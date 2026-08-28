import Foundation

/// What a drink actually contributes to the day. Absolute amounts, not per 100 g.
struct BeverageNutrition: Equatable {
    var grams: Double = 0
    var kcal: Double = 0
    var protein: Double = 0
    /// As stated, in whatever convention the entry declared. Use
    /// `BeverageCalculator.availableCarbs(of:)` before adding this to a total.
    var carbs: Double = 0
    var sugars: Double = 0
    var fat: Double = 0
    var fibre: Double = 0

    static let zero = BeverageNutrition()

    static func + (lhs: BeverageNutrition, rhs: BeverageNutrition) -> BeverageNutrition {
        BeverageNutrition(
            grams: lhs.grams + rhs.grams,
            kcal: lhs.kcal + rhs.kcal,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            sugars: lhs.sugars + rhs.sugars,
            fat: lhs.fat + rhs.fat,
            fibre: lhs.fibre + rhs.fibre
        )
    }
}

/// The arithmetic for drinks.
///
/// The whole file exists for one line — `grams = volumeML × densityGPerML` —
/// and the discipline of never skipping it. Nothing here ever derives energy
/// from the macros: a stated kilocalorie figure is the authority, and an
/// Atwater sum is only ever a cross-check (C13).
enum BeverageCalculator {

    /// Millilitres are not grams. Sugar makes a drink heavier than water, so a
    /// 330 mL can of cola is 344 g, and per-100-**gram** labels have to be
    /// scaled by the weight, not the volume.
    static func grams(volumeML: Double, densityGPerML: Double) -> Double {
        max(0, volumeML) * densityGPerML
    }

    static func kcal(volumeML: Double, densityGPerML: Double, kcalPer100g: Double) -> Double {
        grams(volumeML: volumeML, densityGPerML: densityGPerML) * (kcalPer100g / 100)
    }

    static func nutrition(of component: BeverageComponent) -> BeverageNutrition {
        let g = grams(volumeML: component.volumeML, densityGPerML: component.densityGPerML)
        let factor = g / 100
        return BeverageNutrition(
            grams: g,
            kcal: component.kcalPer100g * factor,
            protein: component.proteinPer100g * factor,
            carbs: component.carbsPer100g * factor,
            sugars: component.sugarsPer100g * factor,
            fat: component.fatPer100g * factor,
            fibre: component.fibrePer100g * factor
        )
    }

    static func nutrition(of components: [BeverageComponent]) -> BeverageNutrition {
        components.map(nutrition(of:)).reduce(.zero, +)
    }

    /// A built drink is the sum of its parts, because that is where its numbers
    /// came from. Everything else scales its own per-100-g figures.
    static func nutrition(of entry: BeverageEntry) -> BeverageNutrition {
        if let components = entry.recipeComponents, !components.isEmpty {
            return nutrition(of: components)
        }
        let g = grams(volumeML: entry.volumeML, densityGPerML: entry.densityGPerML)
        let factor = g / 100
        return BeverageNutrition(
            grams: g,
            kcal: entry.kcalPer100g * factor,
            protein: entry.proteinPer100g * factor,
            carbs: entry.carbsPer100g * factor,
            sugars: entry.sugarsPer100g * factor,
            fat: entry.fatPer100g * factor,
            fibre: entry.fibrePer100g * factor
        )
    }

    /// The entry's carbohydrate converted to the available convention, or `nil`
    /// when it cannot be — a `.total` product with no fibre recorded, or an
    /// `.unknown` one. `nil` means leave it out of the carb total, not zero.
    static func availableCarbs(of entry: BeverageEntry) -> Double? {
        let facts = nutrition(of: entry)
        return entry.carbConvention.availableCarbs(carbs: facts.carbs, fibre: facts.fibre)
    }

    static func kcal(of entries: [BeverageEntry]) -> Double {
        entries.reduce(0) { $0 + nutrition(of: $1).kcal }
    }
}

extension BeverageEntry {
    /// A drink assembled from parts.
    ///
    /// The per-100-g fields are written as the blend of the components, and the
    /// stored density as the blend of theirs, so `volumeML × density ×
    /// kcalPer100g / 100` still reproduces the total. The components stay on
    /// the entry and remain the authority.
    static func built(
        name: String,
        components: [BeverageComponent],
        slot: MealSlot? = nil,
        consumedAt: Date = .now
    ) -> BeverageEntry {
        let totals = BeverageCalculator.nutrition(of: components)
        let volume = components.reduce(0) { $0 + max(0, $1.volumeML) }
        // A drink with no volume has no blend to compute. Water's density is
        // the neutral choice and every per-100 figure below lands on zero.
        let density = volume > 0 ? totals.grams / volume : BeverageDensity.water
        func per100(_ amount: Double) -> Double {
            totals.grams > 0 ? amount / totals.grams * 100 : 0
        }

        return BeverageEntry(
            name: name,
            volumeML: volume,
            densityGPerML: density,
            kcalPer100g: per100(totals.kcal),
            proteinPer100g: per100(totals.protein),
            carbsPer100g: per100(totals.carbs),
            sugarsPer100g: per100(totals.sugars),
            fatPer100g: per100(totals.fat),
            fibrePer100g: per100(totals.fibre),
            carbConvention: .available,
            sourceKind: .builtRecipe,
            slot: slot,
            recipeComponents: components,
            consumedAt: consumedAt
        )
    }
}
