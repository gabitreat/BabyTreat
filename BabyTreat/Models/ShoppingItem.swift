import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var category: String     // Legume · Fructe · Proteine · Cămară
    var name: String
    var quantity: String
    var isChecked: Bool
    /// Monday of the week this list belongs to. Sunday is the planning day.
    var weekStart: Date

    init(
        category: String,
        name: String,
        quantity: String,
        isChecked: Bool = false,
        weekStart: Date,
        calendar: Calendar = .current
    ) {
        self.category = category
        self.name = name
        self.quantity = quantity
        self.isChecked = isChecked
        self.weekStart = calendar.startOfDay(for: weekStart)
    }
}
