import Foundation

/// Works out what one actual serving contributes.
///
/// The label is per 100 g; a person eats 43 g. This is the arithmetic in
/// between, kept apart from the screens so it can be tested on its own.
enum ServingCalculator {

    /// How the amount eaten was expressed.
    enum Amount: Equatable {
        /// Straight weight or volume.
        case measure(Double)
        /// A count of servings, each of a stated size.
        case servings(count: Double, sizeGrams: Double)

        /// The amount in grams/millilitres, which is what the label scales by.
        var grams: Double {
            switch self {
            case .measure(let value):                 max(0, value)
            case .servings(let count, let size):      max(0, count) * max(0, size)
            }
        }
    }

    /// The nutrition of what was actually eaten.
    ///
    /// Returns `nil` for any nutrient the label did not carry — an unknown
    /// scaled by any amount is still unknown, never zero.
    static func nutrition(per100: NutritionFacts, amount: Amount) -> NutritionFacts {
        per100.scaled(to: amount.grams)
    }

    /// Builds the diary row. `kcal`, `protein`, `carbs` and `fat` are
    /// non-optional on `FoodEntry`, so a missing nutrient lands as 0 there —
    /// which is why `hasCompleteMacros` exists to warn before that happens.
    static func entry(
        name: String,
        per100: NutritionFacts,
        amount: Amount,
        slot: NutritionSlot,
        barcode: String? = nil,
        timestamp: Date = .now
    ) -> FoodEntry {
        let eaten = nutrition(per100: per100, amount: amount)
        let servingCount: Double? = {
            if case .servings(let count, _) = amount { return count }
            return nil
        }()

        return FoodEntry(
            name: name,
            kcal: eaten.kcal ?? 0,
            grams: amount.grams,
            servings: servingCount,
            protein: eaten.protein ?? 0,
            carbs: eaten.carbs ?? 0,
            fat: eaten.fat ?? 0,
            slot: slot,
            barcode: barcode,
            timestamp: timestamp
        )
    }

    /// Whether the four values the diary stores were all actually on the label.
    static func hasCompleteMacros(_ facts: NutritionFacts) -> Bool {
        facts.kcal != nil && facts.protein != nil && facts.carbs != nil && facts.fat != nil
    }

    /// Which of them are missing, for the warning text.
    static func missingMacros(_ facts: NutritionFacts) -> [String] {
        var missing: [String] = []
        if facts.kcal == nil    { missing.append("calories") }
        if facts.protein == nil { missing.append("protein") }
        if facts.carbs == nil   { missing.append("carbs") }
        if facts.fat == nil     { missing.append("fat") }
        return missing
    }
}
