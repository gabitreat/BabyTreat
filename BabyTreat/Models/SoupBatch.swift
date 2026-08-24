import Foundation
import SwiftData

/// How a covered day's portion is being kept.
enum StorageMethod: String, Codable, CaseIterable, Identifiable {
    case fresh, refrigerated, frozen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fresh:        "Fresh"
        case .refrigerated: "Fridge"
        case .frozen:       "Frozen"
        }
    }
}

/// One cook, covering one or two consecutive days.
///
/// CRITICAL — two dinners from one batch are **two independent exposures**, not
/// one. `MealLog.batchID` records which cook a portion came from so attribution
/// can see that Monday and Tuesday were the same food, but a Tuesday reaction is
/// scored against Tuesday's `eatenAt` and never back to `cookedAt`. Nothing here
/// derives a meal time from a cook time.
@Model
final class SoupBatch {
    @Attribute(.unique) var id: String
    var recipeID: String
    /// When cooking finished, to the minute. The cooling reminder counts from here.
    var cookedAt: Date
    /// 1 or 2. Clamped on write — a high-nitrate batch is locked to 1 by
    /// `NitrateRisk.maxBatchSpanDays`, enforced at the call site.
    var spanDays: Int
    /// First day the batch covers, at start of day.
    var startDate: Date
    /// Per covered day, keyed `yyyy-MM-dd`.
    ///
    /// Keyed by **day, not `Date`**, deliberately. A `[Date: StorageMethod]` map
    /// would key on an exact instant, so a lookup built from a slightly different
    /// time of day would silently miss and read as "no portion stored".
    var storageByDayRaw: [String: String]
    var timeZoneID: String
    /// Set when the user throws the batch out. Voids unlogged planned meals;
    /// never touches meals already logged.
    var discardedAt: Date?
    var notes: String

    init(
        id: String = UUID().uuidString,
        recipeID: String,
        cookedAt: Date,
        spanDays: Int,
        startDate: Date,
        storage: [Date: StorageMethod] = [:],
        timeZoneID: String = TimeZone.current.identifier,
        discardedAt: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.recipeID = recipeID
        self.cookedAt = MealLog.roundedToMinute(cookedAt)
        self.spanDays = min(max(spanDays, 1), 2)
        self.startDate = MealRules.startOfDay(startDate)
        self.storageByDayRaw = [:]
        self.timeZoneID = timeZoneID
        self.discardedAt = discardedAt
        self.notes = notes
        for (day, method) in storage { setStorage(method, on: day) }
    }

    // MARK: - Covered days

    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = MealRules.calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayKeyFormatter.string(from: date) }

    /// The days this batch is meant to cover, in order.
    var coveredDays: [Date] {
        (0..<spanDays).map { MealRules.addDays($0, to: startDate) }
    }

    func covers(_ day: Date) -> Bool {
        coveredDays.contains { Self.dayKey($0) == Self.dayKey(day) }
    }

    // MARK: - Storage

    func storage(on day: Date) -> StorageMethod? {
        storageByDayRaw[Self.dayKey(day)].flatMap(StorageMethod.init(rawValue:))
    }

    func setStorage(_ method: StorageMethod, on day: Date) {
        storageByDayRaw[Self.dayKey(day)] = method.rawValue
    }

    /// Day 1 is eaten off the stove; day 2 defaults to frozen.
    ///
    /// CRITICAL — the day-2 default is `.frozen`, not `.refrigerated`. A second
    /// day in the fridge is the exact condition in the infant purée case series,
    /// so choosing it has to be a deliberate override with the warning shown,
    /// never something the app picks on the user's behalf. See `NitrateRisk`.
    static func defaultStorage(forDayIndex index: Int) -> StorageMethod {
        index == 0 ? .fresh : .frozen
    }

    /// Fills in any covered day that has no storage set yet. Never overwrites a
    /// choice the user already made.
    func applyDefaultStorage() {
        for (index, day) in coveredDays.enumerated() where storage(on: day) == nil {
            setStorage(Self.defaultStorage(forDayIndex: index), on: day)
        }
    }

    var isDiscarded: Bool { discardedAt != nil }
}
