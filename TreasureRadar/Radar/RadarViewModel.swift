import Foundation
import UIKit

enum RadarSession: Equatable {
    case idle
    case seeking
    case hiding
}

@Observable
@MainActor
final class RadarViewModel: TreasureScanDelegate, UWBPeerDelegate {
    private(set) var treasures: [DetectedTreasure] = []
    private(set) var session: RadarSession = .idle
    private(set) var statusMessage = "『さがす』をおしてね"
    private(set) var isFound = false
    var settings: ScanSettings
    var showSettings = false
    var showHowTo = false

    private var rangingService: BeaconRangingService?
    private var bleScanner: BLEAdvertisementScanner?
    private var demoScanner: DemoTreasureScanner?
    private var advertiser: BeaconAdvertiser?
    private var hunterAdvertiser: BeaconAdvertiser?
    private var hunterRanger: BeaconRangingService?
    private var uwbCoordinator: UWBPeerCoordinator?
    private var bleTreasures: [DetectedTreasure] = []
    private var hunterHits: [DetectedTreasure] = []
    private var uwbFix: UWBFix?
    private var uwbFusionState = UWBFusionState()
    private let tonePlayer = RadarTonePlayer()
    private let voicePlayer = StatusVoicePlayer()
    private var lastPingAt = Date.distantPast
    private var foundTracker = FoundTracker()
    private var statusAnnouncer = StatusAnnouncer()
    private var huntedAlert = HuntedAlertAnnouncer()
    private(set) var hunterProximity: TreasureProximity = .unknown

    init(settings: ScanSettings = .load()) {
        self.settings = settings
    }

    var isScanning: Bool { session == .seeking }
    var isHiding: Bool { session == .hiding }

    var closest: DetectedTreasure? {
        treasures.min(by: { $0.radarRadius < $1.radarRadius })
    }

    var rangingLink: RangingLink? {
        RangingLink.current(isActive: session != .idle, usingUWB: uwbFusionState.usingUWB)
    }

    var liveSignal: LiveSignal? {
        guard session == .seeking, let closest else { return nil }
        guard let power = ProximityMapper.closenessPower(
            accuracyMeters: closest.accuracyMeters,
            rssi: closest.rssi
        ) else {
            return nil
        }
        return LiveSignal(power: power, strength: Double(power) / 100)
    }

    var proximityLabel: String {
        if session == .hiding {
            if hunterProximity >= .near {
                return VoiceClip.hunted.spokenText
            }
            return "かくしているよ"
        }
        if !isScanning { return "レーダーていし" }
        return closest?.proximity.kidLabel ?? "さがしています"
    }

    func startSeeking() {
        stopAll()
        session = .seeking
        treasures = []
        isFound = false
        foundTracker.reset()
        statusAnnouncer.reset()
        UIApplication.shared.isIdleTimerDisabled = true
        statusMessage = "宝の電波をさがしています…"

        #if targetEnvironment(simulator)
        if settings.mode != .demo {
            statusMessage = "シミュレータでは電波が取れません。れんしゅうモードを使ってね"
        }
        #endif

        switch settings.mode {
        case .iBeacon:
            let service = BeaconRangingService(delegate: self)
            rangingService = service
            service.start(settings: settings)
        case .bleName:
            let service = BLEAdvertisementScanner(delegate: self)
            bleScanner = service
            service.start(settings: settings)
        case .demo:
            let service = DemoTreasureScanner(delegate: self)
            demoScanner = service
            service.start(settings: settings)
        }
        speak(statusAnnouncer.speakNow(.unknown))
        startHunterBroadcastIfNeeded()
        startUWBIfNeeded(role: .hunter)
    }

    func startHiding() {
        stopAll()
        session = .hiding
        treasures = []
        isFound = false
        hunterProximity = .unknown
        huntedAlert.reset()
        UIApplication.shared.isIdleTimerDisabled = true

        #if targetEnvironment(simulator)
        if settings.mode != .demo {
            statusMessage = "シミュレータでは電波が取れません。れんしゅうモードを使ってね"
        }
        #endif

        if settings.mode == .demo {
            statusMessage = "れんしゅう中。近づいてきた声をためせるよ"
            let service = DemoTreasureScanner(delegate: self)
            demoScanner = service
            service.start(settings: settings)
            return
        }

        let service = BeaconAdvertiser(delegate: self)
        advertiser = service
        service.start(settings: settings, role: .treasure)

        let ranger = BeaconRangingService(delegate: self)
        hunterRanger = ranger
        ranger.start(settings: settings, role: .hunter)
        startUWBIfNeeded(role: .treasure)
    }

    func stopAll() {
        rangingService?.stop()
        bleScanner?.stop()
        demoScanner?.stop()
        advertiser?.stop()
        hunterAdvertiser?.stop()
        hunterRanger?.stop()
        uwbCoordinator?.stop()
        rangingService = nil
        bleScanner = nil
        demoScanner = nil
        advertiser = nil
        hunterAdvertiser = nil
        hunterRanger = nil
        uwbCoordinator = nil
        bleTreasures = []
        hunterHits = []
        uwbFix = nil
        uwbFusionState = UWBFusionState()
        tonePlayer.stop()
        voicePlayer.stop()
        session = .idle
        treasures = []
        isFound = false
        hunterProximity = .unknown
        foundTracker.reset()
        statusAnnouncer.reset()
        huntedAlert.reset()
        UIApplication.shared.isIdleTimerDisabled = false
        statusMessage = "『さがす』をおしてね"
    }

