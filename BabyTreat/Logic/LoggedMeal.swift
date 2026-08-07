import Foundation

/// A meal that was both **planned and logged**, flattened into one value.
///
/// The two engines need what was served (`MenuEntry.foodIDs`) and how it went
/// (`MealLog`), which live in separate models joined on date + slot. Doing that
/// join once, here, keeps both engines free of SwiftData and testable from a
/// plain array of these.
struct LoggedMeal: Identifiable {
    let date: Date
    let slot: MealSlot
    let dish: String
    let foodIDs: [String]
    let portion: MealPortion
    let tolerance: ToleranceLevel?
    let isCleared: Bool
    let excludeFromTaste: Bool

    var id: String { "\(date.timeIntervalSince1970):\(slot.rawValue)" }

    /// Uncleared, and something more than a taste refusal.
    var hasActiveFlag: Bool {
        guard let tolerance else { return false }
        return !isCleared && tolerance != .dislike
    }

    /// Eaten, with nothing recorded against it. This is what "proven" is built
    /// from — see `ToleranceEngine.cleanExposures`.
    var isCleanExposure: Bool {
        portion.countsAsExposure && tolerance == nil
    }

    static func join(menu: [MenuEntry], logs: [MealLog], calendar: Calendar = MealRules.calendar) -> [LoggedMeal] {
        var byKey: [String: MenuEntry] = [:]
        for entry in menu {
            byKey["\(calendar.startOfDay(for: entry.date).timeIntervalSince1970):\(entry.slotRaw)"] = entry
        }

        return logs.compactMap { log in
            let day = calendar.startOfDay(for: log.date)
            guard let entry = byKey["\(day.timeIntervalSince1970):\(log.slotRaw)"] else { return nil }
            return LoggedMeal(
                date: day,
                slot: log.slot,
                dish: entry.dish,
                foodIDs: entry.foodIDs,
                portion: log.portion,
                tolerance: log.tolerance,
                isCleared: log.isCleared,
                excludeFromTaste: log.isExcludedFromTaste
            )
        }
        .sorted { $0.date < $1.date }
    }
}

extension MealPortion {
    /// How much of the bowl went in, 0…1. Used as the taste signal by
    /// `PairEffectEngine` — it is the only number in the journal that means
    /// "how well did this go".
    var score: Double {
        switch self {
        case .all:     1.00
        case .most:    0.85
        case .half:    0.60
        case .few:     0.25
        case .refused: 0.00
        }
    }

    /// Below half is where "it didn't go well" starts, and where asking about a
    /// reaction stops being noise. Above it, the question would appear after
    /// almost every meal and be ignored within a week.
    var triggersTolerance: Bool { self == .few || self == .refused }
}
