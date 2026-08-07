import Foundation

/// Turns recorded reactions into a decision about whether a food may be served.
///
/// Pure functions over `[LoggedMeal]` — no SwiftData, no SwiftUI.
enum ToleranceEngine {

    /// Where a food stands right now.
    ///
    /// Named `ToleranceStatus` rather than `FoodStatus` because that name is
    /// already taken by `Food.status` (accepted / weak / planned), which answers
    /// a different question: how well a food is *liked*, not whether it is safe.
    enum ToleranceStatus: Equatable {
        /// Servable. `disliked` is true when the only thing on record is a taste
        /// refusal — worth showing, never worth suppressing.
        case clear(disliked: Bool)
        case paused(until: Date, daysLeft: Int)
        /// The pause has run out. This is a question waiting to be answered.
        case retry
        /// Indefinite, pending a person's decision.
        case held
        case blocked

        var isServable: Bool {
            switch self {
            case .clear, .retry:           true
            case .paused, .held, .blocked: false
            }
        }
    }

    /// Clean exposures needed before a food stops being a suspect. Two rather
    /// than one: a single uneventful meal is weak evidence, and reactions to a
    /// second exposure are the classic pattern for a sensitising food.
    static let provenExposures = 2

    /// An unresolved question is worth more than an untried food, so a `.retry`
    /// food outranks everything else in a suggestion list.
    static let retryRankingBoost = 100

    // MARK: - Status

    static func status(
        for foodID: String,
        in meals: [LoggedMeal],
        asOf: Date = .now,
        calendar: Calendar = MealRules.calendar
    ) -> ToleranceStatus {
        let today = calendar.startOfDay(for: asOf)

        // Only flags this food is actually answerable for — see `attribution`.
        let relevant = meals
            .filter { $0.date <= today && $0.hasActiveFlag && $0.foodIDs.contains(foodID) }
            .filter { suppressedFoodIDs(for: $0, in: meals).contains(foodID) }
            .sorted { $0.date > $1.date }

        guard let latest = relevant.first, let level = latest.tolerance else {
            let disliked = meals.contains {
                $0.foodIDs.contains(foodID) && $0.tolerance == .dislike && !$0.isCleared
            }
            return .clear(disliked: disliked)
        }

        switch level {
        case .dislike:
            // Unreachable via `hasActiveFlag`, but stated rather than defaulted:
            // a taste refusal never suppresses. Removing the food is the exact
            // opposite of what fixes it — acceptance needs repeat exposure.
            return .clear(disliked: true)

        case .mild:
            guard let days = level.suppressDays, days > 0 else { return .retry }
            let until = MealRules.addDays(days, to: latest.date)
            let left = MealRules.daysBetween(today, until)
            return left > 0 ? .paused(until: until, daysLeft: left) : .retry

        case .moderate:
            return .held

        case .severe:
            return .blocked
        }
    }

    // MARK: - Attribution

    /// Which food a reaction can honestly be pinned on.
    enum Attribution: Equatable {
        /// Exactly one food in the meal was unproven. It gets the flag.
        case single(foodID: String)
        /// Several unproven foods. All are suppressed and must be retested apart.
        case ambiguous(foodIDs: [String])
        /// Every food in the meal is already proven. The flag is recorded and
        /// shown, but nothing is suppressed — there is no candidate to blame.
        case unattributed

        var foodIDs: [String] {
            switch self {
            case .single(let id):     [id]
            case .ambiguous(let ids): ids
            case .unattributed:       []
            }
        }
    }

    /// A reaction is attributable to one food only when exactly one food in the
    /// meal is still unproven. With two unproven foods on the plate, picking one
    /// is a guess, and a wrong guess both clears a real trigger and removes an
    /// innocent food.
    static func attribution(for meal: LoggedMeal, in meals: [LoggedMeal]) -> Attribution {
        let unproven = meal.foodIDs.filter {
            cleanExposures(of: $0, before: meal.date, in: meals) < provenExposures
        }
        switch unproven.count {
        case 0:  return .unattributed
        case 1:  return .single(foodID: unproven[0])
        default: return .ambiguous(foodIDs: unproven)
        }
    }

    static func suppressedFoodIDs(for meal: LoggedMeal, in meals: [LoggedMeal]) -> [String] {
        attribution(for: meal, in: meals).foodIDs
    }

    /// Meals before `date` where this food was eaten and nothing was recorded
    /// against it. A cleared flag does not count: clearing says a caregiver
    /// decided to move on, not that the food proved itself.
    static func cleanExposures(of foodID: String, before date: Date, in meals: [LoggedMeal]) -> Int {
        meals.filter { $0.date < date && $0.foodIDs.contains(foodID) && $0.isCleanExposure }.count
    }

    // MARK: - Rollups

    struct FoodFlag: Identifiable {
        let foodID: String
        let status: ToleranceStatus
        let level: ToleranceLevel
        let recordedOn: Date
        let note: String
        /// True when the flag was shared with other foods and none could be
        /// singled out.
        let isShared: Bool
        var id: String { foodID }

        var needsPediatrician: Bool { level.needsPediatrician }
    }

    /// Every food currently carrying an uncleared flag, worst first.
    static func flags(in meals: [LoggedMeal], asOf: Date = .now) -> [FoodFlag] {
        var out: [String: FoodFlag] = [:]

        for meal in meals.sorted(by: { $0.date < $1.date }) where meal.hasActiveFlag {
            guard let level = meal.tolerance else { continue }
            let suppressed = suppressedFoodIDs(for: meal, in: meals)
            for id in suppressed {
                let status = status(for: id, in: meals, asOf: asOf)
                if case .clear = status { continue }
                out[id] = FoodFlag(
                    foodID: id,
                    status: status,
                    level: level,
                    recordedOn: meal.date,
                    note: meal.dish,
                    isShared: suppressed.count > 1
                )
            }
        }

        return out.values.sorted { lhs, rhs in
            if lhs.severityRank != rhs.severityRank { return lhs.severityRank > rhs.severityRank }
            return lhs.recordedOn > rhs.recordedOn
        }
    }

    /// Foods that may not be served right now.
    static func suppressed(in meals: [LoggedMeal], asOf: Date = .now) -> Set<String> {
        Set(flags(in: meals, asOf: asOf).filter { !$0.status.isServable }.map(\.foodID))
    }

    /// Foods whose pause has expired — the ones worth trying next.
    static func awaitingRetry(in meals: [LoggedMeal], asOf: Date = .now) -> Set<String> {
        Set(flags(in: meals, asOf: asOf).filter { $0.status == .retry }.map(\.foodID))
    }
}

private extension ToleranceEngine.FoodFlag {
    var severityRank: Int {
        switch status {
        case .blocked:  4
        case .held:     3
        case .paused:   2
        case .retry:    1
        case .clear:    0
        }
    }
}
