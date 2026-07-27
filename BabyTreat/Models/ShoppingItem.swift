import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var category: String     // Vegetables · Fruit · Protein · Pantry
    var name: String
    var quantity: String
    var isChecked: Bool
    /// Monday of the week this list belongs to. Sunday is the planning day.
    var weekStart: Date
    /// The `Food` this line came from, when the list was derived from the menu.
    /// `nil` for pantry staples that are not modelled as foods.
    ///
    /// This is what makes "on the menu but not on the list" reliable. Matching on
    /// the display name cannot work — the list says "Turkey breast" where the
    /// food is "Turkey", and every such pair reads as missing.
    var foodID: String?

    init(
        category: String,
        name: String,
        quantity: String,
        isChecked: Bool = false,
        weekStart: Date,
        foodID: String? = nil,
        calendar: Calendar = .current
    ) {
        self.category = category
        self.name = name
        self.quantity = quantity
        self.isChecked = isChecked
        self.weekStart = calendar.startOfDay(for: weekStart)
        self.foodID = foodID
    }
}
