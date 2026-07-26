import Foundation
import SwiftData

@Model
final class Medicine {
    var name: String
    var details: String
    var createdAt: Date

    init(name: String, details: String = "", createdAt: Date = .now) {
        self.name = name
        self.details = details
        self.createdAt = createdAt
    }
}
