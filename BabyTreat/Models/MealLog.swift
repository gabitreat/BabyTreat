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
    var loggedAt: Date

    init(
        date: Date,
        slot: MealSlot,
        portion: MealPortion,
        grams: Int? = nil,
        note: String = "",
        loggedAt: Date = .now,
        calendar: Calendar = .current
    ) {
        self.date = calendar.startOfDay(for: date)
        self.slotRaw = slot.rawValue
        self.portionRaw = portion.rawValue
        self.grams = grams
        self.note = note
        self.loggedAt = loggedAt
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
}
