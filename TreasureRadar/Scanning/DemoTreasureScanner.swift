import Foundation

@MainActor
final class DemoTreasureScanner: TreasureScanning {
    private var timer: Timer?
    private var distanceMeters = 16.0
    private weak var delegate: TreasureScanDelegate?

    init(delegate: TreasureScanDelegate) {
        self.delegate = delegate
    }

    func start(settings: ScanSettings) {
        stop()
        distanceMeters = 16
        delegate?.scannerDidChangeStatus("れんしゅう中。だんだん近づいてきます")
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setDistance(_ meters: Double) {
        distanceMeters = ProximityMapper.clamp(meters, min: 0.2, max: 20)
        tick()
    }

    private func tick() {
        distanceMeters = max(0.25, distanceMeters - 0.18)
        if distanceMeters <= 0.3 {
            distanceMeters = 16
        }

        let approaching = DetectedTreasure.make(
            id: "demo-1",
            title: "れんしゅうのしきしろ",
            rssi: rssi(for: distanceMeters),
            accuracyMeters: distanceMeters
        )
        let far = DetectedTreasure.make(
            id: "demo-2",
            title: "とおいしきしろ",
            rssi: -92,
            accuracyMeters: 14
        )
        delegate?.scannerDidUpdate([approaching, far])
    }

    private func rssi(for meters: Double) -> Int {
        Int((-59 - 20 * log10(max(meters, 0.2))).rounded())
    }
}
