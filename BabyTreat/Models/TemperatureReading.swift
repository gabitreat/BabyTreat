import Foundation
import SwiftData

@Model
final class TemperatureReading {
    var value: Double
    var unit: String
    var timestamp: Date

    init(value: Double, unit: String, timestamp: Date = .now) {
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
    }
}
