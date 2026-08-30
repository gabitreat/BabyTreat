import Foundation
import HealthKit

/// The real Health store.
///
/// Read-only, and deliberately narrow: it reads `activeEnergyBurned` and
/// nothing that could double-count against our own BMR.
final class HealthKitActiveEnergyProvider: ActiveEnergyProviding {

    private let store: HKHealthStore
    private let calendar: Calendar

    init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Everything read here.
    ///
    /// `basalEnergyBurned` is **absent on purpose** (C2). Apple's resting figure
    /// and our Mifflin-St Jeor figure are the same quantity computed two ways;
    /// reading both is the same double-count in a different place. The
    /// permission is never even requested.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let active = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(active)
        }
        // Display only, for the "what earned this" breakdown. Never arithmetic.
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    private var activeEnergyType: HKQuantityType {
        get throws {
            guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                throw ActiveEnergyError.healthDataUnavailable
            }
            return type
        }
    }

    /// Read-only. `toShare` is empty and stays empty.
    func requestAuthorisation() async throws {
        guard isHealthDataAvailable else { throw ActiveEnergyError.healthDataUnavailable }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            throw ActiveEnergyError.queryFailed(String(describing: error))
        }
    }

    // MARK: - Sources

    /// Who has written active energy lately, with how much they wrote.
    ///
    /// The count is for the user's eyes only. Choosing the default by sample
    /// count would pick the phone almost every time, and the phone is the worst
    /// of the available estimates.
    func availableSources(since: Date) async throws -> [EnergySource] {
        let type = try activeEnergyType
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: [])

        let sources: Set<HKSource> = try await withCheckedThrowingContinuation { continuation in
            let query = HKSourceQuery(sampleType: type, samplePredicate: predicate) { _, sources, error in
                if let error {
                    continuation.resume(throwing: ActiveEnergyError.queryFailed(String(describing: error)))
                } else {
                    continuation.resume(returning: sources ?? [])
                }
            }
            store.execute(query)
        }

        guard !sources.isEmpty else { return [] }

        var result: [EnergySource] = []
        for source in sources {
            let stats = try await statistics(for: source, since: since)
            result.append(EnergySource(
                bundleIdentifier: source.bundleIdentifier,
                displayName: source.name,
                isEnabled: false,
                sampleCount: stats.count,
                lastWrittenAt: stats.newest
            ))
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    private func statistics(for source: HKSource, since: Date) async throws -> (count: Int, newest: Date?) {
        let type = try activeEnergyType
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: since, end: nil, options: []),
            HKQuery.predicateForObjects(from: [source]),
        ])

        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: ActiveEnergyError.queryFailed(String(describing: error)))
                } else {
                    let samples = samples ?? []
                    continuation.resume(returning: (samples.count, samples.first?.endDate))
                }
            }
            store.execute(query)
        }
    }

    // MARK: - A day

    /// One day, from the given sources and no others.
    ///
    /// The deduplication is the predicate: untrusted sources are never fetched,
    /// so their copy of the same walk cannot be added in. `HKStatisticsQuery`
    /// would sum whatever matched, which is exactly the trap.
    func activeEnergy(on day: Date, from sources: Set<String>) async throws -> ActiveEnergyDay {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw ActiveEnergyError.queryFailed("could not step a day forward from \(start)")
        }
        guard !sources.isEmpty else { throw ActiveEnergyError.noSources }

        let type = try activeEnergyType
        let matching = try await hkSources(matching: sources)
        guard !matching.isEmpty else { throw ActiveEnergyError.noSources }

        let inDay = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        let fromTrusted = HKQuery.predicateForObjects(from: matching)

        let daySamples = try await quantitySamples(
            type: type,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [inDay, fromTrusted]))

        var perSource: [String: Double] = [:]
        var total: Double = 0
        for sample in daySamples {
            let kcal = sample.quantity.doubleValue(for: .kilocalorie())
            perSource[sample.sourceRevision.source.bundleIdentifier, default: 0] += kcal
            total += kcal
        }

        // Asked across all time, not just this day: a day with nothing in it
        // needs to know when the watch last spoke at all, or an un-synced day
        // is indistinguishable from a still one.
        let newest = try await newestSampleDate(type: type, sources: matching)

        return ActiveEnergyDay(
            day: start,
            rawKilocalories: total,
            perSource: perSource,
            lastSampleAt: newest,
            isPartialDay: calendar.isDateInToday(start),
            sampleCount: daySamples.count
        )
    }

    func hourlyActiveEnergy(on day: Date, from sources: Set<String>) async throws -> [HourBucket] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        guard !sources.isEmpty else { throw ActiveEnergyError.noSources }

        let type = try activeEnergyType
        let matching = try await hkSources(matching: sources)
        guard !matching.isEmpty else { throw ActiveEnergyError.noSources }

        let samples = try await quantitySamples(
            type: type,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate]),
                HKQuery.predicateForObjects(from: matching),
            ]))

        var buckets: [Date: Double] = [:]
        for sample in samples {
            let hour = calendar.dateInterval(of: .hour, for: sample.startDate)?.start ?? sample.startDate
            buckets[hour, default: 0] += sample.quantity.doubleValue(for: .kilocalorie())
        }
        return buckets.map { HourBucket(hour: $0.key, kilocalories: $0.value) }
            .sorted { $0.hour < $1.hour }
    }

    // MARK: - Plumbing

    private func hkSources(matching identifiers: Set<String>) async throws -> Set<HKSource> {
        let type = try activeEnergyType
        let all: Set<HKSource> = try await withCheckedThrowingContinuation { continuation in
            let query = HKSourceQuery(sampleType: type, samplePredicate: nil) { _, sources, error in
                if let error {
                    continuation.resume(throwing: ActiveEnergyError.queryFailed(String(describing: error)))
                } else {
                    continuation.resume(returning: sources ?? [])
                }
            }
            store.execute(query)
        }
        return all.filter { identifiers.contains($0.bundleIdentifier) }
    }

    private func quantitySamples(type: HKQuantityType, predicate: NSPredicate) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: ActiveEnergyError.queryFailed(String(describing: error)))
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func newestSampleDate(type: HKQuantityType, sources: Set<HKSource>) async throws -> Date? {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: HKQuery.predicateForObjects(from: sources),
                limit: 1, sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: ActiveEnergyError.queryFailed(String(describing: error)))
                } else {
                    continuation.resume(returning: samples?.first?.endDate)
                }
            }
            store.execute(query)
        }
    }
}
