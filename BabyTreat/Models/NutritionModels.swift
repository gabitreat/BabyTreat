import Foundation
import SwiftData

/// Which meal a logged food belongs to.
///
/// Deliberately separate from `MealSlot`, which is the baby's day and carries
/// Romanian raw values and age gates. These two are never the same thing and
/// sharing a type would invite mixing the baby's journal with the parent's.
enum NutritionSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch:     "Lunch"
        case .dinner:    "Dinner"
        case .snack:     "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch:     "sun.max"
        case .dinner:    "moon"
        case .snack:     "leaf"
        }
    }

    /// Chronological, so the day reads top to bottom.
    var order: Int {
        switch self {
        case .breakfast: 0
        case .lunch:     1
        case .snack:     2
        case .dinner:    3
        }
    }
}

/// One thing eaten, at a point in time.
@Model
final class FoodEntry {
    var name: String
    var kcal: Double
    /// Whichever the amount was entered as. Both are optional because a logged
    /// item may be neither weighed nor countable — "a coffee, 40 kcal" is valid.
    var grams: Double?
    var servings: Double?
    var protein: Double
    var carbs: Double
    var fat: Double
    var mealSlotRaw: String
    var barcode: String?
    var timestamp: Date

    init(
        name: String,
        kcal: Double,
        grams: Double? = nil,
        servings: Double? = nil,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        slot: NutritionSlot = .snack,
        barcode: String? = nil,
        timestamp: Date = .now
    ) {
        self.name = name
        self.kcal = kcal
        self.grams = grams
        self.servings = servings
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.mealSlotRaw = slot.rawValue
        self.barcode = barcode
        self.timestamp = timestamp
    }

    var slot: NutritionSlot {
        get { NutritionSlot(rawValue: mealSlotRaw) ?? .snack }
        set { mealSlotRaw = newValue.rawValue }
    }

    /// "180 g" / "1.5 servings" / "" when neither was recorded.
    var amountLabel: String {
        if let grams { return "\(Int(grams.rounded())) g" }
        if let servings {
            let trimmed = servings == servings.rounded()
                ? String(Int(servings))
                : String(format: "%.1f", servings)
            return "\(trimmed) serving\(servings == 1 ? "" : "s")"
        }
        return ""
    }
}

/// A product worth remembering — scanned once, reused after.
@Model
final class SavedFood {
    var name: String
    var brand: String
    /// Per 100 g, which is how EU labels are legally written.
    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var servingGrams: Double?
    @Attribute(.unique) var barcode: String?
    var lastUsed: Date
    var useCount: Int

    init(
        name: String,
        brand: String = "",
        kcalPer100g: Double,
        proteinPer100g: Double = 0,
        carbsPer100g: Double = 0,
        fatPer100g: Double = 0,
        servingGrams: Double? = nil,
        barcode: String? = nil,
        lastUsed: Date = .now,
        useCount: Int = 0
    ) {
        self.name = name
        self.brand = brand
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.servingGrams = servingGrams
        self.barcode = barcode
        self.lastUsed = lastUsed
        self.useCount = useCount
    }

    func entry(grams: Double, slot: NutritionSlot) -> FoodEntry {
        let factor = grams / 100
        return FoodEntry(
            name: brand.isEmpty ? name : "\(name) · \(brand)",
            kcal: kcalPer100g * factor,
            grams: grams,
            protein: proteinPer100g * factor,
            carbs: carbsPer100g * factor,
            fat: fatPer100g * factor,
            slot: slot,
            barcode: barcode
        )
    }
}

/// The first day of a period. Everything about the cycle is derived from the
/// gaps between these, so nothing else needs storing.
@Model
final class CycleEvent {
    var startDate: Date
    var periodLengthDays: Int
    var note: String

    init(startDate: Date, periodLengthDays: Int = 5, note: String = "") {
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.periodLengthDays = periodLengthDays
        self.note = note
    }
}
