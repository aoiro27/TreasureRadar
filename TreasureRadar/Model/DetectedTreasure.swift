import Foundation

struct DetectedTreasure: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let rssi: Int
    let accuracyMeters: Double?
    let proximity: TreasureProximity
    let radarRadius: Double
    let radarAngle: Double
    let lastSeen: Date
    let usesUWBDirection: Bool
    let usesUWBDistance: Bool
    let uwbHorizontalAngle: Double?

    func smoothed(toward incoming: DetectedTreasure, now: Date) -> DetectedTreasure {
        DetectedTreasure(
            id: incoming.id,
            title: incoming.title,
            rssi: ProximityMapper.smoothedRSSI(previous: rssi, incoming: incoming.rssi),
            accuracyMeters: ProximityMapper.smoothedMeters(
                previous: accuracyMeters,
                incoming: incoming.accuracyMeters
            ),
            proximity: incoming.proximity,
            radarRadius: ProximityMapper.clamp(
                radarRadius * 0.65 + incoming.radarRadius * 0.35,
                min: 0.08,
                max: 1
            ),
            radarAngle: incoming.radarAngle,
            lastSeen: now,
            usesUWBDirection: incoming.usesUWBDirection,
            usesUWBDistance: incoming.usesUWBDistance,
            uwbHorizontalAngle: incoming.uwbHorizontalAngle
        )
    }

    static func make(
        id: String,
        title: String,
        rssi: Int,
        accuracyMeters: Double?,
        now: Date = Date(),
        radarAngle: Double? = nil,
        usesUWBDirection: Bool = false,
        usesUWBDistance: Bool = false,
        uwbHorizontalAngle: Double? = nil
    ) -> DetectedTreasure {
        DetectedTreasure(
            id: id,
            title: title,
            rssi: rssi,
            accuracyMeters: accuracyMeters,
            proximity: ProximityMapper.proximity(accuracyMeters: accuracyMeters, rssi: rssi),
            radarRadius: ProximityMapper.radarRadius(accuracyMeters: accuracyMeters, rssi: rssi),
            radarAngle: radarAngle ?? ProximityMapper.stableAngle(for: id),
            lastSeen: now,
            usesUWBDirection: usesUWBDirection,
            usesUWBDistance: usesUWBDistance,
            uwbHorizontalAngle: uwbHorizontalAngle
        )
    }
}

enum TreasureMerge {
    static let lostAfter: TimeInterval = 4

    static func merge(
        existing: [DetectedTreasure],
        incoming: [DetectedTreasure],
        now: Date
    ) -> [DetectedTreasure] {
        var merged = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for item in incoming {
            if let old = merged[item.id] {
                merged[item.id] = old.smoothed(toward: item, now: now)
            } else {
                merged[item.id] = item
            }
        }

        return merged.values
            .filter { now.timeIntervalSince($0.lastSeen) < lostAfter }
            .sorted { $0.id < $1.id }
    }
}
