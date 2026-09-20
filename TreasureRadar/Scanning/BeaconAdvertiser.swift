import CoreBluetooth
import CoreLocation
import Foundation

enum BeaconRole: Sendable {
    case treasure
    case hunter
}

@MainActor
final class BeaconAdvertiser: NSObject {
    private var peripheral: CBPeripheralManager?
    private var payload: [String: Any]?
    private var role: BeaconRole = .treasure
    private var announceStatus = true
    private weak var delegate: TreasureScanDelegate?

    init(delegate: TreasureScanDelegate) {
        self.delegate = delegate
        super.init()
    }

    func start(settings: ScanSettings, role: BeaconRole = .treasure, announceStatus: Bool = true) {
        stop()
        self.role = role
        self.announceStatus = announceStatus

        let uuid: UUID?
        let major: UInt16
        let minor: UInt16
        let identifier: String
        switch role {
        case .treasure:
            uuid = settings.beaconUUID
            major = settings.major ?? 1
            minor = settings.minor ?? 1
            identifier = "treasure.radar.hide"
        case .hunter:
            uuid = ScanSettings.hunterUUID
            major = 1
            minor = 1
            identifier = "treasure.radar.seek"
        }

        guard let uuid else {
            report("UUIDがちがいます。せっていを見てね")
            return
        }

        let constraint = CLBeaconIdentityConstraint(uuid: uuid, major: major, minor: minor)
        let region = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: identifier)
        payload = region.peripheralData(withMeasuredPower: -59) as? [String: Any]
        peripheral = CBPeripheralManager(delegate: self, queue: .main)
        report(role == .treasure ? "宝の電波を発信する準備中…" : "探す電波を発信する準備中…")
    }

    func stop() {
        peripheral?.stopAdvertising()
        peripheral = nil
        payload = nil
    }

    private func report(_ message: String) {
        guard announceStatus else { return }
        delegate?.scannerDidChangeStatus(message)
    }
}

extension BeaconAdvertiser: @preconcurrency CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if let payload {
                peripheral.startAdvertising(payload)
                switch role {
                case .treasure:
                    report("宝の電波を発信中。このスマホを隠してね")
                case .hunter:
                    report("探す電波を発信中")
                }
            }
        case .unauthorized:
            report("Bluetoothの許可が必要です。設定アプリでオンにしてね")
        case .poweredOff:
            report("Bluetoothをオンにしてね")
        default:
            break
        }
    }
}
