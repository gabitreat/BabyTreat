import Foundation

/// Which physical state a per-100 g figure describes.
///
/// Carried explicitly on every `NutritionFacts` and never defaulted implicitly,
/// because the same food gives wildly different numbers depending on it: 100 g
/// of dry rice is roughly 360 kcal, 100 g of boiled rice roughly 130. Water has
/// no calories; only the basis explains the gap.
enum WeightBasis: String, Codable, CaseIterable, Identifiable {
    /// As sold, uncooked. Everything from Open Food Facts is this.
    case raw
    /// Dry weight before hydration — grains, pasta, pulses.
    case dry
    /// Weight after cooking.
    case cooked

    var id: String { rawValue }

    var label: String {
        switch self {
        case .raw:    "Raw / as sold"
        case .dry:    "Dry"
        case .cooked: "Cooked"
        }
    }
}

/// Whether per-100 figures are per 100 g or per 100 ml.
enum NutritionUnit: String, Codable {
    case grams
    case millilitres

    var short: String { self == .grams ? "g" : "ml" }
}
