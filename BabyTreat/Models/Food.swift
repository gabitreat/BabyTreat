import Foundation
import SwiftData
import SwiftUI

enum FoodStatus: String, Codable, CaseIterable {
    case accepted
    case weak
    case planned

    var label: String {
        switch self {
        case .accepted: "Accepted"
        case .weak:     "Weak acceptance"
        case .planned:  "To introduce"
        }
    }
}

/// Coarse type used by the introduction suggester — a new *vegetable* and a new
/// *fruit* each week are proposed separately.
enum FoodKind: String, Codable {
    case veg, fruct, proteina, cereale, grasime, altul
}

/// Nutritional groups a food belongs to. A food can be in several: sweet potato
/// is both `veg` and `amidon`, which is deliberate — see rules.md.
enum FoodGroup: String, Codable {
    case veg, fruct, amidon, proteina
    case asf        // animal-source food — WHO: daily
    case fier       // iron
    case grasime    // fat
    case omega3
    case lactate    // dairy — gated behind the APLV hold
}

@Model
final class Food {
    @Attribute(.unique) var id: String
    var name: String
    var category: String        // Legume · Fructe · Cereale · Proteine · Grăsimi · Planificate
    var colorHex: String
    var statusRaw: String
    var rating: Int
    var kindRaw: String?
    var groupsRaw: [String]
    /// Months (1–12) this food is in season in Romania. Empty = year-round.
    var season: [Int]
    /// **The gating flag.** Drives rotation gating and exposure counting — egg,
    /// salmon, peanut butter. Kept deliberately separate from `family`, which is
    /// taxonomy and must never gate anything: collapsing the two is what causes
    /// false blocks (coconut suppressed as a tree nut, carob as a peanut).
    var isAllergen: Bool
    var isPriority: Bool

    /// Whether this counts toward rotation. Optional in the store so foods
    /// written before roles existed migrate cleanly; read through `role`, which
    /// treats a missing value as `.base` — the behaviour before this field.
    var roleRaw: String?
    /// Taxonomy, for **menu diversity only**. See `AllergenFamily`.
    var familyRaw: String?
    /// Earliest age this may be served at all.
    var minAgeMonths: Int?
    /// Age below which this must not be served as a **standalone drink**, even
    /// though it is fine in cooking. Plant milks are not formulated as a main
    /// drink under 12 months and using one as such risks real deficiency.
    var drinkBlockedUnderMonths: Int?
    /// Nitrate load, for **batch storage safety only** (see `NitrateRisk`).
    /// Never reaches allergen gating or diversity scoring.
    var nitrateRiskRaw: String?

    /// Suggestions will not propose this food before this date (APLV hold).
    var holdUntil: Date?
    var triedOn: Date?
    var retryOn: Date?
    var note: String?

    init(
        id: String,
        name: String,
        category: String,
        colorHex: String,
        status: FoodStatus,
        rating: Int = 0,
        kind: FoodKind? = nil,
        groups: [FoodGroup] = [],
        season: [Int] = [],
        isAllergen: Bool = false,
        isPriority: Bool = false,
        role: IngredientRole = .base,
        family: AllergenFamily = .none,
        minAgeMonths: Int? = nil,
        drinkBlockedUnderMonths: Int? = nil,
        nitrateRisk: NitrateRisk? = nil,
        holdUntil: Date? = nil,
        triedOn: Date? = nil,
        retryOn: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.colorHex = colorHex
        self.statusRaw = status.rawValue
        self.rating = rating
        self.kindRaw = kind?.rawValue
        self.groupsRaw = groups.map(\.rawValue)
        self.season = season
        self.isAllergen = isAllergen
        self.isPriority = isPriority
        self.roleRaw = role.rawValue
        self.familyRaw = family.rawValue
        self.minAgeMonths = minAgeMonths
        self.drinkBlockedUnderMonths = drinkBlockedUnderMonths
        self.nitrateRiskRaw = nitrateRisk?.rawValue
        self.holdUntil = holdUntil
        self.triedOn = triedOn
        self.retryOn = retryOn
        self.note = note
    }

    var status: FoodStatus {
        get { FoodStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var groups: [FoodGroup] {
        groupsRaw.compactMap(FoodGroup.init(rawValue:))
    }

    var color: Color { Color(hex: colorHex) }

    /// Falls back to the category when no explicit kind is set, mirroring
    /// `KIND_BY_CAT` in the prototype.
    var kind: FoodKind {
        if let kindRaw, let kind = FoodKind(rawValue: kindRaw) { return kind }
        switch category {
        case MealSeed.categoryVegetables: return .veg
        case MealSeed.categoryFruit:      return .fruct
        case MealSeed.categoryProtein:    return .proteina
        case MealSeed.categoryGrains:     return .cereale
        case MealSeed.categoryFats:       return .grasime
        default:                          return .altul
        }
    }

    func isInSeason(on date: Date, calendar: Calendar = .current) -> Bool {
        season.isEmpty || season.contains(calendar.component(.month, from: date))
    }

    func isHeld(on date: Date) -> Bool {
        guard let holdUntil else { return false }
        return date < holdUntil
    }

    func has(_ group: FoodGroup) -> Bool { groupsRaw.contains(group.rawValue) }

    /// Missing means `.base` — the behaviour every food had before roles existed.
    var role: IngredientRole {
        get { roleRaw.flatMap(IngredientRole.init(rawValue:)) ?? .base }
        set { roleRaw = newValue.rawValue }
    }

    /// Nitrate load. An untagged food is read from its kind rather than assumed
    /// safe: an unknown **vegetable** is `.moderate`, because guessing `.low` on
    /// something that turns out to be a leafy green is the one error here with a
    /// clinical cost. Anything else — meat, fruit, grain, fat — is `.low`.
    var nitrateRisk: NitrateRisk {
        get {
            if let raw = nitrateRiskRaw, let risk = NitrateRisk(rawValue: raw) { return risk }
            return kind == .veg ? .moderate : .low
        }
        set { nitrateRiskRaw = newValue.rawValue }
    }

    var family: AllergenFamily {
        get { familyRaw.flatMap(AllergenFamily.init(rawValue:)) ?? .none }
        set { familyRaw = newValue.rawValue }
    }

    /// Old enough to be served at all.
    func isAgeAppropriate(atAgeMonths months: Int) -> Bool {
        guard let minAgeMonths else { return true }
        return months >= minAgeMonths
    }

    /// Fine in cooking, not fine in a cup. Returns the explanation when the
    /// child is too young, so the block can never appear without its reason.
    func drinkBlockReason(atAgeMonths months: Int) -> String? {
        guard let limit = drinkBlockedUnderMonths, months < limit else { return nil }
        return "\(name) can be used in cooking from \(minAgeMonths ?? 6) months, but not as a drink before \(limit) months. Plant milks are not formulated as a main drink at this age and using one as such risks serious nutritional deficiency."
    }
}
