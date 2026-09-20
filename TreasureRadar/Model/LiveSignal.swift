import Foundation

struct LiveSignal: Equatable, Sendable {
    let power: Int
    let strength: Double

    var powerText: String { ProximityMapper.closenessPowerText(power) }
}
