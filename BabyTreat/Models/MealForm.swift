import Foundation

/// The physical form a meal takes at the table.
///
/// This is texture, not nutrition. It exists so the dinner suggestion filter can
/// say "soups only this month" without needing to understand recipes, and so the
/// texture-progression reminder has something concrete to point at.
enum MealForm: String, Codable, CaseIterable, Identifiable {
    /// Liquid or blended, spoon-fed.
    case soup
    case puree
    case mashed
    case fingerFood

    var id: String { rawValue }

    var label: String {
        switch self {
        case .soup:       "Soup"
        case .puree:      "Purée"
        case .mashed:     "Mashed"
        case .fingerFood: "Finger food"
        }
    }

    /// Roughly how much chewing this asks for. Used by the texture reminder —
    /// a week of nothing but `.soup` and `.puree` is worth mentioning at 8 months.
    var advancesTexture: Bool {
        switch self {
        case .soup, .puree:       false
        case .mashed, .fingerFood: true
        }
    }
}

/// How much nitrate an ingredient carries into a batch.
///
/// This is a **storage-safety** axis and nothing else — it must never reach
/// allergen gating or diversity scoring. Improper storage of cooked vegetables
/// converts nitrate to nitrite in situ, which is the mechanism behind the
/// methaemoglobinaemia case series in infants averaging 8 months old, all fed
/// homemade mixed-vegetable purée refrigerated for 12–27 hours. Freezing halts
/// the conversion; a second day in the fridge does not.
///
/// See `Tasks/babytreat-soup-dinner-rule-spec.md` § Part 3 for the sourcing.
enum NitrateRisk: String, Codable, CaseIterable, Identifiable, Comparable {
    /// Potato, meat, rice, most fruit.
    case low
    /// Carrot, courgette, green beans, squash.
    case moderate
    /// Spinach, chard, beetroot, lettuce, fennel.
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:      "Low nitrate"
        case .moderate: "Moderate nitrate"
        case .high:     "High nitrate"
        }
    }

    /// The longest a batch containing this ingredient may span.
    ///
    /// A high-nitrate ingredient locks the batch to a single day. This is the
    /// rule the whole enum exists to serve.
    var maxBatchSpanDays: Int { self == .high ? 1 : 2 }

    private var order: Int {
        switch self {
        case .low: 0
        case .moderate: 1
        case .high: 2
        }
    }

    static func < (lhs: NitrateRisk, rhs: NitrateRisk) -> Bool { lhs.order < rhs.order }
}
