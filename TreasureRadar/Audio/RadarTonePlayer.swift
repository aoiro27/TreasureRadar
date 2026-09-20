import AVFoundation
import Foundation
import UIKit

@MainActor
final class RadarTonePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var didConfigure = false
    private var lastFoundSoundAt: Date?
    private var interruptionObserver: NSObjectProtocol?

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let hapticSuccess = UINotificationFeedbackGenerator()

    func ping(proximity: TreasureProximity) {
        configureIfNeeded()
        let frequency = ProximityMapper.pingFrequency(for: proximity)
        let duration: Double = proximity == .immediate ? 0.07 : 0.09
        guard let buffer = Self.makePingBuffer(frequency: frequency, duration: duration) else { return }
        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
        haptic(for: proximity)
    }

    func playFoundFanfare() {
        if let lastFoundSoundAt, Date().timeIntervalSince(lastFoundSoundAt) < 2.5 {
            return
        }
        lastFoundSoundAt = Date()
        configureIfNeeded()
        if !player.isPlaying {
            player.play()
        }
        let notes: [(Double, Double)] = [(880, 0.08), (1174, 0.08), (1568, 0.16)]
        for (frequency, duration) in notes {
            guard let buffer = Self.makePingBuffer(frequency: frequency, duration: duration) else { continue }
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
        hapticSuccess.notificationOccurred(.success)
    }

    func stop() {
        player.stop()
        if engine.isRunning {
            engine.stop()
        }
        didConfigure = false
        lastFoundSoundAt = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureIfNeeded() {
        guard !didConfigure else {
            if !engine.isRunning {
                try? engine.start()
                player.play()
            }
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if player.engine == nil {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: Self.stereoFormat)
            }
            try engine.start()
            player.play()
            listenForInterruptions()
            didConfigure = true
        } catch {
            didConfigure = false
        }
    }

    private func listenForInterruptions() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                self?.handleInterruption(typeValue)
            }
        }
    }

    private func handleInterruption(_ typeValue: UInt?) {
        let type = typeValue.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
        switch type {
        case .ended:
            didConfigure = false
            configureIfNeeded()
        case .began:
            player.pause()
        default:
            break
        }
    }

    private func haptic(for proximity: TreasureProximity) {
        switch proximity {
        case .immediate, .near:
            hapticHeavy.impactOccurred()
        case .mid:
            hapticMedium.impactOccurred()
        case .far, .unknown:
            hapticLight.impactOccurred()
        }
    }

    private static let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

    private static func makePingBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let sampleRate = stereoFormat.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        guard let channels = buffer.floatChannelData else { return nil }

        let twoPi = 2.0 * Double.pi
        for frame in 0 ..< Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = pow(0.0001, time / duration)
            let sample = Float(sin(twoPi * frequency * time) * envelope * 0.55)
            channels[0][frame] = sample
            channels[1][frame] = sample
        }
        return buffer
    }
}
