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

    /// Last day of bleeding, when it is known. Optional because the end is not
    /// known on the day it starts — logging a start must never require guessing
    /// an end.
    var endDate: Date?

    var notes: String

    init(
        id: String = UUID().uuidString,
        startDate: Date,
        loggedAt: Date = .now,
        timeZoneID: String = TimeZone.current.identifier,
        isSpotting: Bool = false,
        endDate: Date? = nil,
        notes: String = ""
    ) {
        let day = Self.calendar.startOfDay(for: startDate)
        self.id = id
        self.startDate = day
        self.dayKey = Self.dayKey(day)
        self.loggedAt = loggedAt
        self.timeZoneID = timeZoneID
        self.isSpotting = isSpotting
        self.endDate = endDate.map { Self.calendar.startOfDay(for: $0) }
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

    /// How many days the bleeding lasted, when an end is recorded.
    ///
    /// Inclusive of both days: a Monday start with a Friday end is 5 days, which
    /// is how a person counts it, not 4.
    var periodLengthDays: Int? {
        guard let endDate else { return nil }
        guard endDate >= startDate else { return nil }
        let days = Self.calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1
    }

    // MARK: - Migration

    /// Converts the older `CycleEvent` rows into period starts, one per day.
    ///
    /// The old screen wrote a fresh row on every tap, so the same day could be
    /// logged several times over. Those collapse to a single entry here, keeping
    /// the earliest, and its stored period length becomes an end date.
    ///
    /// The `CycleEvent` rows are left in place — unused, but not thrown away,
    /// because deleting somebody's log to tidy up is not a call worth making
    /// automatically.
    @MainActor
    @discardableResult
    static func migrateFromCycleEvents(in context: ModelContext) -> Int {
        let existing = Set(((try? context.fetch(FetchDescriptor<PeriodStart>())) ?? []).map(\.dayKey))
        let old = ((try? context.fetch(FetchDescriptor<CycleEvent>())) ?? [])
            .sorted { $0.startDate < $1.startDate }

        var seen = existing
        var made = 0
        for event in old {
            let key = dayKey(event.startDate)
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            // periodLengthDays counts both ends, so a 5-day period ends on
            // start + 4.
            let end = event.periodLengthDays > 0
                ? calendar.date(byAdding: .day, value: event.periodLengthDays - 1, to: calendar.startOfDay(for: event.startDate))
                : nil

            context.insert(PeriodStart(startDate: event.startDate, endDate: end, notes: event.note))
            made += 1
        }

        guard made > 0 else { return 0 }
        try? context.save()
        return made
    }

    /// Whether this entry counts toward cycle-length maths.
    var countsForCycleLength: Bool { !isSpotting }
}
