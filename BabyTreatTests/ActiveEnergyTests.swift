import XCTest
@testable import BabyTreat

/// Part 7 tests 4, 9, 10, 11 and 12, plus the multiplier lock the whole design
/// rests on. Everything here runs against `MockActiveEnergyProvider` — the
/// awkward cases are all "the watch has not synced", and waiting for a real one
/// to do that is not a test.
final class ActiveEnergyTests: XCTestCase {

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private let garmin = EnergySource(bundleIdentifier: "com.garmin.connect.mobile", displayName: "Garmin Connect")
    private let phone  = EnergySource(bundleIdentifier: "com.apple.health.ABC123", displayName: "Andreea's iPhone")
    private let watch  = EnergySource(bundleIdentifier: "com.apple.health.DEF456", displayName: "Andreea's Apple Watch")

    // MARK: - Test 4 · dedup

    /// Garmin and the iPhone both report the same 400 kcal walk. Only Garmin is
    /// trusted, so the day is 400 and the credit is 300 — not 600, and not 450.
    func testOnlyEnabledSourcesAreCounted() async throws {
        let now = date(2026, 8, 30, 18)
        let provider = MockActiveEnergyProvider(
            sources: [garmin, phone],
            samples: [
                .init(sourceID: garmin.bundleIdentifier, kilocalories: 400, at: date(2026, 8, 30, 9)),
                .init(sourceID: phone.bundleIdentifier, kilocalories: 400, at: date(2026, 8, 30, 9)),
            ],
            now: now, calendar: calendar)

        let selection = ActiveEnergySourceSelector.defaultSelection(from: [garmin, phone])
        let reading = try await ActiveEnergyWindow.reading(
            on: now, provider: provider, sources: selection,
            creditFactor: 0.75, calendar: calendar)

        XCTAssertEqual(reading.day.rawKilocalories, 400, accuracy: 0.001)
        XCTAssertEqual(reading.creditedKilocalories, 300, accuracy: 0.001)
    }

    /// With a wearable selected, the phone and the watch are off — not ranked
    /// lower, off. Both would report the same morning walk.
    func testPhoneAndWatchAreDisabledWhenGarminIsPresent() {
        let sources = ActiveEnergySourceSelector.applyingDefaults(to: [phone, watch, garmin])
        let byID = Dictionary(uniqueKeysWithValues: sources.map { ($0.bundleIdentifier, $0) })

        XCTAssertTrue(byID[garmin.bundleIdentifier]!.isEnabled)
        XCTAssertFalse(byID[phone.bundleIdentifier]!.isEnabled)
        XCTAssertFalse(byID[watch.bundleIdentifier]!.isEnabled)
    }

    // MARK: - Test 9 · defaulting is by quality, not by volume

    /// Garmin wrote 40 samples, the iPhone wrote 900. Garmin still wins.
    ///
    /// The phone logs constantly and estimates badly — its active energy comes
    /// from step cadence, so it misses cycling, weights and carrying a child.
    /// Sample density is not accuracy.
    func testGarminBeatsTheiPhoneOnFewerSamples() {
        var garminFew = garmin; garminFew.sampleCount = 40
        var phoneMany = phone;  phoneMany.sampleCount = 900

        XCTAssertEqual(
            ActiveEnergySourceSelector.defaultSelection(from: [phoneMany, garminFew]),
            [garmin.bundleIdentifier])
    }

    func testAppleWatchIsPreferredOverThePhone() {
        XCTAssertEqual(
            ActiveEnergySourceSelector.defaultSelection(from: [phone, watch]),
            [watch.bundleIdentifier])
    }

    func testThePhoneIsUsedOnlyWhenNothingElseWrote() {
        XCTAssertEqual(
            ActiveEnergySourceSelector.defaultSelection(from: [phone]),
            [phone.bundleIdentifier])
    }

    func testNothingIsEnabledWhenNoSourceIsRecognised() {
        let odd = EnergySource(bundleIdentifier: "com.example.tracker", displayName: "Some app")
        XCTAssertTrue(ActiveEnergySourceSelector.defaultSelection(from: [odd]).isEmpty)
    }

