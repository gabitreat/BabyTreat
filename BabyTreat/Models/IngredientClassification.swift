import Foundation

/// What an ingredient is *doing* in a meal.
///
/// Only `.base` consumes a rotation slot. A teaspoon of olive oil and a pinch of
/// cinnamon are logged, timestamped and attributable, but counting them as
/// exposures would fill the rotation meter with things that were never the point.
enum IngredientRole: String, Codable, CaseIterable, Identifiable {
    /// A real portion of a real food. Counts toward rotation exposure.
    case base
    /// Flavour or fat carrier. Logged, consumes no rotation slot.
    case accent
    /// E-numbers and thickeners, usually hidden inside formula and packaged
    /// food. Invisible to rotation, but visible to attribution — a background
    /// exposure nobody chose still has to be a candidate.
    case additive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .base:     "Base"
        case .accent:   "Accent"
        case .additive: "Additive"
        }
    }

    /// The single rule this enum exists for.
    var consumesRotationSlot: Bool { self == .base }
}

/// Botanical / taxonomic grouping.
///
/// CRITICAL — this drives **menu diversity scoring only**: it is what stops
/// three legumes landing in one week. It must never gate an exposure.
/// Allergen gating is `Food.isAllergen`, and the two are kept apart on purpose.
///
/// Coconut is the worked example. It is botanically a drupe, and the FDA's
/// 5th-edition allergen guidance removed it from the major tree-nut list —
/// most children with a tree-nut allergy tolerate it. Tagging it `treeNut`
/// would suppress a perfectly safe food, so it gets its own family,
/// `arecaceae`, the palm family.
///
/// Carob is the same shape of mistake in the other direction: it is a legume by
/// family, but studies find little cross-reactivity between legume members and
/// specifically none between carob and peanut. Its `legume` tag is for
/// diversity, and must not gate on a peanut flag.
enum AllergenFamily: String, Codable, CaseIterable, Identifiable {
    case dairy, egg, peanut, treeNut, legume, sesame, fish, shellfish
    case wheat, soy
    /// The palm family — coconut, dates. Deliberately not `treeNut`.
    case arecaceae
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dairy:     "Dairy"
        case .egg:       "Egg"
        case .peanut:    "Peanut"
        case .treeNut:   "Tree nut"
        case .legume:    "Legume"
        case .sesame:    "Sesame"
        case .fish:      "Fish"
        case .shellfish: "Shellfish"
        case .wheat:     "Wheat"
        case .soy:       "Soy"
        case .arecaceae: "Palm family"
        case .none:      "—"
        }
    }
}
