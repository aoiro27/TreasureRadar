import AVFoundation
import Foundation

@MainActor
final class StatusVoicePlayer: NSObject {
    private var filePlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ clip: VoiceClip) {
        stop()
        configureSession()
        if let url = Self.bundledURL(for: clip) {
            playFile(url, fallbackText: clip.spokenText)
        } else {
            speakFallback(clip.spokenText)
        }
    }

    func stop() {
        filePlayer?.stop()
        filePlayer = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    private func playFile(_ url: URL, fallbackText: String) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            filePlayer = player
            isSpeaking = true
        } catch {
            speakFallback(fallbackText)
        }
    }

    private func speakFallback(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.05
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    static func bundledURL(for clip: VoiceClip) -> URL? {
        let extensions = ["wav", "caf", "m4a", "mp3"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: clip.fileName, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}

extension StatusVoicePlayer: @preconcurrency AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if filePlayer === player {
            isSpeaking = false
            filePlayer = nil
        }
    }
}

extension StatusVoicePlayer: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
