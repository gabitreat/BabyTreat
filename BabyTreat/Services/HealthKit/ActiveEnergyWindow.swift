import Foundation

/// A day's active energy after the credit factor has been applied.
struct ActiveEnergyReading: Equatable {
    var day: ActiveEnergyDay
    /// Kept beside the raw figure, never folded into it (C3).
    var creditFactor: Double
    /// What the budget may spend. Zero while `.awaitingSync`.
    var creditedKilocalories: Double
    /// The same-weekday median, shown greyed as a reference when nothing has
    /// synced. **Never** added to the target — it is there so the user can see
    /// roughly what is missing, not so they can eat it.
    var referenceEstimate: Double?

    var isAwaitingSync: Bool { day.syncState == .awaitingSync }
}

/// Recomputes the last three days whenever Health says something changed.
///
/// Three days rather than today, because Garmin Connect writes to Health in
/// batches when it next syncs the watch — so samples for yesterday and the day
/// before can land hours or days late. Recomputing only today leaves those days
/// permanently under-credited, and nothing on screen ever says so.
enum ActiveEnergyWindow {

    /// How many days back a late-arriving sample is still picked up.
    static let days = 3

    /// The default fraction of the wearable's figure that reaches the budget.
    ///
    /// Not pessimism: energy expenditure is the least accurate thing a consumer
    /// wearable produces — around 28% mean error against laboratory measurement,
    /// versus about 4% for heart rate — and roughly half of a day's active
    /// calories come from the weaker step-derived estimator rather than the
    /// heart-rate one. Crediting three-quarters errs toward the budget being a
    /// little small rather than a lot too big.
    static let defaultCreditFactor: Double = 0.75
    static let creditFactorRange: ClosedRange<Double> = 0.50...1.00

    static func clampFactor(_ factor: Double) -> Double {
        min(max(factor, creditFactorRange.lowerBound), creditFactorRange.upperBound)
    }

    /// Today and the two days before it, newest first.
    ///
    /// Idempotent: the same store queried twice gives the same answer, so the
    /// observer can fire as often as it likes.
    static func recompute(
        endingOn day: Date,
        provider: ActiveEnergyProviding,
        sources: Set<String>,
        creditFactor: Double,
        calendar: Calendar = .current
    ) async throws -> [ActiveEnergyReading] {
        let factor = clampFactor(creditFactor)
        let end = calendar.startOfDay(for: day)

        var readings: [ActiveEnergyReading] = []
        for offset in 0..<days {
            // Calendar arithmetic, never 86_400 seconds. A clock-change day is
            // 23 or 25 hours long, and seconds-based stepping lands mid-day.
            guard let target = calendar.date(byAdding: .day, value: -offset, to: end) else { continue }
            readings.append(try await reading(
                on: target, provider: provider, sources: sources,
                creditFactor: factor, calendar: calendar))
        }
        return readings
    }

    static func reading(
        on day: Date,
        provider: ActiveEnergyProviding,
        sources: Set<String>,
        creditFactor: Double,
        calendar: Calendar = .current
    ) async throws -> ActiveEnergyReading {
        let factor = clampFactor(creditFactor)
        let energy = try await provider.activeEnergy(on: day, from: sources)

        // The estimate is only fetched when it will be shown, so an ordinary
        // day costs one query rather than five.
        let estimate: Double?
        if energy.syncState == .awaitingSync {
            estimate = try await sameWeekdayMedian(
                before: day, provider: provider, sources: sources, calendar: calendar)
        } else {
            estimate = nil
        }

        return ActiveEnergyReading(
            day: energy,
            creditFactor: factor,
            creditedKilocalories: energy.credited(factor: factor),
            referenceEstimate: estimate
        )
    }

    /// The median of the same weekday over the last four weeks.
    ///
    /// A median rather than a mean so one long hike four weeks ago does not set
    /// the expectation for every Sunday since. Days that never synced are left
    /// out — averaging in a gap would drag the reference toward zero, which is
    /// the error this whole state exists to avoid.
    static func sameWeekdayMedian(
        before day: Date,
        weeks: Int = 4,
        provider: ActiveEnergyProviding,
        sources: Set<String>,
        calendar: Calendar = .current
    ) async throws -> Double? {
        let end = calendar.startOfDay(for: day)
        var values: [Double] = []

        for week in 1...max(1, weeks) {
            guard let past = calendar.date(byAdding: .day, value: -7 * week, to: end) else { continue }
            let energy = try await provider.activeEnergy(on: past, from: sources)
            guard energy.sampleCount > 0 else { continue }
            values.append(energy.rawKilocalories)
        }

        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
