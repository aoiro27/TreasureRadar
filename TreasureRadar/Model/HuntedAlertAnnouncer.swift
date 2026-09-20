import Foundation

struct HuntedAlertAnnouncer: Equatable, Sendable {
    var holdDuration: TimeInterval = 0.75
    var cooldown: TimeInterval = 12
    var triggerAt: TreasureProximity = .near

    private var candidate: TreasureProximity?
    private var candidateSince: Date?
    private var lastAlertAt: Date?

    mutating func reset() {
        candidate = nil
        candidateSince = nil
        lastAlertAt = nil
    }

    /// 探す側がすぐ近くまで来たら `voice_hunted` を返す。
    mutating func clip(for proximity: TreasureProximity, now: Date) -> VoiceClip? {
        guard proximity >= triggerAt else {
            candidate = nil
            candidateSince = nil
            return nil
        }

        if candidate == nil {
            candidate = proximity
            candidateSince = now
            return nil
        }

        candidate = proximity
        guard let candidateSince, now.timeIntervalSince(candidateSince) >= holdDuration else {
            return nil
        }

        if let lastAlertAt, now.timeIntervalSince(lastAlertAt) < cooldown {
            return nil
        }

        lastAlertAt = now
        return .hunted
    }
}
