import Foundation

struct FoundTracker: Equatable, Sendable {
    private(set) var isFound = false
    private var foundSince: Date?
    private var lostSince: Date?
    private var didCelebrate = false

    mutating func reset() {
        isFound = false
        foundSince = nil
        lostSince = nil
        didCelebrate = false
    }

    /// 発見ファンファーレを今鳴らすべきなら `true`。
    mutating func update(proximity: TreasureProximity?, now: Date) -> Bool {
        if proximity == .immediate {
            lostSince = nil
            if foundSince == nil { foundSince = now }
            if let foundSince, now.timeIntervalSince(foundSince) >= 1 {
                isFound = true
                if !didCelebrate {
                    didCelebrate = true
                    return true
                }
            }
            return false
        }

        foundSince = nil
        guard isFound else { return false }
        if lostSince == nil { lostSince = now }
        if let lostSince, now.timeIntervalSince(lostSince) >= 1.5 {
            isFound = false
            didCelebrate = false
            self.lostSince = nil
        }
        return false
    }
}
