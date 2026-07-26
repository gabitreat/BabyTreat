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
    var isAllergen: Bool
    var isPriority: Bool
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
}
