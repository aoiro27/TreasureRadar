import Foundation
import simd

struct UWBFix: Equatable, Sendable {
    var distanceMeters: Double
    var horizontalAngle: Double?
    var timestamp: Date
}

struct UWBFusionState: Equatable, Sendable {
    var usingUWB = false
    var lastRadarAngle: Double?
}

enum RangingLink: String, Equatable, Sendable {
    case ble = "BLE"
    case uwb = "UWB"

    static func current(isActive: Bool, usingUWB: Bool) -> RangingLink? {
        guard isActive else { return nil }
        return usingUWB ? .uwb : .ble
    }
}

enum UWBRadarFusion {
    static let staleAfter: TimeInterval = 2.5
    static let syntheticTreasureID = "uwb-peer"

    static func radarAngle(fromHorizontalAngle horizontal: Double) -> Double {
        horizontal - .pi / 2
    }

    static func mixAngles(_ from: Double, _ to: Double, t: Double) -> Double {
        let delta = atan2(sin(to - from), cos(to - from))
        return from + delta * t
    }

    /// Nearby Interaction の方向ベクトル。−Z がスマホの背面（探す向き）。
    static func horizontalAngle(fromDirection direction: SIMD3<Float>) -> Double? {
        if direction.x == 0, direction.z == 0 { return nil }
        return Double(atan2(direction.x, -direction.z))
    }

    static func relativeDirectionLabel(fromHorizontalAngle horizontal: Double) -> String {
        var degrees = horizontal * 180 / .pi
        while degrees <= -180 { degrees += 360 }
        while degrees > 180 { degrees -= 360 }
        let absolute = abs(degrees)
        if absolute < 22.5 { return "まえ" }
        if absolute < 67.5 { return degrees > 0 ? "みぎまえ" : "ひだりまえ" }
        if absolute < 112.5 { return degrees > 0 ? "みぎ" : "ひだり" }
        if absolute < 157.5 { return degrees > 0 ? "みぎうしろ" : "ひだりうしろ" }
        return "うしろ"
    }

    static func formattedMeters(_ meters: Double) -> String {
        if meters < 10 {
            return String(format: "%.1fm", meters)
        }
        return String(format: "%.0fm", meters)
    }

    static func fix(distanceMeters: Double?, horizontalAngle: Double?, now: Date = Date()) -> UWBFix? {
        if let distanceMeters {
            return UWBFix(
                distanceMeters: max(distanceMeters, 0),
                horizontalAngle: horizontalAngle,
                timestamp: now
            )
        }
        guard horizontalAngle != nil else { return nil }
        return UWBFix(distanceMeters: 0.15, horizontalAngle: horizontalAngle, timestamp: now)
    }

    static func seekingHint(meters: Double, horizontalAngle: Double?) -> String {
        let distance = formattedMeters(meters)
        if let horizontalAngle {
            let direction = relativeDirectionLabel(fromHorizontalAngle: horizontalAngle)
            return "\(direction) \(distance)　うえ＝スマホのうしろ"
        }
        return "\(distance)　方角はまだ。スマホをたてて、うしろ側をしきしろのほうへ"
    }

    static func shouldUseUWB(currentlyUsing _: Bool, fix: UWBFix?, now: Date) -> Bool {
        guard let fix else { return false }
        return now.timeIntervalSince(fix.timestamp) < staleAfter
    }

    static func apply(
        treasures: [DetectedTreasure],
        fix: UWBFix?,
        state: UWBFusionState,
        now: Date
    ) -> (treasures: [DetectedTreasure], state: UWBFusionState) {
        let usingUWB = shouldUseUWB(currentlyUsing: state.usingUWB, fix: fix, now: now)
        var nextState = UWBFusionState(usingUWB: usingUWB)
        guard usingUWB, let fix else {
            return (treasures, nextState)
        }

        if treasures.isEmpty {
            let overlaid = overlay(
                DetectedTreasure.make(
                    id: syntheticTreasureID,
                    title: "しきしろ",
                    rssi: -59,
                    accuracyMeters: fix.distanceMeters,
                    now: now
                ),
                with: fix,
                now: now,
                state: state
            )
            nextState.lastRadarAngle = overlaid.usesUWBDirection ? overlaid.radarAngle : nil
            return ([overlaid], nextState)
        }

        let closestID = treasures.min(by: { $0.radarRadius < $1.radarRadius })?.id
        let updated = treasures.map { treasure -> DetectedTreasure in
            guard treasure.id == closestID else { return treasure }
            let overlaid = overlay(treasure, with: fix, now: now, state: state)
            nextState.lastRadarAngle = overlaid.usesUWBDirection ? overlaid.radarAngle : nil
            return overlaid
        }
        return (updated, nextState)
    }

    private static func resolveAngle(target: Double?, state: UWBFusionState) -> Double? {
        guard let target else { return state.lastRadarAngle }
        if let last = state.lastRadarAngle, state.usingUWB {
            return mixAngles(last, target, t: 0.75)
        }
        return target
    }

    private static func overlay(
        _ treasure: DetectedTreasure,
        with fix: UWBFix,
        now: Date,
        state: UWBFusionState
    ) -> DetectedTreasure {
        let heading = fix.horizontalAngle.map(radarAngle(fromHorizontalAngle:))
        let hasHeading = heading != nil
        let angle = resolveAngle(target: heading, state: state) ?? treasure.radarAngle
        return DetectedTreasure.make(
            id: treasure.id,
            title: treasure.title,
            rssi: treasure.rssi,
            accuracyMeters: fix.distanceMeters,
            now: now,
            radarAngle: angle,
            usesUWBDirection: hasHeading,
            usesUWBDistance: true,
            uwbHorizontalAngle: fix.horizontalAngle
        )
    }
}