    /// Garmin ships more than one app and renames its bundles between releases.
    /// A single hardcoded identifier that stops matching would credit zero for
    /// ever without erroring, so the match is a substring of either field.
    func testGarminIsMatchedByNameOrIdentifier() {
        let byName = EnergySource(bundleIdentifier: "com.example.unknown", displayName: "Garmin Connect")
        let byBundle = EnergySource(bundleIdentifier: "com.garmin.connect.NEW", displayName: "Connect")
        let shouty = EnergySource(bundleIdentifier: "com.GARMIN.beta", displayName: "Beta")

        XCTAssertTrue(ActiveEnergySourceSelector.isWearable(byName))
        XCTAssertTrue(ActiveEnergySourceSelector.isWearable(byBundle))
        XCTAssertTrue(ActiveEnergySourceSelector.isWearable(shouty))
    }

    // MARK: - Test 10 · the phantom zero

    /// Nothing written today and the last sample is nine hours old. That is
    /// Garmin Connect not having run, not a day without moving.
    ///
    /// Crediting the zero would take ~300–450 kcal off the day's food with
    /// nothing on screen to explain it.
    func testUnsyncedDayIsNotTreatedAsZeroActivity() async throws {
        let now = date(2026, 8, 30, 6)                     // early morning
        let lastNight = date(2026, 8, 29, 21)              // nine hours before

        let provider = MockActiveEnergyProvider(
            sources: [garmin],
            samples: [.init(sourceID: garmin.bundleIdentifier, kilocalories: 500, at: lastNight)],
            now: now, calendar: calendar)

        let reading = try await ActiveEnergyWindow.reading(
            on: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)

        XCTAssertEqual(reading.day.syncState, .awaitingSync)
        XCTAssertEqual(reading.day.rawKilocalories, 0, accuracy: 0.001)
        XCTAssertEqual(reading.creditedKilocalories, 0, accuracy: 0.001,
                       "an un-synced day must credit nothing, not an estimate")
    }

    /// The reference figure is shown so the user can see roughly what is
    /// missing. It must never reach the number they can spend.
    func testTheMedianEstimateIsShownButNeverCredited() async throws {
        let now = date(2026, 8, 30, 6)                     // a Sunday
        var samples: [MockActiveEnergyProvider.Sample] = [
            .init(sourceID: garmin.bundleIdentifier, kilocalories: 500, at: date(2026, 8, 29, 21)),
        ]
        // The four Sundays before, so there is a median to take.
        for (week, kcal) in [(1, 400.0), (2, 600.0), (3, 500.0), (4, 900.0)] {
            let day = calendar.date(byAdding: .day, value: -7 * week, to: now)!
            samples.append(.init(sourceID: garmin.bundleIdentifier, kilocalories: kcal, at: day))
        }

        let provider = MockActiveEnergyProvider(
            sources: [garmin], samples: samples, now: now, calendar: calendar)

        let reading = try await ActiveEnergyWindow.reading(
            on: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)

        XCTAssertEqual(reading.referenceEstimate, 550)     // median of 400/500/600/900
        XCTAssertEqual(reading.creditedKilocalories, 0, accuracy: 0.001)
    }

    /// A median, not a mean, so one long hike does not set the expectation for
    /// every Sunday after it.
    func testTheEstimateIsAMedianNotAMean() async throws {
        let now = date(2026, 8, 30, 6)
        var samples: [MockActiveEnergyProvider.Sample] = [
            .init(sourceID: garmin.bundleIdentifier, kilocalories: 300, at: date(2026, 8, 29, 21)),
        ]
        for (week, kcal) in [(1, 300.0), (2, 300.0), (3, 300.0), (4, 3000.0)] {
            let day = calendar.date(byAdding: .day, value: -7 * week, to: now)!
            samples.append(.init(sourceID: garmin.bundleIdentifier, kilocalories: kcal, at: day))
        }
        let provider = MockActiveEnergyProvider(
            sources: [garmin], samples: samples, now: now, calendar: calendar)

        let median = try await ActiveEnergyWindow.sameWeekdayMedian(
            before: now, provider: provider,
            sources: [garmin.bundleIdentifier], calendar: calendar)

        XCTAssertEqual(median!, 300, accuracy: 0.001)      // a mean would say 975
    }

    // MARK: - Test 11 · a genuine zero

    /// Samples exist, they add up to nothing, and the newest is twenty minutes
    /// old. The watch is talking; she just sat still. Credit it as a real zero
    /// and show no sync notice.
    func testAGenuineZeroActivityDayIsNotMistakenForAMissingSync() async throws {
        let now = date(2026, 8, 30, 18)
        let provider = MockActiveEnergyProvider(
            sources: [garmin],
            samples: [.init(sourceID: garmin.bundleIdentifier, kilocalories: 0, at: date(2026, 8, 30, 17, 40))],
            now: now, calendar: calendar)

        let reading = try await ActiveEnergyWindow.reading(
            on: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)

        XCTAssertEqual(reading.day.syncState, .fresh)
        XCTAssertFalse(reading.isAwaitingSync)
        XCTAssertNil(reading.referenceEstimate, "no sync notice, so no estimate to show")
    }

