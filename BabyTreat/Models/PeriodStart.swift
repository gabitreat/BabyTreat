import Foundation
import SwiftData

/// One logged period start day.
///
/// CRITICAL — the app stores a **list of these** and derives everything from the
/// gaps between them. There is deliberately no `cycleLength` field and no "last
/// period" field: a stored cycle length goes stale silently, and removing that
/// staleness is the whole point of the feature.
///
/// Kept flat and relationship-free so it ports to Supabase as a plain row.
@Model
final class PeriodStart {

    /// Stable identity for sync. Not the uniqueness rule — that is `dayKey`.
    var id: String

    /// Day precision, normalised to start of day.
    var startDate: Date

    /// `yyyy-MM-dd` for the start date.
    ///
    /// Unique, which is what enforces **one entry per calendar day** in the
    /// store itself rather than leaving it to whichever screen happens to be
    /// writing. Kept as a string because a `Date` key would compare by instant,
    /// and two taps on the same day would land on different instants.
    @Attribute(.unique) var dayKey: String

    /// `.now` at insert. Audit only — never shown as the period date.
    var loggedAt: Date

    /// Same convention as `MealLog`: what zone the person was in when they logged.
    var timeZoneID: String

    /// Spotting is logged but **excluded from cycle-length maths** — counting it
    /// as a start would invent short cycles that never happened.
    var isSpotting: Bool

    var notes: String

    init(
        id: String = UUID().uuidString,
        startDate: Date,
        loggedAt: Date = .now,
        timeZoneID: String = TimeZone.current.identifier,
        isSpotting: Bool = false,
        notes: String = ""
    ) {
        let day = Self.calendar.startOfDay(for: startDate)
        self.id = id
        self.startDate = day
        self.dayKey = Self.dayKey(day)
        self.loggedAt = loggedAt
        self.timeZoneID = timeZoneID
        self.isSpotting = isSpotting
        self.notes = notes
    }

    // MARK: - Day keys

    /// The user's own calendar, so the week start and locale follow the device
    /// rather than being pinned here.
    static var calendar: Calendar { .current }

    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String {
        dayKeyFormatter.string(from: calendar.startOfDay(for: date))
    }

    /// Keeps `startDate` and `dayKey` from drifting apart when the date is edited.
    func move(to date: Date) {
        let day = Self.calendar.startOfDay(for: date)
        startDate = day
        dayKey = Self.dayKey(day)
    }

    /// Whether this entry counts toward cycle-length maths.
    var countsForCycleLength: Bool { !isSpotting }
}