    func persistSettings() {
        settings.save()
    }

    func copyUUIDToPasteboard() {
        UIPasteboard.general.string = settings.uuidString
        statusMessage = "UUIDをコピーしたよ"
    }

    func resetUUID() {
        settings.uuidString = ScanSettings.defaultUUIDString
        persistSettings()
    }

    func tick(now: Date) {
        guard session == .seeking, settings.soundEnabled else { return }
        if settings.voiceEnabled, voicePlayer.isSpeaking { return }
        let proximity = closest?.proximity ?? .unknown
        let interval = ProximityMapper.beepInterval(for: proximity)
        guard now.timeIntervalSince(lastPingAt) >= interval else { return }
        lastPingAt = now
        if isFound {
            tonePlayer.playFoundFanfare()
        } else {
            tonePlayer.ping(proximity: proximity)
        }
    }

    func previewVoice() {
        guard settings.voiceEnabled else { return }
        voicePlayer.speak(.mid)
    }

    func previewHuntedVoice() {
        guard settings.huntedVoiceEnabled else { return }
        voicePlayer.speak(.hunted)
    }

    func scannerDidUpdate(_ incoming: [DetectedTreasure]) {
        let now = Date()
        if session == .hiding {
            hunterHits = incoming
            handleHunterUpdate(incoming, now: now)
            return
        }
        guard session == .seeking else { return }

        bleTreasures = TreasureMerge.merge(existing: bleTreasures, incoming: incoming, now: now)
        publishFused(now: now)
    }

    func scannerDidChangeStatus(_ message: String) {
        if session == .seeking, closest != nil { return }
        if session == .hiding, hunterProximity >= .near { return }
        statusMessage = message
    }

    private func updateFoundState(now: Date) {
        guard session == .seeking else { return }
        let shouldCelebrate = foundTracker.update(proximity: closest?.proximity, now: now)
        isFound = foundTracker.isFound
        if shouldCelebrate {
            if settings.soundEnabled {
                tonePlayer.playFoundFanfare()
            }
            speak(.found)
        }
    }

    private func speak(_ clip: VoiceClip) {
        switch clip {
        case .hunted:
            guard settings.huntedVoiceEnabled else { return }
        default:
            guard settings.voiceEnabled else { return }
        }
        voicePlayer.speak(clip)
    }

    func uwbDidUpdate(_ fix: UWBFix?) {
        uwbFix = fix
        let now = Date()
        if session == .hiding {
            handleHunterUpdate(hunterHits, now: now)
        } else if session == .seeking {
            publishFused(now: now)
        }
    }

    func uwbDidChangeStatus(_ message: String) {
        scannerDidChangeStatus(message)
    }

    private func publishFused(now: Date) {
        let fused = UWBRadarFusion.apply(
            treasures: bleTreasures,
            fix: uwbFix,
            state: uwbFusionState,
            now: now
        )
        uwbFusionState = fused.state
        treasures = fused.treasures
        updateFoundState(now: now)
        if session == .seeking {
            let proximity = closest?.proximity ?? .unknown
            if fused.state.usingUWB, let meters = closest?.accuracyMeters {
                statusMessage = UWBRadarFusion.seekingHint(
                    meters: meters,
                    horizontalAngle: closest?.uwbHorizontalAngle
                )
            } else {
                statusMessage = proximity.kidLabel
            }
            if settings.voiceEnabled, let clip = statusAnnouncer.clip(for: proximity, now: now) {
                speak(clip)
            }
        }
    }

    private func startUWBIfNeeded(role: BeaconRole) {
        guard settings.mode != .demo else { return }
        #if targetEnvironment(simulator)
        return
        #else
        let coordinator = UWBPeerCoordinator(delegate: self)
        uwbCoordinator = coordinator
        coordinator.start(role: role)
        #endif
    }

    private func startHunterBroadcastIfNeeded() {
        guard settings.mode != .demo else { return }
        let service = BeaconAdvertiser(delegate: self)
        hunterAdvertiser = service
        service.start(settings: settings, role: .hunter, announceStatus: false)
    }

    private func handleHunterUpdate(_ incoming: [DetectedTreasure], now: Date) {
        let fused = UWBRadarFusion.apply(
            treasures: incoming,
            fix: uwbFix,
            state: uwbFusionState,
            now: now
        )
        uwbFusionState = fused.state
        hunterProximity = fused.treasures.map(\.proximity).max()
            ?? incoming.map(\.proximity).max()
            ?? .unknown
        if hunterProximity >= .near {
            statusMessage = VoiceClip.hunted.spokenText
        } else if hunterProximity == .unknown {
            statusMessage = "かくしているよ。近づく人を見張っています"
        } else {
            statusMessage = "だれかが近くにいるかも"
        }
        if settings.huntedVoiceEnabled, let clip = huntedAlert.clip(for: hunterProximity, now: now) {
            speak(clip)
        }
    }
}
