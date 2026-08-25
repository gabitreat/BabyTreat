import Foundation

/// Storage and reheating rules for a cooked batch.
///
/// Pure functions over a `SoupBatch` — no writes, no clock of its own. Every
/// entry point takes `now` so the whole thing is testable and so a rule can
/// never quietly depend on when it happened to be called.
///
/// The reasoning behind the numbers is in `NitrateRisk` and D-20. In short:
/// general batch-cooking advice allows two fridge days, but infant vegetable
/// purée is a special case, and a second day in the fridge is exactly the
/// condition that produced harm in the published case series.
enum BatchSafety {

    /// Portion and chill within this long of the cook finishing.
    static let coolingWindowMinutes: Double = 90
    /// A refrigerated portion is dead after this.
    static let fridgeLimitHours: Double = 24
    /// Rice drops the fridge limit to the same 24 h and must never be reheated twice.
    static let riceFridgeLimitHours: Double = 24

    // MARK: - Cooling

    static func coolingDeadline(for batch: SoupBatch) -> Date {
        batch.cookedAt.addingTimeInterval(coolingWindowMinutes * 60)
    }

    /// True once the cooling window has passed. The reminder fires on this.
    static func coolingOverdue(for batch: SoupBatch, now: Date = .now) -> Bool {
        now >= coolingDeadline(for: batch)
    }

    static let coolingMessage =
        "Portion it and get it in the fridge or freezer now — it's been over an hour and a half since it came off the heat."

    // MARK: - Expiry

    /// Why a portion can no longer be served.
    enum Expiry: Equatable {
        case fine
        /// Left in the fridge past the limit.
        case fridgeExpired(hoursOld: Int)
        /// The user threw the batch out.
        case discarded

        var isServable: Bool { self == .fine }

        var reason: String? {
            switch self {
            case .fine:
                nil
            case .fridgeExpired(let hours):
                "Cooked \(hours) h ago and kept in the fridge. Past 24 h a refrigerated portion goes in the bin, not on a spoon."
            case .discarded:
                "You marked this batch as thrown out."
            }
        }
    }

    /// Whether a given day's portion may still be served.
    ///
    /// Frozen portions do not age out here — freezing halts the nitrate
    /// conversion this rule exists for. Fresh (day one) is eaten the day it is
    /// cooked and is governed by the cooling reminder, not by this.
    static func expiry(for batch: SoupBatch, on day: Date, now: Date = .now) -> Expiry {
        if batch.isDiscarded { return .discarded }
        guard batch.storage(on: day) == .refrigerated else { return .fine }

        let hours = now.timeIntervalSince(batch.cookedAt) / 3600
        guard hours > fridgeLimitHours else { return .fine }
        return .fridgeExpired(hoursOld: Int(hours.rounded()))
    }

    // MARK: - Second fridge day

    static let secondFridgeDayWarning =
        "A second day in the fridge is the one thing to avoid here. Cooked vegetables turn nitrate into nitrite as they sit, " +
        "and infants have been harmed by day-old refrigerated veg purée. Freezing stops that — the fridge doesn't. " +
        "Freeze it unless you're serving it within 24 hours."

    /// True when choosing the fridge for this day needs the warning shown.
    static func needsSecondDayWarning(for batch: SoupBatch, on day: Date) -> Bool {
        guard let index = batch.coveredDays.firstIndex(where: {
            SoupBatch.dayKey($0) == SoupBatch.dayKey(day)
        }) else { return false }
        return index > 0
    }

    // MARK: - Reheating

    static let reheatRule =
        "Reheat until steaming hot all the way through, then let it cool before serving. Once only — whatever isn't eaten goes in the bin."

    static func reheatRule(containsRice: Bool) -> String {
        guard containsRice else { return reheatRule }
        return reheatRule + " There's rice in this one: fridge for 24 h at most, and never reheat rice twice."
    }

    /// Longest a batch may be kept in the fridge, given what's in it.
    static func fridgeLimit(containsRice: Bool) -> Double {
        containsRice ? riceFridgeLimitHours : fridgeLimitHours
    }

    // MARK: - Span

    /// The most days this batch may span, given its recipe.
    ///
    /// A high-nitrate ingredient locks it to one day. Explained inline rather
    /// than silently clamped, so the reason reaches the person cooking.
    static func maxSpanDays(risk: NitrateRisk) -> Int { risk.maxBatchSpanDays }

    static func spanLockReason(risk: NitrateRisk) -> String? {
        guard risk == .high else { return nil }
        return "This one's a single day. High-nitrate vegetables — spinach, beetroot, chard — shouldn't be kept and served again."
    }
}
