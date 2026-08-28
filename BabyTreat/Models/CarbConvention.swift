import Foundation

/// Whether a carbohydrate figure has fibre inside it.
///
/// Not a detail. The US and Canada print "Total Carbohydrates" with fibre
/// counted in; the EU prints "Carbohydrates" with fibre taken out and listed on
/// its own line. Open Food Facts has a single `carbohydrates` field holding
/// whatever the package said and does not record which of the two it is (OFF
/// server issue #5675). Adding an American figure to a Romanian one without
/// asking overstates the day by the fibre content of every US product in it.
///
/// The budget is kept in **available** carbohydrate, because that is what
/// Romanian labels print.
enum CarbConvention: String, Codable, CaseIterable, Identifiable {
    /// EU / Codex. Fibre excluded from the carbohydrate figure and carrying its
    /// own 2 kcal/g under Regulation 1169/2011.
    case available
    /// US / Canada. Fibre included in the carbohydrate figure.
    case total
    /// Which convention applies was never established. Still counted for
    /// energy — the kilocalories on the label are not in doubt — but kept out
    /// of the carbohydrate total and marked in the list.
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .available: "Available carbs (EU)"
        case .total:     "Total carbs (US)"
        case .unknown:   "Carb basis unknown"
        }
    }
}

extension CarbConvention {
    /// The carbohydrate figure converted to the available convention.
    ///
    /// `nil` means **leave this out of the carbohydrate total**, and never
    /// zero: a `.total` product with no fibre recorded cannot be converted, and
    /// guessing zero fibre would count its fibre as sugar and starch.
    func availableCarbs(carbs: Double, fibre: Double?) -> Double? {
        switch self {
        case .available:
            return carbs
        case .total:
            guard let fibre else { return nil }
            // A label that prints more fibre than carbohydrate is a bad record,
            // not a negative quantity of food.
            return max(0, carbs - fibre)
        case .unknown:
            return nil
        }
    }

    /// What to assume for a product Open Food Facts just handed back.
    ///
    /// The app only ever queries `ro.openfoodfacts.org`, so the working
    /// assumption is the EU convention. North American country tags override
    /// it. A product fetched from anywhere else is left `.unknown` rather than
    /// guessed, because once a guess is stored it is indistinguishable from a
    /// fact.
    static func forOpenFoodFacts(
        countryTags: [String],
        fromRomanianSubdomain: Bool = true
    ) -> CarbConvention {
        let tags = countryTags.map { tag -> String in
            // OFF tags arrive language-prefixed, e.g. "en:united-states".
            let stripped = tag.contains(":")
                ? tag.split(separator: ":").dropFirst().joined(separator: ":")
                : tag
            return String(stripped).lowercased()
        }

        let northAmerican: Set<String> = [
            "united-states", "united-states-of-america", "usa", "us",
            "canada", "ca",
        ]
        if tags.contains(where: northAmerican.contains) { return .total }

        return fromRomanianSubdomain ? .available : .unknown
    }
}
