import Foundation
import SwiftData

/// Where a drink's numbers came from.
enum BeverageSourceKind: String, Codable, CaseIterable, Identifiable {
    /// Composed from parts. A flat white is milk with a little coffee in it, so
    /// its energy moves with the milk and it has to be built, not looked up.
    case builtRecipe
    /// Barcode, through the existing `OFFClient`.
    case offProduct
    /// Typed in by hand off a label.
    case manualEntry
    /// One of the shipped rows in `BeverageLibrary`.
    case seedLibrary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .builtRecipe: "Built"
        case .offProduct:  "Barcode"
        case .manualEntry: "Manual"
        case .seedLibrary: "Library"
        }
    }
}

/// One liquid inside a built drink.
///
/// Carries its own density because a flat white is two liquids of different
/// densities and one averaged figure would be wrong for both.
struct BeverageComponent: Codable, Equatable, Hashable {
    /// The `BeverageLibrary.Item` this part came from.
    var ingredientID: UUID
    var name: String
    var volumeML: Double
    var densityGPerML: Double
    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var sugarsPer100g: Double
    var fatPer100g: Double
    var fibrePer100g: Double

    init(
        ingredientID: UUID,
        name: String,
        volumeML: Double,
        densityGPerML: Double,
        kcalPer100g: Double,
        proteinPer100g: Double = 0,
        carbsPer100g: Double = 0,
        sugarsPer100g: Double = 0,
        fatPer100g: Double = 0,
        fibrePer100g: Double = 0
    ) {
        self.ingredientID = ingredientID
        self.name = name
        self.volumeML = volumeML
        self.densityGPerML = densityGPerML
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.sugarsPer100g = sugarsPer100g
        self.fatPer100g = fatPer100g
        self.fibrePer100g = fibrePer100g
    }
}

/// A drink, kept as its own record rather than folded into the food log.
///
/// The reason is display, not judgement: liquid calories are easy to lose track
/// of because liquid carbohydrate satisfies hunger less completely than the
/// same carbohydrate eaten, so the day's drinks are worth showing as their own
/// sub-total. The app surfaces the number and says nothing about it — no
/// warning colour, no nudge (spec 3.1).
@Model
final class BeverageEntry {
    var id: UUID

    /// When it was drunk, to the minute. User-editable.
    var consumedAt: Date
    /// `.now` at insert. **Audit only** — never edited, never shown as the time
    /// of the drink. Same discipline as `MealLog`.
    var loggedAt: Date
    /// Captured at save. A coffee drunk at 08:00 abroad is still that coffee
    /// when the phone comes home.
    var timeZoneID: String

    /// Set explicitly by the user, or left `nil` for "between meals".
    ///
    /// **Never derived from the clock.** A drink at 13:00 with no slot chosen
    /// has no slot; guessing lunch from the hour turns a blank into a claim.
    var slotRaw: String?

    var name: String
    var volumeML: Double
    var densityGPerML: Double

    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var sugarsPer100g: Double
    var fatPer100g: Double
    /// Needed to convert a `.total` carbohydrate figure to the available one,
    /// and it feeds the day's fibre total like any other entry (spec 4.7).
    var fibrePer100g: Double

    /// Whether `carbsPer100g` has the fibre inside it. Recorded per entry
    /// because the answer differs by where the product was labelled (C12).
    var carbConventionRaw: String

    var sourceKindRaw: String
    var barcode: String?
    /// Built drinks only. `nil` for a scan, a library row or a manual entry.
    var recipeComponents: [BeverageComponent]?

    init(
        id: UUID = UUID(),
        name: String,
        volumeML: Double,
        densityGPerML: Double,
        kcalPer100g: Double,
        proteinPer100g: Double = 0,
        carbsPer100g: Double = 0,
        sugarsPer100g: Double = 0,
        fatPer100g: Double = 0,
        fibrePer100g: Double = 0,
        carbConvention: CarbConvention = .available,
        sourceKind: BeverageSourceKind,
        slot: MealSlot? = nil,
        barcode: String? = nil,
        recipeComponents: [BeverageComponent]? = nil,
        consumedAt: Date = .now,
        loggedAt: Date = .now,
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.name = name
        self.volumeML = volumeML
        self.densityGPerML = densityGPerML
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.sugarsPer100g = sugarsPer100g
        self.fatPer100g = fatPer100g
        self.fibrePer100g = fibrePer100g
        self.carbConventionRaw = carbConvention.rawValue
        self.sourceKindRaw = sourceKind.rawValue
        // Left exactly as handed in. There is no default slot and no fallback
        // to the current hour.
        self.slotRaw = slot?.rawValue
        self.barcode = barcode
        self.recipeComponents = recipeComponents
        self.consumedAt = BeverageEntry.roundedToMinute(consumedAt)
        self.loggedAt = loggedAt
        self.timeZoneID = timeZone.identifier
    }

    /// Seconds are noise, and storing one implies a precision nobody has about
    /// when a cup was finished.
    static func roundedToMinute(_ date: Date, calendar: Calendar = .current) -> Date {
        let seconds = calendar.component(.second, from: date)
        return calendar.date(byAdding: .second, value: -seconds, to: date) ?? date
    }

    var slot: MealSlot? {
        get { slotRaw.flatMap(MealSlot.init(rawValue:)) }
        set { slotRaw = newValue?.rawValue }
    }

    var sourceKind: BeverageSourceKind {
        get { BeverageSourceKind(rawValue: sourceKindRaw) ?? .manualEntry }
        set { sourceKindRaw = newValue.rawValue }
    }

    /// Falls back to `.unknown`, which keeps the entry's energy and leaves it
    /// out of the carbohydrate total — the safe direction for a value that
    /// failed to decode.
    var carbConvention: CarbConvention {
        get { CarbConvention(rawValue: carbConventionRaw) ?? .unknown }
        set { carbConventionRaw = newValue.rawValue }
    }

    var isBuilt: Bool { !(recipeComponents ?? []).isEmpty }
}
