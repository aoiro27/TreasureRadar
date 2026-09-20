import Foundation

enum TreasureProximity: Int, Sendable, Comparable {
    case unknown = 0
    case far = 1
    case mid = 2
    case near = 3
    case immediate = 4

    static func < (lhs: TreasureProximity, rhs: TreasureProximity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var kidLabel: String {
        switch self {
        case .unknown: "さがしています"
        case .far: "まだとおいよ"
        case .mid: "ちかづいてきたよ"
        case .near: "あとすこしだよ"
        case .immediate: "すぐそばだよ"
        }
    }
}

enum ProximityMapper {
    static func proximity(accuracyMeters: Double?, rssi: Int) -> TreasureProximity {
        if let accuracyMeters, accuracyMeters >= 0 {
            switch accuracyMeters {
            case ..<0.8: return .immediate
            case ..<3.0: return .near
            case ..<8.0: return .mid
            default: return .far
            }
        }

        guard isUsableRSSI(rssi) else { return .unknown }

        switch rssi {
        case -45...Int.max: return .immediate
        case -62 ..< -45: return .near
        case -78 ..< -62: return .mid
        default: return .far
        }
    }

    /// 画面中央が 0、外周が 1。距離が近いほど中心に寄る。
    static func radarRadius(accuracyMeters: Double?, rssi: Int) -> Double {
        if let accuracyMeters, accuracyMeters >= 0 {
            return clamp(accuracyMeters / 18.0, min: 0.08, max: 1)
        }

        guard isUsableRSSI(rssi) else { return 1 }

        let normalized = Double(-rssi - 30) / 70.0
        return clamp(normalized, min: 0.08, max: 1)
    }

    static func beepInterval(for proximity: TreasureProximity) -> TimeInterval {
        switch proximity {
        case .unknown: 2.4
        case .far: 1.55
        case .mid: 0.85
        case .near: 0.36
        case .immediate: 0.12
        }
    }

    static func pingFrequency(for proximity: TreasureProximity) -> Double {
        switch proximity {
        case .unknown: 740
        case .far: 880
        case .mid: 1050
        case .near: 1320
        case .immediate: 1760
        }
    }

    static func stableAngle(for id: String) -> Double {
        var hash: UInt64 = 5381
        for byte in id.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return Double(hash % 360) * .pi / 180
    }

    static func isUsableRSSI(_ rssi: Int) -> Bool {
        rssi != 127 && rssi != 0 && rssi > -120 && rssi < 0
    }

    static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(max, Swift.max(min, value))
    }

    /// iBeacon の推定距離を優先し、なければ RSSI からおおよそのメートルを出す。
    static func estimatedMeters(
        accuracyMeters: Double?,
        rssi: Int,
        measuredPower: Int = -59
    ) -> Double? {
        if let accuracyMeters, accuracyMeters >= 0 {
            return clamp(accuracyMeters, min: 0.1, max: 40)
        }
        guard isUsableRSSI(rssi) else { return nil }
        let meters = pow(10, Double(measuredPower - rssi) / 20)
        return clamp(meters, min: 0.2, max: 40)
    }

    /// 0 が弱い、1 が強い。
    static func signalStrength(rssi: Int) -> Double {
        guard isUsableRSSI(rssi) else { return 0 }
        return clamp(Double(rssi + 100) / 70, min: 0, max: 1)
    }

    /// 0 が遠い、100 がちかい。「ちかさパワー」の数値。
    static func closenessPower(accuracyMeters: Double?, rssi: Int) -> Int? {
        guard let meters = estimatedMeters(accuracyMeters: accuracyMeters, rssi: rssi) else {
            return nil
        }
        let near = 0.3
        let far = 40.0
        let ratio = log10(max(meters, near) / near) / log10(far / near)
        let score = (1 - clamp(ratio, min: 0, max: 1)) * 100
        return Int(score.rounded())
    }

    static func closenessPowerText(_ power: Int?) -> String {
        guard let power else { return "—" }
        return "\(power)"
    }

    static func smoothedRSSI(previous: Int, incoming: Int) -> Int {
        guard isUsableRSSI(previous), isUsableRSSI(incoming) else { return incoming }
        return Int((Double(previous) * 0.55 + Double(incoming) * 0.45).rounded())
    }

    static func smoothedMeters(previous: Double?, incoming: Double?) -> Double? {
        guard let previous, let incoming, previous >= 0, incoming >= 0 else {
            return incoming
        }
        return previous * 0.55 + incoming * 0.45
    }
}
