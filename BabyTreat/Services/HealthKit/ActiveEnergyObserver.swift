import Foundation
import HealthKit

/// Watches Health for new active-energy samples.
///
/// Hourly and no faster. More frequent background wake-ups cost battery to
/// refresh a number that carries roughly 28% error — there is nothing to be
/// gained by chasing it (spec 2.5).
final class ActiveEnergyObserver {

    private let store: HKHealthStore
    private var query: HKObserverQuery?

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    /// Calls `onChange` when Health gains or loses active-energy samples.
    ///
    /// The handler is expected to recompute the whole three-day window, not
    /// just today — a fire usually means Garmin Connect has just synced, and
    /// what it brought may belong to yesterday or the day before.
    func start(onChange: @escaping @Sendable () -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else { return }

        stop()

        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
            onChange()
            // Health keeps waking the app until this is called, so it runs on
            // every path including the error one.
            completion()
        }
        self.query = query
        store.execute(query)

        store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
    }

    func stop() {
        if let query {
            store.stop(query)
            self.query = nil
        }
    }

    deinit { stop() }
}
