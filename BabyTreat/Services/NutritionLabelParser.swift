import Foundation

/// Reads a nutrition table out of the lines of text a label scan produces.
///
/// Labels are messy: two languages side by side, a per-100 g column next to a
/// per-serving one, commas for decimal points, and OCR that turns `0` into `O`.
/// Everything here is best-effort and **every field stays optional** — a value
/// this cannot find is left `nil` for the person to fill in, never guessed at.
/// A wrong number in a food diary is worse than a blank one.
enum NutritionLabelParser {

    /// What a single line resolved to.
    struct Match: Equatable {
        var nutrient: Nutrient
        var value: Double
        var unit: Unit
    }

    enum Nutrient: String, CaseIterable {
        case energyKJ, energyKcal, fat, saturatedFat, carbs, sugars, fiber, protein, salt, sodium
    }

    enum Unit: Equatable { case kcal, kJ, grams, milligrams }

    // MARK: - Vocabulary

    /// Romanian first, then English. Order matters within a nutrient: the more
    /// specific phrase has to be tested before the generic one, or "din care
    /// zaharuri" matches plain "carbohydrates".
    private static let vocabulary: [(Nutrient, [String])] = [
        (.saturatedFat, ["acizi grasi saturati", "acizi grași saturați", "grasimi saturate", "grăsimi saturate",
                         "of which saturates", "saturated fat", "saturates", "din care saturate"]),
        (.sugars,       ["din care zaharuri", "zaharuri", "of which sugars", "sugars", "sugar"]),
        (.fat,          ["grasimi", "grăsimi", "lipide", "total fat", "fat"]),
        (.carbs,        ["glucide", "carbohidrati", "carbohidrați", "carbohydrate", "carbohydrates", "total carbohydrate"]),
        (.fiber,        ["fibre alimentare", "fibre", "dietary fibre", "dietary fiber", "fibre", "fiber"]),
        (.protein,      ["proteine", "protein"]),
        (.salt,         ["sare", "salt"]),
        (.sodium,       ["sodiu", "sodium"]),
    ]

    /// Sodium and salt both exist on labels and are not the same number.
    /// salt = sodium × 2.5, the factor the EU regulation fixes.
    static let saltPerSodium = 2.5

    // MARK: - Entry point

    /// Parses OCR lines into facts **per 100 g/ml**.
    ///
    /// Lines are expected roughly in reading order. Where a line carries two
    /// columns — per 100 g and per portion — the **first** number is taken,
    /// because per 100 g is printed first on EU labels. That is a convention,
    /// not a guarantee, which is why the result is always shown for review
    /// before anything is logged.
    static func parse(lines: [String]) -> NutritionFacts {
        var facts = NutritionFacts()
        var sawKcal = false

        for raw in lines {
            let line = normalise(raw)
            guard let match = match(line: line) else { continue }

            switch match.nutrient {
            case .energyKcal:
                facts.kcal = match.value
                sawKcal = true
            case .energyKJ:
                // Only fall back to kJ if no kcal figure turns up anywhere.
                if !sawKcal, facts.kcal == nil {
                    facts.kcal = match.value / NutritionFacts.kilojoulesPerKcal
                    facts.energyWasDerived = true
                }
            case .fat:          facts.fat = facts.fat ?? grams(match)
            case .saturatedFat: facts.saturatedFat = facts.saturatedFat ?? grams(match)
            case .carbs:        facts.carbs = facts.carbs ?? grams(match)
            case .sugars:       facts.sugars = facts.sugars ?? grams(match)
            case .fiber:        facts.fiber = facts.fiber ?? grams(match)
            case .protein:      facts.protein = facts.protein ?? grams(match)
            case .salt:         facts.salt = facts.salt ?? grams(match)
            case .sodium:       facts.sodium = facts.sodium ?? grams(match)
            }
        }

        // Fill whichever of salt/sodium the label left out.
        if facts.salt == nil, let sodium = facts.sodium {
            facts.salt = sodium * saltPerSodium
        }
        if facts.sodium == nil, let salt = facts.salt {
            facts.sodium = salt / saltPerSodium
        }

        facts.per100 = .grams
        return facts
    }

    // MARK: - One line

    static func match(line: String) -> Match? {
        // Energy is its own shape: one line often carries both kJ and kcal.
        if line.contains("energ") || line.contains("valoare energetica") {
            let numbers = numbers(in: line)
            if let kcal = firstNumber(in: line, followedBy: ["kcal"]) {
                return Match(nutrient: .energyKcal, value: kcal, unit: .kcal)
            }
            if let kj = firstNumber(in: line, followedBy: ["kj"]) {
                return Match(nutrient: .energyKJ, value: kj, unit: .kJ)
            }
            // A bare number on an energy line is ambiguous; skip rather than guess.
            _ = numbers
            return nil
        }

        for (nutrient, phrases) in vocabulary {
            guard phrases.contains(where: { line.contains($0) }) else { continue }
            guard let value = numbers(in: line).first else { return nil }
            let unit: Unit = line.contains("mg") && !line.contains("100 g") ? .milligrams : .grams
            return Match(nutrient: nutrient, value: value, unit: unit)
        }
        return nil
    }

    // MARK: - Numbers

    /// Lower-cased, diacritics kept, commas turned into decimal points, and the
    /// commonest OCR confusions for digits repaired.
    static func normalise(_ line: String) -> String {
        var text = line.lowercased()
        // "1,5" is a decimal in Romanian. Only convert a comma sitting between
        // two digits, so a list like "salt, sugar" is untouched.
        text = text.replacingOccurrences(
            of: #"(?<=\d),(?=\d)"#, with: ".", options: .regularExpression)
        // OCR reads a lone letter O inside a number as the letter, not zero.
        text = text.replacingOccurrences(
            of: #"(?<=\d)[oO](?=\d|\b)"#, with: "0", options: .regularExpression)
        return text
    }

    static func numbers(in line: String) -> [Double] {
        let pattern = #"\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap {
            Range($0.range, in: line).flatMap { Double(line[$0]) }
        }
    }

    /// The number immediately preceding one of the given unit words.
    static func firstNumber(in line: String, followedBy units: [String]) -> Double? {
        for unit in units {
            let pattern = #"(\d+(?:\.\d+)?)\s*"# + NSRegularExpression.escapedPattern(for: unit)
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(line.startIndex..., in: line)
            if let m = regex.firstMatch(in: line, range: range),
               let r = Range(m.range(at: 1), in: line),
               let value = Double(line[r]) {
                return value
            }
        }
        return nil
    }

    private static func grams(_ match: Match) -> Double {
        match.unit == .milligrams ? match.value / 1000 : match.value
    }
}
