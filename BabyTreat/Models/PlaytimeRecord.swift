import Foundation
import SwiftData

@Model
final class PlaytimeRecord {
    var startTime: Date
    var stopTime: Date

    init(startTime: Date, stopTime: Date) {
        self.startTime = startTime
        self.stopTime = stopTime
    }
}