    // MARK: - Test 12 · backfill

    /// Garmin Connect syncs this morning and brings samples belonging to the
    /// day before last. A today-only recompute would leave that day short for
    /// ever; the three-day window picks it up.
    func testLateSamplesForTheDayBeforeLastArePickedUp() async throws {
        let now = date(2026, 8, 30, 10)
        let provider = MockActiveEnergyProvider(
            sources: [garmin], samples: [], now: now, calendar: calendar)

        func credited(_ readings: [ActiveEnergyReading], daysAgo: Int) -> Double {
            let target = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
            return readings.first { $0.day.day == target }?.creditedKilocalories ?? -1
        }

        let before = try await ActiveEnergyWindow.recompute(
            endingOn: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)
        XCTAssertEqual(credited(before, daysAgo: 2), 0, accuracy: 0.001)

        // The watch finally syncs, carrying Friday's walk.
        provider.samples = [
            .init(sourceID: garmin.bundleIdentifier, kilocalories: 480, at: date(2026, 8, 28, 11)),
        ]

        let after = try await ActiveEnergyWindow.recompute(
            endingOn: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)
        XCTAssertEqual(credited(after, daysAgo: 2), 360, accuracy: 0.001)   // 480 × 0.75
    }

    /// The observer can fire as often as Health likes. Running it again must
    /// not move a single number.
    func testRecomputeIsIdempotent() async throws {
        let now = date(2026, 8, 30, 10)
        let provider = MockActiveEnergyProvider(
            sources: [garmin],
            samples: [
                .init(sourceID: garmin.bundleIdentifier, kilocalories: 480, at: date(2026, 8, 28, 11)),
                .init(sourceID: garmin.bundleIdentifier, kilocalories: 120, at: date(2026, 8, 30, 8)),
            ],
            now: now, calendar: calendar)

        let first = try await ActiveEnergyWindow.recompute(
            endingOn: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)
        let second = try await ActiveEnergyWindow.recompute(
            endingOn: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)
        let third = try await ActiveEnergyWindow.recompute(
            endingOn: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertEqual(second, third)
    }

    func testTheWindowIsThreeDaysEndingToday() async throws {
        let now = date(2026, 8, 30, 10)
        let provider = MockActiveEnergyProvider(sources: [garmin], now: now, calendar: calendar)

        let readings = try await ActiveEnergyWindow.recompute(
            endingOn: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)

        XCTAssertEqual(readings.count, 3)
        XCTAssertEqual(readings.map(\.day.day), [
            calendar.startOfDay(for: date(2026, 8, 30)),
            calendar.startOfDay(for: date(2026, 8, 29)),
            calendar.startOfDay(for: date(2026, 8, 28)),
        ])
    }

    /// Clocks change. Stepping back by 86,400 seconds lands mid-day on a 23- or
    /// 25-hour day, so the window has to walk calendar days.
    func testTheWindowWalksCalendarDaysAcrossAClockChange() async throws {
        // Romania's clocks go back on 25 October 2026: that day is 25 hours.
        let now = date(2026, 10, 26, 10)
        let provider = MockActiveEnergyProvider(sources: [garmin], now: now, calendar: calendar)

        let readings = try await ActiveEnergyWindow.recompute(
            endingOn: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)

        XCTAssertEqual(readings.map(\.day.day), [
            calendar.startOfDay(for: date(2026, 10, 26)),
            calendar.startOfDay(for: date(2026, 10, 25)),
            calendar.startOfDay(for: date(2026, 10, 24)),
        ])
        for reading in readings {
            XCTAssertEqual(calendar.component(.hour, from: reading.day.day), 0)
        }
    }

    // MARK: - The credit factor

    /// The raw figure is what Health said. It has to stay recoverable, so the
    /// discount is kept beside it and never folded in (C3).
    func testRawAndCreditedAreBothKeptAndDifferByTheFactor() async throws {
        let now = date(2026, 8, 30, 18)
        let provider = MockActiveEnergyProvider(
            sources: [garmin],
            samples: [.init(sourceID: garmin.bundleIdentifier, kilocalories: 520, at: date(2026, 8, 30, 9))],
            now: now, calendar: calendar)

        let reading = try await ActiveEnergyWindow.reading(
            on: now, provider: provider, sources: [garmin.bundleIdentifier],
            creditFactor: 0.75, calendar: calendar)

        XCTAssertEqual(reading.day.rawKilocalories, 520, accuracy: 0.001)
        XCTAssertEqual(reading.creditFactor, 0.75, accuracy: 0.001)
        XCTAssertEqual(reading.creditedKilocalories, 390, accuracy: 0.001)
        XCTAssertEqual(reading.creditedKilocalories / reading.day.rawKilocalories, 0.75, accuracy: 0.0001)
    }

    /// Applied once. A second pass would quietly shrink the budget again.
    func testTheCreditFactorIsAppliedOnlyOnce() {
        let day = ActiveEnergyDay(
            day: date(2026, 8, 30), rawKilocalories: 400,
            lastSampleAt: date(2026, 8, 30, 17, 45), sampleCount: 3,
            now: date(2026, 8, 30, 18))
        XCTAssertEqual(day.credited(factor: 0.75), 300, accuracy: 0.001)
        XCTAssertEqual(day.rawKilocalories, 400, accuracy: 0.001, "raw was overwritten")
    }

    func testTheCreditFactorIsClampedToItsRange() {
        XCTAssertEqual(ActiveEnergyWindow.clampFactor(1.4), 1.0, accuracy: 0.001)
        XCTAssertEqual(ActiveEnergyWindow.clampFactor(0.1), 0.5, accuracy: 0.001)
        XCTAssertEqual(ActiveEnergyWindow.defaultCreditFactor, 0.75, accuracy: 0.001)
    }

    // MARK: - C1 · the lock that is worth 600 kcal a day

    /// Mifflin-St Jeor times 1.55 already contains the exercise. Adding a
    /// watch's active energy on top counts the same movement twice.
    ///
    /// The spec's worked example: 68 kg, 168 cm, 32, exclusively breastfeeding,
    /// 500 kcal of active energy. Guessed movement and measured movement both
    /// applied gives 3184; pinning the multiplier and crediting 75% of the
    /// measurement gives 2566. A 618 kcal gap, every day.
    ///
    /// The figures are 8–12 kcal below the ones printed in spec 4.1, because
    /// the spec's own BMR is 8 kcal out — Mifflin-St Jeor for these inputs is
    /// 1409, not 1417. Recorded as P-2. The arithmetic below is the correct
    /// one; nothing about the conclusion changes.
    func testHealthKitPinsTheMultiplierToSedentary() {
        let bmr = EnergyEngine.bmr(weightKg: 68, heightCm: 168, age: 32)

        let doubleCounted = bmr * 1.55 + 500 + 500
        let correct = bmr * EnergyEngine.ActivityLevel.sedentary.multiplier + (500 * 0.75) + 500

        XCTAssertEqual(bmr, 1409, accuracy: 0.5)
        XCTAssertEqual(doubleCounted, 3184, accuracy: 1)
        XCTAssertEqual(correct, 2566, accuracy: 1)
        XCTAssertEqual(doubleCounted - correct, 618, accuracy: 1)
        XCTAssertEqual(EnergyEngine.ActivityLevel.sedentary.multiplier, 1.2, accuracy: 0.0001)
    }

    /// The lock lives on the profile, so the budget cannot be handed a
    /// multiplier above 1.2 while a Health credit is also in play.
    @MainActor
    func testTheActivityPickerIsIgnoredWhileHealthIsOn() {
        let store = EnergyProfileStore()
        let restoreHealth = store.useHealthKitActiveEnergy
        let restoreActivity = store.activityRaw
        defer {
            store.useHealthKitActiveEnergy = restoreHealth
            store.activityRaw = restoreActivity
        }

        store.useHealthKitActiveEnergy = false
        store.activity = .moderate
        XCTAssertEqual(store.activity, .moderate)

        store.useHealthKitActiveEnergy = true
        XCTAssertEqual(store.activity, .sedentary, "the multiplier must pin to 1.2")

        store.activity = .veryActive                       // ignored, not stored
        XCTAssertEqual(store.activity, .sedentary)

        // Turning Health off gives back the choice that was there before.
        store.useHealthKitActiveEnergy = false
        XCTAssertEqual(store.activity, .moderate)
    }
}
