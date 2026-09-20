import Foundation

enum VoiceClip: String, CaseIterable, Sendable {
    case searching
    case far
    case mid
    case near
    case immediate
    case found
    case hunted

    var fileName: String { "voice_\(rawValue)" }

    var spokenText: String {
        switch self {
        case .searching: "さがしています"
        case .far: "まだとおいよ"
        case .mid: "ちかづいてきたよ"
        case .near: "あとすこしだよ"
        case .immediate: "すぐそばだよ"
        case .found: "しきしろをみつけたよ"
        case .hunted: "やばい、ちかづいてきたー！"
        }
    }

    static func status(_ proximity: TreasureProximity) -> VoiceClip {
        switch proximity {
        case .unknown: .searching
        case .far: .far
        case .mid: .mid
        case .near: .near
        case .immediate: .immediate
        }
    }
}

struct StatusAnnouncer: Equatable, Sendable {
    var holdDuration: TimeInterval = 0.75

    private var lastSpoken: TreasureProximity?
    private var candidate: TreasureProximity?
    private var candidateSince: Date?

    mutating func reset() {
        lastSpoken = nil
        candidate = nil
        candidateSince = nil
    }

    /// 開始時など、ホールドせずにすぐ言う。
    mutating func speakNow(_ proximity: TreasureProximity) -> VoiceClip {
        lastSpoken = proximity
        candidate = nil
        candidateSince = nil
        return VoiceClip.status(proximity)
    }

    mutating func clip(for proximity: TreasureProximity, now: Date) -> VoiceClip? {
        if proximity == lastSpoken {
            candidate = nil
            candidateSince = nil
            return nil
        }

        if candidate != proximity {
            candidate = proximity
            candidateSince = now
            return nil
        }

        guard let candidateSince, now.timeIntervalSince(candidateSince) >= holdDuration else {
            return nil
        }

        lastSpoken = proximity
        candidate = nil
        self.candidateSince = nil
        return VoiceClip.status(proximity)
    }
}
