import Foundation

/// An app or device that has written active energy into Health.
///
/// Several of them write the same walk. Apple Health does not merge them for
/// you when you query raw samples, so summing every source counts one morning
/// walk two or three times over.
struct EnergySource: Identifiable, Equatable, Hashable {
    var bundleIdentifier: String
    var displayName: String
    var isEnabled: Bool
    /// Shown in the picker so the user can see who has been writing.
    ///
    /// It is **not** how the default is chosen — see `ActiveEnergySourceSelector`.
    var sampleCount: Int
    var lastWrittenAt: Date?

    var id: String { bundleIdentifier }

    init(
        bundleIdentifier: String,
        displayName: String,
        isEnabled: Bool = false,
        sampleCount: Int = 0,
        lastWrittenAt: Date? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.sampleCount = sampleCount
        self.lastWrittenAt = lastWrittenAt
    }
}

/// Whether today's figure can be trusted yet.
///
/// The state exists because "no samples" and "no movement" look identical in a
/// sum, and Garmin only writes to Health when the Connect app runs. Treating an
/// un-synced day as a zero-activity day quietly removes a few hundred
/// kilocalories from the budget with nothing on screen to say so.
enum ActiveEnergySyncState: String, Codable, CaseIterable {
    /// Recent samples. Credit them.
    case fresh
    /// Nothing at all, and nothing recent either. Credit **nothing**, show the
    /// base target, and ask the user to open Garmin Connect.
    case awaitingSync
    /// Some data, but the newest sample is hours old and the day is not over.
    /// Credit what is there; it will probably grow.
    case stale
}

/// One day's active energy, as read from Health.
struct ActiveEnergyDay: Equatable {
    /// Local start of the day this covers.
    var day: Date
    /// Sum across **enabled sources only**, before any discount. Never
    /// overwritten with the credited figure — the raw number is what Health
    /// said, and it has to stay recoverable (C3).
    var rawKilocalories: Double
    /// Per source, for the breakdown sheet. Enabled sources only.
    var perSource: [String: Double]
    /// Newest sample seen, which may predate `day` when nothing has synced.
    var lastSampleAt: Date?
    /// True while the day is still running.
    var isPartialDay: Bool
    /// How many samples the enabled sources actually produced.
    ///
    /// Distinguishes "no samples" from "samples that happen to add to zero" —
    /// the difference between a phone that has not synced and a genuinely
    /// still day.
    var sampleCount: Int
    /// Set at construction by `classify`, never worked out in a view.
    var syncState: ActiveEnergySyncState

    /// How old the newest sample may be before a day with nothing in it is
    /// treated as un-synced rather than sedentary.
    static let staleAfter: TimeInterval = 6 * 60 * 60

    init(
        day: Date,
        rawKilocalories: Double,
        perSource: [String: Double] = [:],
        lastSampleAt: Date? = nil,
        isPartialDay: Bool = false,
        sampleCount: Int = 0,
        now: Date = .now
    ) {
        self.day = day
        self.rawKilocalories = rawKilocalories
        self.perSource = perSource
        self.lastSampleAt = lastSampleAt
        self.isPartialDay = isPartialDay
        self.sampleCount = sampleCount
        self.syncState = ActiveEnergyDay.classify(
            rawKilocalories: rawKilocalories,
            lastSampleAt: lastSampleAt,
            isPartialDay: isPartialDay,
            now: now
        )
    }

    /// The phantom-zero guard.
    ///
    /// Nothing burned *and* nothing written for six hours is a sync that has
    /// not happened, not a day on the sofa. A day with real samples in it stays
    /// `.fresh` even when they add up to zero, because the watch clearly spoke.
    static func classify(
        rawKilocalories: Double,
        lastSampleAt: Date?,
        isPartialDay: Bool,
        now: Date
    ) -> ActiveEnergySyncState {
        let age = lastSampleAt.map { now.timeIntervalSince($0) }
        let isOld = age.map { $0 > staleAfter } ?? true

        if rawKilocalories == 0 && isOld { return .awaitingSync }
        // A finished day is not waiting for anything more; only a day still in
        // progress can be behind.
        if isOld && isPartialDay { return .stale }
        return .fresh
    }

    /// What actually reaches the budget.
    ///
    /// `.awaitingSync` credits zero on purpose: the estimate shown alongside it
    /// is a reference figure for the user to read, never a number to spend.
    func credited(factor: Double) -> Double {
        guard syncState != .awaitingSync else { return 0 }
        return rawKilocalories * factor
    }
}

/// One hour of the day, for the shape of the breakdown sheet.
struct HourBucket: Equatable {
    var hour: Date
    var kilocalories: Double
}

/// Mirrors `OFFError`: the caller distinguishes "not allowed" from "went
/// wrong", because the first has a button and the second does not.
enum ActiveEnergyError: Error, Equatable {
    case notAuthorised
    case healthDataUnavailable
    case noSources
    case queryFailed(String)

    static func == (lhs: ActiveEnergyError, rhs: ActiveEnergyError) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
