import XCTest
import SwiftData
@testable import BabyTreat

final class ReactionAttributionTests: XCTestCase {

    private let calendar = MealRules.calendar

    private func day(_ offset: Int) -> Date {
        MealRules.addDays(offset, to: MealRules.startOfDay(Date(timeIntervalSince1970: 1_785_000_000)))
    }

    private func meal(_ offset: Int, _ slot: MealSlot, _ foods: [String], _ portion: MealPortion = .all) -> LoggedMeal {
        LoggedMeal(date: day(offset), slot: slot, dish: foods.joined(separator: " + "),
                   foodIDs: foods, portion: portion, tolerance: nil,
                   isCleared: false, excludeFromTaste: false)
    }

    private func observed(_ offset: Int, hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day(offset)) ?? day(offset)
    }

    /// The whole point of the design: a reaction noticed in the evening must not
    /// automatically blame dinner.
    func testEveningReactionDoesNotAutomaticallyBlameTheLatestMeal() {
        let meals = [
            meal(0, .breakfast, ["oats"]),
            meal(0, .lunch, ["salmon"]),
        ]
        // 14:00 — lunch was 2 h ago, breakfast 6 h ago.
        let candidates = ReactionAttribution.candidates(observedAt: observed(0, hour: 14), meals: meals)

        XCTAssertEqual(candidates.count, 2, "both meals are candidates, not just the latest")
        XCTAssertEqual(candidates.first?.foodID, "salmon")
        XCTAssertEqual(try XCTUnwrap(candidates.first?.score), 0.80, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(candidates.last?.score), 0.50, accuracy: 0.001)
    }

    /// A suspect eaten alone must outscore the same food in a mixed bowl.
    func testWeightIsSplitAcrossFoodsInAMeal() {
        let solo = [meal(0, .lunch, ["egg"])]
        let mixed = [meal(0, .lunch, ["egg", "broccoli", "potato"])]
        let at = observed(0, hour: 13)   // 1 h after lunch, weight 1.00

        let soloScore = try? XCTUnwrap(ReactionAttribution.candidates(observedAt: at, meals: solo).first?.score)
        let mixedScore = try? XCTUnwrap(ReactionAttribution.candidates(observedAt: at, meals: mixed).first?.score)

        XCTAssertEqual(soloScore ?? 0, 1.00, accuracy: 0.001)
        XCTAssertEqual(mixedScore ?? 0, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertGreaterThan(soloScore ?? 0, mixedScore ?? 0)
    }

    func testWindowBoundariesMatchTheTable() {
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 0)?.weight, 1.00)
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 1.9)?.weight, 1.00)
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 2)?.weight, 0.80)
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 3.9)?.weight, 0.80)
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 4)?.weight, 0.50)
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 9.9)?.weight, 0.50)
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 10)?.weight, 0.25)
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 24)?.weight, 0.10)
        XCTAssertEqual(ReactionAttribution.window(hoursBefore: 47.9)?.weight, 0.10)
        XCTAssertNil(ReactionAttribution.window(hoursBefore: 48), "beyond the horizon is discarded")
        XCTAssertNil(ReactionAttribution.window(hoursBefore: -1), "a meal after the reaction is not a candidate")
    }

    func testRefusedMealsScoreNothing() {
        let meals = [meal(0, .lunch, ["lentils"], .refused)]
        XCTAssertTrue(ReactionAttribution.candidates(observedAt: observed(0, hour: 13), meals: meals).isEmpty)
    }

    func testMealsBeyond48HoursAreDiscarded() {
        let meals = [meal(-3, .lunch, ["beef"]), meal(0, .lunch, ["chicken"])]
        let candidates = ReactionAttribution.candidates(observedAt: observed(0, hour: 13), meals: meals)
        XCTAssertEqual(candidates.map(\.foodID), ["chicken"])
    }

    /// A dislike is a taste signal, not a reaction.
    func testDislikeProducesNoCandidates() {
        let reaction = ReactionLog(observedAt: observed(0, hour: 13), severity: .dislike)
        let meals = [meal(0, .lunch, ["mango"])]
        XCTAssertTrue(ReactionAttribution.candidates(for: reaction, meals: meals).isEmpty)
    }

    func testEveryCandidateCarriesItsMechanism() {
        let meals = [meal(0, .lunch, ["egg"])]
        let candidate = ReactionAttribution.candidates(observedAt: observed(0, hour: 15), meals: meals).first
        XCTAssertEqual(candidate?.leadingMechanism, "Acute FPIES — repetitive vomiting 1–4 h")
    }

    func testReactionLogRoundsToTheMinute() {
        let messy = Date(timeIntervalSince1970: 1_785_000_037)
        let log = ReactionLog(observedAt: messy, severity: .mild)
        XCTAssertEqual(Calendar.current.component(.second, from: log.observedAt), 0)
    }

    // MARK: - Ingredient roles

    func testOnlyBaseConsumesARotationSlot() {
        XCTAssertTrue(IngredientRole.base.consumesRotationSlot)
        XCTAssertFalse(IngredientRole.accent.consumesRotationSlot)
        XCTAssertFalse(IngredientRole.additive.consumesRotationSlot)
    }

    /// Coconut must not be a tree nut, and carob must not gate on peanut.
    func testTaxonomyDoesNotGateAllergens() {
        let coconut = MealSeed.accents().first { $0.id == "coconutcan" }
        XCTAssertEqual(coconut?.family, .arecaceae)
        XCTAssertNotEqual(coconut?.family, .treeNut)
        XCTAssertEqual(coconut?.isAllergen, false, "family is taxonomy; it must never set the gating flag")

        let carob = MealSeed.accents().first { $0.id == "roscove" }
        XCTAssertEqual(carob?.family, .legume)
        XCTAssertEqual(carob?.isAllergen, false)
    }

    func testCoconutIsBlockedAsADrinkUnderTwelveMonths() {
        let coconut = try? XCTUnwrap(MealSeed.accents().first { $0.id == "coconutbox" })
        XCTAssertNotNil(coconut?.drinkBlockReason(atAgeMonths: 8))
        XCTAssertNil(coconut?.drinkBlockReason(atAgeMonths: 12))
        // …while cooking use is fine from 6 months.
        XCTAssertTrue(coconut?.isAgeAppropriate(atAgeMonths: 7) ?? false)
        XCTAssertFalse(coconut?.isAgeAppropriate(atAgeMonths: 5) ?? true)
    }

    func testCoconutIsSplitIntoTwoEntries() {
        let ids = MealSeed.accents().map(\.id)
        XCTAssertTrue(ids.contains("coconutcan"))
        XCTAssertTrue(ids.contains("coconutbox"))
    }

    // MARK: - Recorded eaten time

    /// A recorded time is used as-is; without one the slot's usual hour stands in.
    func testRecordedEatenTimeBeatsTheSlotFallback() {
        let calendar = MealRules.calendar
        var meal = self.meal(0, .lunch, ["egg"])
        XCTAssertFalse(ReactionAttribution.hasRecordedTime(meal))
        XCTAssertEqual(calendar.component(.hour, from: ReactionAttribution.mealTime(for: meal)), 12)

        meal.eatenAt = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: day(0))
        XCTAssertTrue(ReactionAttribution.hasRecordedTime(meal))
        XCTAssertEqual(calendar.component(.hour, from: ReactionAttribution.mealTime(for: meal)), 15)
    }

    /// The real time can move a meal into a different onset window — which is
    /// the entire reason for capturing it.
    func testRecordedTimeChangesTheWindow() {
        let calendar = MealRules.calendar
        var meal = self.meal(0, .lunch, ["egg"])
        let at = observed(0, hour: 14)

        // Assumed 12:00 → 2 h → acute FPIES band, 0.80.
        let assumed = ReactionAttribution.candidates(observedAt: at, meals: [meal]).first
        XCTAssertEqual(try XCTUnwrap(assumed?.score), 0.80, accuracy: 0.001)

        // Actually eaten at 13:00 → 1 h → IgE band, 1.00.
        meal.eatenAt = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: day(0))
        let recorded = ReactionAttribution.candidates(observedAt: at, meals: [meal]).first
        XCTAssertEqual(try XCTUnwrap(recorded?.score), 1.00, accuracy: 0.001)
    }

    func testMealLogRoundsEatenAtToTheMinute() {
        let messy = Date(timeIntervalSince1970: 1_785_000_041)
        let log = MealLog(date: messy, slot: .lunch, portion: .all, eatenAt: messy)
        XCTAssertEqual(Calendar.current.component(.second, from: try XCTUnwrap(log.eatenAt)), 0)
        XCTAssertEqual(log.timeZoneID, TimeZone.current.identifier)
    }

    // MARK: - Slot gating

    func testSlotsUnlockAtTheStatedAges() {
        XCTAssertEqual(MealRules.activeSlots(atAgeMonths: 6), [.breakfast, .lunch])
        XCTAssertTrue(MealRules.activeSlots(atAgeMonths: 8).contains(.dinner))
        XCTAssertFalse(MealRules.activeSlots(atAgeMonths: 8).contains(.snack))
        XCTAssertTrue(MealRules.activeSlots(atAgeMonths: 12).contains(.snack))

        XCTAssertEqual(MealRules.lockedSlots(atAgeMonths: 6), [.dinner, .snack])
        XCTAssertTrue(MealRules.lockedSlots(atAgeMonths: 12).isEmpty)
    }

    /// A slot is what the user said it is — never derived from the clock.
    func testSlotIsNeverInferredFromTime() {
        // A 10:30 lunch abroad stays lunch.
        let calendar = MealRules.calendar
        let earlyLunch = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: day(0))
        let log = MealLog(date: day(0), slot: .lunch, portion: .all, eatenAt: earlyLunch)
        XCTAssertEqual(log.slot, .lunch)
    }

    func testExistingFoodsDefaultToBaseRole() {
        let broccoli = MealSeed.foods().first { $0.id == "broccoli" }
        XCTAssertEqual(broccoli?.role, .base)
    }

    // MARK: - Roles govern rotation

    /// The rule the role enum exists for, enforced where it counts.
    func testAccentsAndAdditivesNeverEnterRotation() {
        let foods = MealSeed.foods()
        // Nothing has been served, so every base food is "absent".
        let flags = MealRules.rotationCheck(refDate: day(0), foods: foods, menu: [])
        let flagged = Set(flags.map(\.food.id))

        XCTAssertFalse(flagged.contains("uleimasline"), "olive oil must not need rotating back in")
        XCTAssertFalse(flagged.contains("scortisoara"), "cinnamon is a flavour, not an exposure")
        XCTAssertFalse(flagged.contains("e410"), "an additive nobody chose cannot drop out of rotation")
        XCTAssertTrue(flagged.contains("broccoli"), "base foods still rotate")
    }

    // MARK: - Family drives diversity, never gating

    func testFamilyCountsMealsNotFoods() {
        let foods = MealSeed.foods()
        let byID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let monday = MealRules.mondayOf(day(0))

        // One meal with two legumes is one legume meal, not two.
        let menu = [
            MenuEntry(date: monday, slot: .lunch, dish: "Lentils + chickpeas",
                      foodIDs: ["linte", "naut"], calendar: MealRules.calendar)
        ]
        let load = MealRules.familyLoad(weekStart: monday, menu: menu, foodsByID: byID,
                                        activeSlots: [.breakfast, .lunch])
        XCTAssertEqual(load.first { $0.family == .legume }?.meals, 1)
    }

    func testThreeLegumeMealsAreFlaggedAsCrowded() {
        let foods = MealSeed.foods()
        let byID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let monday = MealRules.mondayOf(day(0))

        let menu = (0..<3).map { offset in
            MenuEntry(date: MealRules.addDays(offset, to: monday), slot: .lunch,
                      dish: "Lentils", foodIDs: ["linte"], calendar: MealRules.calendar)
        }
        let load = MealRules.familyLoad(weekStart: monday, menu: menu, foodsByID: byID,
                                        activeSlots: [.breakfast, .lunch])
        XCTAssertEqual(load.first { $0.family == .legume }?.isCrowded, true)
    }

    /// Carob is a legume for diversity, and that must not reach the peanut flag.
    func testCarobCrowdsDiversityWithoutGatingPeanut() {
        let foods = MealSeed.foods()
        let carob = foods.first { $0.id == "roscove" }
        XCTAssertEqual(carob?.family, .legume)
        XCTAssertEqual(carob?.isAllergen, false)

        // …and being an accent, it does not even reach the diversity count.
        let byID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let monday = MealRules.mondayOf(day(0))
        let menu = (0..<3).map { offset in
            MenuEntry(date: MealRules.addDays(offset, to: monday), slot: .breakfast,
                      dish: "Oats + carob", foodIDs: ["ovaz", "roscove"], calendar: MealRules.calendar)
        }
        let load = MealRules.familyLoad(weekStart: monday, menu: menu, foodsByID: byID,
                                        activeSlots: [.breakfast, .lunch])
        XCTAssertNil(load.first { $0.family == .legume }, "an accent is invisible to diversity scoring")
    }

    /// A store seeded before classification existed has every `familyRaw` nil,
    /// which would silently switch diversity scoring off on an upgraded install.
    @MainActor
    func testBackfillRestoresClassificationOnAPreExistingStore() throws {
        let container = try ModelContainer(
            for: Food.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        // Stand in for a row written by an older build: right id, no classification.
        let stale = Food(id: "linte", name: "Lentils", category: "Protein",
                         colorHex: "#A8763E", status: .weak, groups: [.proteina])
        stale.familyRaw = nil
        stale.roleRaw = nil
        context.insert(stale)
        try context.save()

        XCTAssertEqual(stale.family, .none, "precondition: the old row has no family")

        let touched = MealSeed.backfillClassification(in: context)
        XCTAssertGreaterThan(touched, 0)
        XCTAssertEqual(stale.family, .legume)
        XCTAssertEqual(stale.role, .base)
    }

    /// A row written by an intermediate build stores the default `.none`
    /// rather than nil, and must still pick up its tag.
    @MainActor
    func testBackfillUpgradesTheStoredDefault() throws {
        let container = try ModelContainer(
            for: Food.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        // The initialiser writes ".none"/".base" — never nil.
        let food = Food(id: "linte", name: "Lentils", category: "Protein",
                        colorHex: "#A8763E", status: .weak, groups: [.proteina])
        context.insert(food)
        try context.save()
        XCTAssertEqual(food.familyRaw, AllergenFamily.none.rawValue,
                       "precondition: the default is stored, not nil")

        MealSeed.backfillClassification(in: context)
        XCTAssertEqual(food.family, .legume)
    }

    /// Foods the seed does not know about are left untouched.
    @MainActor
    func testBackfillIgnoresUnseededFoods() throws {
        let container = try ModelContainer(
            for: Food.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let custom = Food(id: "user-added-thing", name: "Kefir", category: "Protein",
                          colorHex: "#FFFFFF", status: .planned, family: .dairy)
        context.insert(custom)
        try context.save()

        XCTAssertEqual(MealSeed.backfillClassification(in: context), 0)
        XCTAssertEqual(custom.family, .dairy)
    }
}
