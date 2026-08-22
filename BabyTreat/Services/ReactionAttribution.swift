import Foundation

/// Ranks which foods could plausibly explain an observed reaction, by how long
/// before it they were eaten.
///
/// Pure functions, no SwiftData writes. Never returns "the cause" — only
/// candidates, ordered, each carrying the mechanism that makes it plausible.
enum ReactionAttribution {

    /// One row of the onset-time table.
    struct Window {
        /// Hours since the meal, inclusive lower bound, exclusive upper.
        let from: Double
        let to: Double
        let weight: Double
        /// Why a meal this old is still a candidate — shown in the UI so a
        /// three-hour-old lunch does not look like a bug.
        let mechanism: String
    }

    /// Exposed as a named constant rather than inline numbers so it can be
    /// tuned without hunting through the scoring loop.
    ///
    /// The boundaries follow the recognised onset patterns: IgE-mediated
    /// reactions are classified by onset within 2 hours; acute FPIES presents as
    /// repetitive vomiting 1–4 hours after ingestion, with diarrhoea typically
    /// 5–10 hours; T-cell mediated and eczema responses run beyond 24 hours.
    static let windows: [Window] = [
        Window(from: 0,  to: 2,  weight: 1.00, mechanism: "IgE-mediated — onset within 2 h"),
        Window(from: 2,  to: 4,  weight: 0.80, mechanism: "Acute FPIES — repetitive vomiting 1–4 h"),
        Window(from: 4,  to: 10, weight: 0.50, mechanism: "FPIES diarrhoea — typically 5–10 h"),
        Window(from: 10, to: 24, weight: 0.25, mechanism: "Non-IgE gastrointestinal"),
        Window(from: 24, to: 48, weight: 0.10, mechanism: "T-cell mediated / eczema flare — over 24 h"),
    ]

    /// Beyond this, discard.
    static let horizonHours: Double = 48

    struct Candidate: Identifiable {
        let foodID: String
        let score: Double
        /// Every meal that contributed, newest first.
        let contributions: [Contribution]
        var id: String { foodID }

        /// The mechanism of the strongest contributing meal.
        var leadingMechanism: String? { contributions.max { $0.weight < $1.weight }?.mechanism }
    }

    struct Contribution {
        let mealDate: Date
        let slot: MealSlot
        let dish: String
        let hoursBefore: Double
        /// The meal's own weight, before it was split across its foods.
        let weight: Double
        /// Foods sharing that weight.
        let foodsInMeal: Int
        let mechanism: String

        var share: Double { foodsInMeal > 0 ? weight / Double(foodsInMeal) : 0 }
    }

    static func window(hoursBefore hours: Double) -> Window? {
        guard hours >= 0, hours < horizonHours else { return nil }
        return windows.first { hours >= $0.from && hours < $0.to }
    }

    /// Candidates for one reaction, ranked. Empty for a `dislike`, which is a
    /// taste signal and not a reaction at all.
    static func candidates(
        for reaction: ReactionLog,
        meals: [LoggedMeal],
        calendar: Calendar = MealRules.calendar
    ) -> [Candidate] {
        guard reaction.countsForAttribution else { return [] }
        return candidates(observedAt: reaction.observedAt, meals: meals, calendar: calendar)
    }

    static func candidates(
        observedAt: Date,
        meals: [LoggedMeal],
        calendar: Calendar = MealRules.calendar
    ) -> [Candidate] {
        var scores: [String: Double] = [:]
        var contributions: [String: [Contribution]] = [:]

        for meal in meals {
            // A refused meal was not eaten, so it cannot have caused anything.
            guard meal.portion != .refused, !meal.foodIDs.isEmpty else { continue }

            let eatenAt = mealTime(for: meal, calendar: calendar)
            let hours = observedAt.timeIntervalSince(eatenAt) / 3600
            guard let window = window(hoursBefore: hours) else { continue }

            // The meal's weight is split across its foods, so a suspect eaten
            // alone outscores the same food buried in a mixed bowl. Three foods
            // in one meal each carry a third of the suspicion, which is what
            // "we don't know which" actually means.
            let foods = Array(Set(meal.foodIDs))
            let share = window.weight / Double(foods.count)

            for id in foods {
                scores[id, default: 0] += share
                contributions[id, default: []].append(
                    Contribution(
                        mealDate: eatenAt, slot: meal.slot, dish: meal.dish,
                        hoursBefore: hours, weight: window.weight,
                        foodsInMeal: foods.count, mechanism: window.mechanism
                    )
                )
            }
        }

        return scores
            .map { id, score in
                Candidate(
                    foodID: id,
                    score: score,
                    contributions: (contributions[id] ?? []).sorted { $0.mealDate > $1.mealDate }
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.foodID < rhs.foodID
            }
    }

    /// When the meal was eaten.
    ///
    /// `LoggedMeal.date` is a day, not an instant — the journal stores meals by
    /// date and slot. Until a real `eatenAt` is captured, the slot's usual hour
    /// stands in, and the windows are wide enough (2 h at the narrowest) that an
    /// hour of slack does not move a meal between them for most of the range.
    /// This is an approximation, and the only one in this file.
    static func mealTime(for meal: LoggedMeal, calendar: Calendar = MealRules.calendar) -> Date {
        let hour = typicalHour(for: meal.slot)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: meal.date) ?? meal.date
    }

    static func typicalHour(for slot: MealSlot) -> Int {
        switch slot {
        case .breakfast: 8
        case .lunch:     12
        case .snack:     16
        case .dinner:    18
        }
    }
}
