import Foundation

/// Finds foods that behave differently together than they do apart, in both
/// directions: a combination that gets refused, and a carrier that rescues
/// something otherwise rejected.
///
/// Pure functions over `[LoggedMeal]`.
enum PairEffectEngine {

    // MARK: - Thresholds

    /// Meals containing both foods before the maths means anything.
    static let minSharedMeals = 3
    /// …and before it is called confirmed rather than suspected.
    static let confirmSharedMeals = 6
    /// Meals containing one food **without** the other. Without these there is
    /// no baseline to compare against.
    static let minSoloMeals = 4
    /// How far apart observed and expected have to be. 0.30 is roughly one full
    /// step on the portion scale — half a bowl instead of most of it.
    static let deltaThreshold = 0.30

    /// How to combine two solo rates into what the pair *should* have scored.
    enum ExpectedModel {
        /// The average of the two. Treats the meal as a blend.
        case mean
        /// The worse of the two. Assumes the weaker food sets the ceiling —
        /// stricter, so it finds fewer negative effects.
        case min
    }

    // MARK: - Output

    enum Confidence: Equatable {
        case suspected
        case confirmed
    }

    enum Verdict: Equatable {
        /// Worse together than apart.
        case negative(Confidence)
        /// Better together — the carrier case.
        case positive(Confidence)
        case neutral
        /// Not enough separated data. `needs` says what to serve apart.
        case insufficient(needs: [String])
    }

    struct PairEffect: Identifiable {
        /// Sorted, so a pair appears once however it was served.
        let a: String
        let b: String
        let rateA: Double
        let rateB: Double
        let expected: Double
        let observed: Double
        let delta: Double
        let sharedMeals: Int
        let soloA: Int
        let soloB: Int
        let verdict: Verdict

        var id: String { "\(a)|\(b)" }

        var isActionable: Bool {
            switch verdict {
            case .negative, .positive: true
            case .neutral, .insufficient: false
            }
        }

        var confidence: Confidence? {
            switch verdict {
            case .negative(let c), .positive(let c): c
            case .neutral, .insufficient: nil
            }
        }

        /// Shared meals still needed before a suspected effect is confirmed.
        var mealsToConfirm: Int { max(0, PairEffectEngine.confirmSharedMeals - sharedMeals) }
    }

    // MARK: - Analysis

    static func analyze(
        meals: [LoggedMeal],
        model: ExpectedModel = .mean
    ) -> [PairEffect] {
        let scorable = meals.filter(isScorable)
        guard scorable.count >= minSharedMeals else { return [] }

        // Every pair that has ever shared a plate.
        var pairs = Set<String>()
        for meal in scorable {
            let ids = Array(Set(meal.foodIDs)).sorted()
            for i in ids.indices {
                for j in ids.indices where j > i {
                    pairs.insert("\(ids[i])|\(ids[j])")
                }
            }
        }

        return pairs
            .compactMap { key -> PairEffect? in
                let parts = key.split(separator: "|").map(String.init)
                guard parts.count == 2 else { return nil }
                return effect(for: parts[0], and: parts[1], in: scorable, model: model)
            }
            .sorted { lhs, rhs in
                if lhs.isActionable != rhs.isActionable { return lhs.isActionable }
                return abs(lhs.delta) > abs(rhs.delta)
            }
    }

    static func effect(
        for a: String,
        and b: String,
        in scorable: [LoggedMeal],
        model: ExpectedModel = .mean
    ) -> PairEffect? {
        // The `AND NOT` on each solo set is load-bearing. Score A over every meal
        // containing A and you include the shared ones, so a food only ever
        // served alongside one partner has rateA == observed and a delta pinned
        // near zero — invisible in exactly the case worth finding.
        let soloA = scorable.filter { $0.foodIDs.contains(a) && !$0.foodIDs.contains(b) }
        let soloB = scorable.filter { $0.foodIDs.contains(b) && !$0.foodIDs.contains(a) }
        let shared = scorable.filter { $0.foodIDs.contains(a) && $0.foodIDs.contains(b) }

        guard !shared.isEmpty else { return nil }

        let rateA = mean(soloA)
        let rateB = mean(soloB)
        let observed = mean(shared)
        let expected = switch model {
        case .mean: (rateA + rateB) / 2
        case .min:  Swift.min(rateA, rateB)
        }
        let delta = observed - expected

        var needs: [String] = []
        if shared.count < minSharedMeals { needs.append("both together") }
        if soloA.count < minSoloMeals { needs.append(a) }
        if soloB.count < minSoloMeals { needs.append(b) }

        let verdict: Verdict
        if !needs.isEmpty {
            verdict = .insufficient(needs: needs)
        } else if delta <= -deltaThreshold {
            verdict = .negative(confidence(for: shared.count))
        } else if delta >= deltaThreshold {
            verdict = .positive(confidence(for: shared.count))
        } else {
            verdict = .neutral
        }

        return PairEffect(
            a: a, b: b,
            rateA: rateA, rateB: rateB,
            expected: expected, observed: observed, delta: delta,
            sharedMeals: shared.count, soloA: soloA.count, soloB: soloB.count,
            verdict: verdict
        )
    }

    /// A physiological reaction is not a preference signal, so anything carrying
    /// a real flag is out. Dislikes stay in — a taste refusal is precisely the
    /// signal being measured. Meals marked as off (illness, teething) are out too.
    static func isScorable(_ meal: LoggedMeal) -> Bool {
        if meal.excludeFromTaste { return false }
        if let tolerance = meal.tolerance, tolerance != .dislike { return false }
        return !meal.foodIDs.isEmpty
    }

    private static func mean(_ meals: [LoggedMeal]) -> Double {
        guard !meals.isEmpty else { return 0 }
        return meals.reduce(0.0) { $0 + $1.portion.score } / Double(meals.count)
    }

    private static func confidence(for sharedMeals: Int) -> Confidence {
        sharedMeals >= confirmSharedMeals ? .confirmed : .suspected
    }

    // MARK: - Consequences

    static func key(_ a: String, _ b: String) -> String {
        let sorted = [a, b].sorted()
        return "\(sorted[0])|\(sorted[1])"
    }

    /// Pairs to keep off a menu. Confirmed negatives only — a suspected effect
    /// is a reason to keep watching, not to act.
    ///
    /// Note what this does **not** do: neither food is downgraded. Both stay
    /// individually available, because individually there is nothing wrong with
    /// either of them. That is the entire point of measuring the pair.
    static func blockedPairs(from effects: [PairEffect]) -> Set<String> {
        Set(effects.compactMap { effect in
            effect.verdict == .negative(.confirmed) ? key(effect.a, effect.b) : nil
        })
    }

    /// Carrier dependencies: `[carried food: carriers]`. A food that only scores
    /// well alongside its carrier has **not** been proven on its own, and should
    /// not be counted as accepted.
    static func carriers(from effects: [PairEffect]) -> [String: [String]] {
        var out: [String: [String]] = [:]
        for effect in effects {
            guard case .positive = effect.verdict else { continue }
            // The carried food is the weaker one on its own.
            let (carried, carrier) = effect.rateA <= effect.rateB
                ? (effect.a, effect.b)
                : (effect.b, effect.a)
            out[carried, default: []].append(carrier)
        }
        return out
    }
}
