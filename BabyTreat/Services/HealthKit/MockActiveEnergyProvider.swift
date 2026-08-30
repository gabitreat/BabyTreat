import Foundation

/// A stand-in Health store.
///
/// Exists so the awkward cases can be produced on demand — a watch that has not
/// synced, two apps reporting the same walk, samples for the day before last
/// landing this morning. Waiting for a real watch to do those things is not a
/// test strategy.
final class MockActiveEnergyProvider: ActiveEnergyProviding {

    struct Sample: Equatable {
        var sourceID: String
        var kilocalories: Double
        var at: Date

        init(sourceID: String, kilocalories: Double, at: Date) {
            self.sourceID = sourceID
            self.kilocalories = kilocalories
            self.at = at
        }
    }

    var sources: [EnergySource]
    var samples: [Sample]
    /// The clock, so "nine hours ago" is a fact in a test rather than a wait.
    var now: Date
    var calendar: Calendar

    var isHealthDataAvailable: Bool = true
    var authorisationError: ActiveEnergyError?
    var queryError: ActiveEnergyError?

    private(set) var authorisationRequests = 0
    private(set) var dayQueries: [Date] = []

    init(
        sources: [EnergySource] = [],
        samples: [Sample] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.sources = sources
        self.samples = samples
        self.now = now
        self.calendar = calendar
    }

    func requestAuthorisation() async throws {
        authorisationRequests += 1
        if let authorisationError { throw authorisationError }
    }

    func availableSources(since: Date) async throws -> [EnergySource] {
        if let queryError { throw queryError }
        return sources.map { source in
            let mine = samples.filter { $0.sourceID == source.bundleIdentifier && $0.at >= since }
            var copy = source
            copy.sampleCount = mine.count
            copy.lastWrittenAt = mine.map(\.at).max()
            return copy
        }
    }

    func activeEnergy(on day: Date, from sources: Set<String>) async throws -> ActiveEnergyDay {
        if let queryError { throw queryError }
        let start = calendar.startOfDay(for: day)
        dayQueries.append(start)

        // Only enabled sources are read at all. This is the deduplication: the
        // iPhone's copy of the same walk is not summed and then divided, it is
        // never fetched.
        let mine = samples.filter { sources.contains($0.sourceID) }
        let today = mine.filter { calendar.isDate($0.at, inSameDayAs: start) }

        var perSource: [String: Double] = [:]
        for sample in today {
            perSource[sample.sourceID, default: 0] += sample.kilocalories
        }

        return ActiveEnergyDay(
            day: start,
            rawKilocalories: today.reduce(0) { $0 + $1.kilocalories },
            perSource: perSource,
            // The newest sample from a trusted source on **any** day. That is
            // what says when the watch last spoke, which is the question the
            // phantom-zero guard is asking.
            lastSampleAt: mine.map(\.at).max(),
            isPartialDay: calendar.isDate(start, inSameDayAs: now),
            sampleCount: today.count,
            now: now
        )
    }

    func hourlyActiveEnergy(on day: Date, from sources: Set<String>) async throws -> [HourBucket] {
        if let queryError { throw queryError }
        let start = calendar.startOfDay(for: day)
        let mine = samples.filter {
            sources.contains($0.sourceID) && calendar.isDate($0.at, inSameDayAs: start)
        }
        var buckets: [Date: Double] = [:]
        for sample in mine {
            let hour = calendar.dateInterval(of: .hour, for: sample.at)?.start ?? sample.at
            buckets[hour, default: 0] += sample.kilocalories
        }
        return buckets.map { HourBucket(hour: $0.key, kilocalories: $0.value) }
            .sorted { $0.hour < $1.hour }
    }
}
