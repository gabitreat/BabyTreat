import Foundation
import SwiftData

/// How much was actually eaten. The distinction that matters is `refused` versus
/// everything else: a refused meal does **not** count as an allergen exposure.
enum MealPortion: String, Codable, CaseIterable, Identifiable {
    case all       = "tot"
    case most      = "majoritatea"
    case half      = "jumatate"
    case few       = "putin"
    case refused   = "refuzat"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:     "All of it"
        case .most:    "Almost all"
        case .half:    "Half"
        case .few:     "A few spoons"
        case .refused: "Refused"
        }
    }

    /// Any amount actually eaten counts as an exposure. Only a refusal doesn't.
    var countsAsExposure: Bool { self != .refused }
}

/// The weekday routine the prototype was missing: "tried X today, reaction Y".
/// Allergen re-exposure counts read from here, never from the plan — see D-3.
@Model
final class MealLog {
    var date: Date
    var slotRaw: String
    var portionRaw: String
    /// Measured intake. Optional because not every meal gets weighed — the
    /// qualitative portion is always there, grams are recorded when known.
    var grams: Int?
    var note: String
    /// `.now` at insert. **Audit only** — never edited, never shown as the meal
    /// time. When the meal happened is `eatenAt`; this is when it got typed in,
    /// which on a bad evening can be three hours later.
    var loggedAt: Date

    /// When the food was actually eaten, to the minute. User-editable.
    ///
    /// Optional so journals written before it existed migrate untouched; read
    /// through `servedAt`, which falls back to the slot's usual hour. That
    /// fallback is the only approximation in the attribution maths, and this
    /// field is how it gets removed one meal at a time.
    var eatenAt: Date?
    /// Captured at save. A meal eaten at 10:30 abroad is still that meal when
    /// the phone comes home.
    var timeZoneID: String?
    /// Which cook this portion came from, when it came from a batch.
    ///
    /// A back-reference for the planner and for reading a week's history — it is
    /// NOT an attribution shortcut. Two dinners off one batch are two separate
    /// exposures, each scored from its own `eatenAt`.
    var batchID: String?

    /// How the meal was tolerated. Recorded only when something went wrong, and
    /// optional even then — most meals have no reason to carry one.
    ///
    /// These four are optional in the store so journals written before the field
    /// existed migrate without a version bump; read them through the computed
    /// accessors below.
    var toleranceRaw: String?
    var toleranceNote: String?
    /// Illness, teething, a meal pushed two hours late. Reasons a small portion
    /// says nothing about the food — so it is kept out of the taste maths.
    var excludeFromTaste: Bool?
    /// Set when a caregiver decides a flag no longer applies. A cleared flag
    /// stops suppressing the food but stays in the record.
    var clearedAt: Date?

    init(
        date: Date,
        slot: MealSlot,
        portion: MealPortion,
        grams: Int? = nil,
        note: String = "",
        tolerance: ToleranceLevel? = nil,
        toleranceNote: String = "",
        excludeFromTaste: Bool = false,
        eatenAt: Date? = nil,
        loggedAt: Date = .now,
        calendar: Calendar = .current
    ) {
        self.date = calendar.startOfDay(for: date)
        self.slotRaw = slot.rawValue
        self.portionRaw = portion.rawValue
        self.grams = grams
        self.note = note
        self.toleranceRaw = tolerance?.rawValue
        self.toleranceNote = toleranceNote
        self.excludeFromTaste = excludeFromTaste
        self.eatenAt = eatenAt.map(MealLog.roundedToMinute)
        self.timeZoneID = TimeZone.current.identifier
        self.loggedAt = loggedAt
    }

    /// Seconds are noise, and storing one implies a precision nobody has about
    /// when a bowl was finished.
    static func roundedToMinute(_ date: Date) -> Date {
        let seconds = Calendar.current.component(.second, from: date)
        return Calendar.current.date(byAdding: .second, value: -seconds, to: date) ?? date
    }

    /// "120 g · Almost all", or just the portion when nothing was weighed.
    var summary: String {
        guard let grams else { return portion.label }
        return "\(grams) g · \(portion.label)"
    }

    var slot: MealSlot {
        get { MealSlot(rawValue: slotRaw) ?? .lunch }
        set { slotRaw = newValue.rawValue }
    }

    var portion: MealPortion {
        get { MealPortion(rawValue: portionRaw) ?? .half }
        set { portionRaw = newValue.rawValue }
    }

    var tolerance: ToleranceLevel? {
        get { toleranceRaw.flatMap(ToleranceLevel.init(rawValue:)) }
        set { toleranceRaw = newValue?.rawValue }
    }

    var isCleared: Bool { clearedAt != nil }
    var isExcludedFromTaste: Bool { excludeFromTaste ?? false }

    /// A flag that is still doing something — uncleared, and not just a dislike.
    var hasActiveFlag: Bool {
        guard let tolerance else { return false }
        return !isCleared && tolerance != .dislike
    }
}
