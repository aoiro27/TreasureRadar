import Foundation

struct ScanSettings: Equatable, Codable, Sendable {
    enum Mode: String, Codable, CaseIterable, Identifiable, Sendable {
        case iBeacon
        case bleName
        case demo

        var id: String { rawValue }

        var title: String {
            switch self {
            case .iBeacon: "iBeacon"
            case .bleName: "Bluetoothのなまえ"
            case .demo: "れんしゅう"
            }
        }

        var subtitle: String {
            switch self {
            case .iBeacon: "Beacon Simulator のUUIDで探す"
            case .bleName: "発信側の表示名で探す"
            case .demo: "電波なしでレーダーの動きを試す"
            }
        }
    }

    static let defaultUUIDString = "D4A60A10-7EA5-4E12-9ADA-545245415355"
    /// 探す側が発信するビーコン。宝のUUIDと先頭ブロックだけ変えて衝突を防ぐ。
    static let hunterUUIDString = "D4A60A11-7EA5-4E12-9ADA-545245415355"
    static let hunterUUID = UUID(uuidString: hunterUUIDString)!
    static let storageKey = "treasure.radar.settings"

    var mode: Mode
    var uuidString: String
    var majorText: String
    var minorText: String
    var bleName: String
    var soundEnabled: Bool
    var voiceEnabled: Bool

    static let `default` = ScanSettings(
        mode: .iBeacon,
        uuidString: defaultUUIDString,
        majorText: "1",
        minorText: "1",
        bleName: "Treasure",
        soundEnabled: true,
        voiceEnabled: true
    )

    var beaconUUID: UUID? {
        UUID(uuidString: uuidString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var major: UInt16? {
        Self.parseIdentity(majorText)
    }

    var minor: UInt16? {
        Self.parseIdentity(minorText)
    }

    var isUUIDValid: Bool {
        beaconUUID != nil
    }

    enum CodingKeys: String, CodingKey {
        case mode, uuidString, majorText, minorText, bleName, soundEnabled, voiceEnabled
    }

    init(
        mode: Mode,
        uuidString: String,
        majorText: String,
        minorText: String,
        bleName: String,
        soundEnabled: Bool,
        voiceEnabled: Bool
    ) {
        self.mode = mode
        self.uuidString = uuidString
        self.majorText = majorText
        self.minorText = minorText
        self.bleName = bleName
        self.soundEnabled = soundEnabled
        self.voiceEnabled = voiceEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(Mode.self, forKey: .mode)
        uuidString = try container.decode(String.self, forKey: .uuidString)
        majorText = try container.decode(String.self, forKey: .majorText)
        minorText = try container.decode(String.self, forKey: .minorText)
        bleName = try container.decode(String.self, forKey: .bleName)
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        voiceEnabled = try container.decodeIfPresent(Bool.self, forKey: .voiceEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(uuidString, forKey: .uuidString)
        try container.encode(majorText, forKey: .majorText)
        try container.encode(minorText, forKey: .minorText)
        try container.encode(bleName, forKey: .bleName)
        try container.encode(soundEnabled, forKey: .soundEnabled)
        try container.encode(voiceEnabled, forKey: .voiceEnabled)
    }

    static func parseIdentity(_ raw: String) -> UInt16? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let value = UInt16(trimmed) else { return nil }
        return value
    }

    func save(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    static func load(defaults: UserDefaults = .standard) -> ScanSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(ScanSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }
}
