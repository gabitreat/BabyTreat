import Foundation
import SwiftData

@Model
final class NursingRecord {
    var timestamp: Date
    var leftDuration: TimeInterval
    var rightDuration: TimeInterval

    init(timestamp: Date = .now, leftDuration: TimeInterval, rightDuration: TimeInterval) {
        self.timestamp = timestamp
        self.leftDuration = leftDuration
        self.rightDuration = rightDuration
    }
}
