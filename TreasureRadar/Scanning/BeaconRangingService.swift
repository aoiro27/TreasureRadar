import CoreLocation
import Foundation

@MainActor
protocol TreasureScanning: AnyObject {
    func start(settings: ScanSettings)
    func stop()
}

@MainActor
protocol TreasureScanDelegate: AnyObject {
    func scannerDidUpdate(_ treasures: [DetectedTreasure])
    func scannerDidChangeStatus(_ message: String)
}

@MainActor
final class BeaconRangingService: NSObject, TreasureScanning {
    private let locationManager = CLLocationManager()
    private var constraint: CLBeaconIdentityConstraint?
    private var region: CLBeaconRegion?
    private var isRanging = false
    private var role: BeaconRole = .treasure
    private weak var delegate: TreasureScanDelegate?

    init(delegate: TreasureScanDelegate) {
        self.delegate = delegate
        super.init()
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func start(settings: ScanSettings) {
        start(settings: settings, role: .treasure)
    }

    func start(settings: ScanSettings, role: BeaconRole) {
        stop()
        self.role = role

        let uuid: UUID?
        let nextConstraint: CLBeaconIdentityConstraint
        switch role {
        case .treasure:
            uuid = settings.beaconUUID
            guard let uuid else {
                delegate?.scannerDidChangeStatus("UUIDがちがいます。せっていを見てね")
                return
            }
            if let major = settings.major, let minor = settings.minor {
                nextConstraint = CLBeaconIdentityConstraint(uuid: uuid, major: major, minor: minor)
            } else if let major = settings.major {
                nextConstraint = CLBeaconIdentityConstraint(uuid: uuid, major: major)
            } else {
                nextConstraint = CLBeaconIdentityConstraint(uuid: uuid)
            }
        case .hunter:
            uuid = settings.hunterUUID
            guard let uuid else {
                delegate?.scannerDidChangeStatus("UUIDがちがいます。せっていを見てね")
                return
            }
            nextConstraint = CLBeaconIdentityConstraint(uuid: uuid, major: 1, minor: 1)
        }

        guard let uuid else { return }
        constraint = nextConstraint
        region = CLBeaconRegion(beaconIdentityConstraint: nextConstraint, identifier: uuid.uuidString)

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            delegate?.scannerDidChangeStatus("位置情報の許可が必要です。設定アプリでオンにしてね")
        default:
            beginRanging()
        }
    }

    func stop() {
        if let constraint {
            locationManager.stopRangingBeacons(satisfying: constraint)
        }
        if let region {
            locationManager.stopMonitoring(for: region)
        }
        constraint = nil
        region = nil
        isRanging = false
    }

    private func beginRanging() {
        guard let constraint, let region, !isRanging else { return }
        locationManager.startMonitoring(for: region)
        locationManager.startRangingBeacons(satisfying: constraint)
        isRanging = true
        delegate?.scannerDidChangeStatus(searchingMessage)
    }
}

extension BeaconRangingService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            beginRanging()
        case .denied, .restricted:
            delegate?.scannerDidChangeStatus("位置情報の許可が必要です。設定アプリでオンにしてね")
        default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying beaconConstraint: CLBeaconIdentityConstraint
    ) {
        let now = Date()
        let treasures = beacons.map { beacon in
            DetectedTreasure.make(
                id: "\(beacon.uuid.uuidString)-\(beacon.major)-\(beacon.minor)",
                title: "宝 \(beacon.major)-\(beacon.minor)",
                rssi: beacon.rssi,
                accuracyMeters: beacon.accuracy >= 0 ? beacon.accuracy : nil,
                now: now
            )
        }

        delegate?.scannerDidUpdate(treasures)
        if treasures.isEmpty {
            delegate?.scannerDidChangeStatus(searchingMessage)
        }
    }

    private var searchingMessage: String {
        switch role {
        case .treasure: "宝の電波をさがしています…"
        case .hunter: "かくしているよ。近づく人を見張っています"
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailRangingFor beaconConstraint: CLBeaconIdentityConstraint, error: any Error) {
        delegate?.scannerDidChangeStatus("レーダーが使えない状態です。Bluetoothをオンにしてね")
    }
}
