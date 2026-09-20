import CoreBluetooth
import Foundation

@MainActor
final class BLEAdvertisementScanner: NSObject, TreasureScanning {
    private var central: CBCentralManager?
    private var nameNeedle = "Treasure"
    private var lastHits: [UUID: DetectedTreasure] = [:]
    private var pruneTimer: Timer?
    private weak var delegate: TreasureScanDelegate?

    init(delegate: TreasureScanDelegate) {
        self.delegate = delegate
        super.init()
    }

    func start(settings: ScanSettings) {
        stop()
        nameNeedle = settings.bleName.trimmingCharacters(in: .whitespacesAndNewlines)
        lastHits = [:]
        central = CBCentralManager(delegate: self, queue: .main)
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.publish()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pruneTimer = timer
    }

    func stop() {
        pruneTimer?.invalidate()
        pruneTimer = nil
        central?.stopScan()
        central = nil
        lastHits = [:]
    }

    private func beginScanIfReady() {
        guard let central, central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        delegate?.scannerDidChangeStatus("Bluetoothのなまえでさがしています…")
    }

    private func publish() {
        let now = Date()
        let treasures = lastHits.values
            .filter { now.timeIntervalSince($0.lastSeen) < TreasureMerge.lostAfter }
            .sorted { $0.id < $1.id }
        delegate?.scannerDidUpdate(treasures)
    }
}

extension BLEAdvertisementScanner: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            beginScanIfReady()
        case .unauthorized:
            delegate?.scannerDidChangeStatus("Bluetoothの許可が必要です。設定アプリでオンにしてね")
        case .poweredOff:
            delegate?.scannerDidChangeStatus("Bluetoothをオンにしてね")
        case .unsupported:
            delegate?.scannerDidChangeStatus("この端末ではBluetoothを使えません")
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? ""
        if !nameNeedle.isEmpty {
            guard name.localizedCaseInsensitiveContains(nameNeedle) else { return }
        } else if name.isEmpty {
            return
        }

        let rssi = RSSI.intValue
        let treasure = DetectedTreasure.make(
            id: peripheral.identifier.uuidString,
            title: name.isEmpty ? "宝" : name,
            rssi: rssi,
            accuracyMeters: nil
        )
        lastHits[peripheral.identifier] = treasure
        publish()
    }
}
