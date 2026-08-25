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

        // A label is a table. Vision sometimes returns a row as one line
        // ("Grăsimi 6,8 g") and sometimes as two ("Grăsimi", then "6,8 g"),
        // depending on how far apart the columns are printed. When a line names
        // a nutrient but carries no number, it is held here and filled by the
        // next line that does.
        var pending: Nutrient?

        func record(_ nutrient: Nutrient, _ value: Double, _ unit: Unit) {
            switch nutrient {
            case .energyKcal:
                facts.kcal = value
                sawKcal = true
            case .energyKJ:
                // Only fall back to kJ if no kcal figure turns up anywhere.
                if !sawKcal, facts.kcal == nil {
                    facts.kcal = value / NutritionFacts.kilojoulesPerKcal
                    facts.energyWasDerived = true
                }
            case .fat:          facts.fat = facts.fat ?? grams(value, unit)
            case .saturatedFat: facts.saturatedFat = facts.saturatedFat ?? grams(value, unit)
            case .carbs:        facts.carbs = facts.carbs ?? grams(value, unit)
            case .sugars:       facts.sugars = facts.sugars ?? grams(value, unit)
            case .fiber:        facts.fiber = facts.fiber ?? grams(value, unit)
            case .protein:      facts.protein = facts.protein ?? grams(value, unit)
            case .salt:         facts.salt = facts.salt ?? grams(value, unit)
            case .sodium:       facts.sodium = facts.sodium ?? grams(value, unit)
            }
        }

        for raw in lines {
            let line = normalise(raw)

            if let match = match(line: line) {
                record(match.nutrient, match.value, match.unit)
                pending = nil
                continue
            }

            // A nutrient name on its own — remember it for the next value.
            if let named = nutrient(named: line) {
                pending = named
                continue
            }

            // A value on its own — belongs to whatever was named last.
            if let waiting = pending {
                if waiting == .energyKcal || waiting == .energyKJ {
                    if let kcal = firstNumber(in: line, followedBy: ["kcal"]) {
                        record(.energyKcal, kcal, .kcal)
                        pending = nil
                        continue
                    }
                    if let kj = firstNumber(in: line, followedBy: ["kj"]) {
                        record(.energyKJ, kj, .kJ)
                        pending = nil
                        continue
                    }
                }
                if let value = numbers(in: line).first, isValueOnly(line) {
                    record(waiting, value, unit(of: line))
                    pending = nil
                }
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

    /// The nutrient a line names, when it names one and carries no value of its
    /// own. Energy is included so a bare "Valoare energetică" can be held too.
    static func nutrient(named line: String) -> Nutrient? {
        guard numbers(in: line).isEmpty else { return nil }
        if line.contains("energ") || line.contains("valoare energetica") { return .energyKcal }
        for (nutrient, phrases) in vocabulary where phrases.contains(where: { line.contains($0) }) {
            return nutrient
        }
        return nil
    }

    /// Whether a line is just a number and a unit — the value column of a table.
    ///
    /// Guards against a stray "best before 2027" or "contains 4 portions" being
    /// swallowed as the value of whatever nutrient was named above it.
    static func isValueOnly(_ line: String) -> Bool {
        let stripped = line
            .replacingOccurrences(of: #"[\d.,]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\b(g|mg|kj|kcal|ml)\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty
    }

    private static func unit(of line: String) -> Unit {
        line.contains("mg") ? .milligrams : .grams
    }

    // MARK: - One line

    static func match(line: String) -> Match? {
        // Energy is its own shape: one line usually carries both kJ and kcal.
        if line.contains("energ") || line.contains("valoare energetica") {
            // Units printed against the numbers settle it outright.
            if let kcal = firstNumber(in: line, followedBy: ["kcal"]) {
                return Match(nutrient: .energyKcal, value: kcal, unit: .kcal)
            }
            if let kj = firstNumber(in: line, followedBy: ["kj"]) {
                return Match(nutrient: .energyKJ, value: kj, unit: .kJ)
            }
            // Romanian labels commonly print the pair bare, as "200/1000".
            if let kcal = kcalFromBarePair(line) {
                return Match(nutrient: .energyKcal, value: kcal, unit: .kcal)
            }
            // A single bare number is genuinely ambiguous — it could be either
            // unit — so it is left for the person to type rather than guessed.
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

    /// The kcal figure from an energy line that prints both numbers without
    /// units, e.g. "Valoare energetică 200/1000".
    ///
    /// Decided by size, not by position: kJ is always about 4.2× the kcal
    /// figure, so of the two the **smaller** is kcal. That is arithmetic rather
    /// than a printing convention, so it holds whichever way round the label
    /// puts them — and Romanian labels put kcal first while EU labels usually
    /// put kJ first.
    static func kcalFromBarePair(_ line: String) -> Double? {
        let values = numbers(in: line).filter { $0 > 0 }
        guard values.count >= 2 else { return nil }

        // Take the two largest, so a stray "100" from "per 100 g" on the same
        // row cannot be mistaken for one of the energy figures.
        let candidates = values.sorted(by: >).prefix(2)
        guard let high = candidates.first, let low = candidates.last, high != low else { return nil }

        // Sanity: the pair really should be the same energy in two units.
        let ratio = high / low
        guard ratio > 3.0, ratio < 5.5 else { return nil }
        return low
    }

    private static func grams(_ value: Double, _ unit: Unit) -> Double {
        unit == .milligrams ? value / 1000 : value
    }
}
