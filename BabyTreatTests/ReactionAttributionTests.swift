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

    // MARK: - Soup batches (month-8 dinner rule, Parts 1–2)

    /// The rule the whole nitrate axis exists for.
    func testHighNitrateIngredientLocksTheBatchToOneDay() {
        XCTAssertEqual(NitrateRisk.high.maxBatchSpanDays, 1)
        XCTAssertEqual(NitrateRisk.moderate.maxBatchSpanDays, 2)
        XCTAssertEqual(NitrateRisk.low.maxBatchSpanDays, 2)
    }

    func testSeedTagsTheNitrateRisksTheSpecNames() {
        let byID = Dictionary(MealSeed.foods().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(byID["spanac"]?.nitrateRisk, .high)
        XCTAssertEqual(byID["sfecla"]?.nitrateRisk, .high)
        XCTAssertEqual(byID["morcov"]?.nitrateRisk, .moderate)
        XCTAssertEqual(byID["dovlecel"]?.nitrateRisk, .moderate)
        XCTAssertEqual(byID["cartof"]?.nitrateRisk, .low, "potato is low even though it is filed under vegetables")
    }

    /// An untagged vegetable must not read as safe.
    func testUntaggedVegetableDefaultsToModerateAndMeatToLow() {
        let veg = Food(id: "x-veg", name: "Fennel", category: "Vegetables",
                       colorHex: "#FFFFFF", status: .planned, kind: .veg)
        let meat = Food(id: "x-meat", name: "Lamb", category: "Protein",
                        colorHex: "#FFFFFF", status: .planned, kind: .proteina)
        XCTAssertEqual(veg.nitrateRisk, .moderate)
        XCTAssertEqual(meat.nitrateRisk, .low)
    }

    /// A recipe takes the risk of its riskiest base ingredient, and accents are
    /// invisible to it — olive oil must not decide how long a soup keeps.
    func testRecipeRiskIsTheMaxOfItsBaseIngredients() {
        let byID = Dictionary(MealSeed.foods().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let recipes = Dictionary(MealSeed.recipes().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        XCTAssertEqual(recipes["s1"]?.nitrateRisk(foodsByID: byID), .moderate, "carrot carries it")
        XCTAssertEqual(recipes["s1"]?.form, .soup)

        // Same soup with spinach in it is locked to a single day.
        let spinachSoup = Recipe(id: "x", title: "Spinach soup", minAgeMonths: 8,
                                 foodIDs: ["spanac", "cartof", "uleimasline"],
                                 ingredients: [], steps: [], form: .soup)
        XCTAssertEqual(spinachSoup.nitrateRisk(foodsByID: byID), .high)
        XCTAssertEqual(spinachSoup.nitrateRisk(foodsByID: byID).maxBatchSpanDays, 1)
    }

    func testUnknownIngredientIsNotTreatedAsSafe() {
        let recipe = Recipe(id: "x", title: "Mystery", minAgeMonths: 8,
                            foodIDs: ["not-in-the-pantry"], ingredients: [], steps: [], form: .soup)
        XCTAssertEqual(recipe.nitrateRisk(foodsByID: [:]), .moderate)
    }

    /// CRITICAL — day two defaults to the freezer, never the fridge.
    func testDayTwoDefaultsToFrozen() {
        XCTAssertEqual(SoupBatch.defaultStorage(forDayIndex: 0), .fresh)
        XCTAssertEqual(SoupBatch.defaultStorage(forDayIndex: 1), .frozen)

        let batch = SoupBatch(recipeID: "s1", cookedAt: day(0), spanDays: 2, startDate: day(0))
        batch.applyDefaultStorage()
        XCTAssertEqual(batch.storage(on: day(0)), .fresh)
        XCTAssertEqual(batch.storage(on: day(1)), .frozen)
    }

    func testDefaultStorageNeverOverwritesAnOverride() {
        let batch = SoupBatch(recipeID: "s1", cookedAt: day(0), spanDays: 2, startDate: day(0))
        batch.setStorage(.refrigerated, on: day(1))
        batch.applyDefaultStorage()
        XCTAssertEqual(batch.storage(on: day(1)), .refrigerated,
                       "an explicit override survives — it is the user's call, with the warning shown")
    }

    /// Storage is keyed by day, so any time on that day finds the portion.
    func testStorageLookupIsByDayNotByInstant() {
        let batch = SoupBatch(recipeID: "s1", cookedAt: day(0), spanDays: 2, startDate: day(0))
        batch.applyDefaultStorage()
        let laterThatDay = day(1).addingTimeInterval(17 * 3600 + 43 * 60)
        XCTAssertEqual(batch.storage(on: laterThatDay), .frozen)
        XCTAssertTrue(batch.covers(laterThatDay))
    }

    func testSpanIsClampedAndCoversTheRightDays() {
        XCTAssertEqual(SoupBatch(recipeID: "s1", cookedAt: day(0), spanDays: 5, startDate: day(0)).spanDays, 2)
        XCTAssertEqual(SoupBatch(recipeID: "s1", cookedAt: day(0), spanDays: 0, startDate: day(0)).spanDays, 1)

        let batch = SoupBatch(recipeID: "s1", cookedAt: day(0), spanDays: 2, startDate: day(0))
        XCTAssertEqual(batch.coveredDays.count, 2)
        XCTAssertTrue(batch.covers(day(1)))
        XCTAssertFalse(batch.covers(day(2)))
    }

    /// The cook time is not a meal time. Nothing may derive one from the other.
    func testBatchDoesNotCarryAMealTime() {
        let cooked = day(0).addingTimeInterval(11 * 3600 + 30 * 60 + 42)
        let batch = SoupBatch(recipeID: "s1", cookedAt: cooked, spanDays: 2, startDate: day(0))
        XCTAssertEqual(batch.cookedAt, MealLog.roundedToMinute(cooked), "minute precision")

        // Two dinners off one batch are two exposures, each with its own eatenAt.
        let monday = MealLog(date: day(0), slot: .dinner, portion: .all)
        let tuesday = MealLog(date: day(1), slot: .dinner, portion: .all)
        monday.batchID = batch.id
        tuesday.batchID = batch.id
        monday.eatenAt = day(0).addingTimeInterval(18 * 3600)
        tuesday.eatenAt = day(1).addingTimeInterval(18 * 3600)

        XCTAssertEqual(monday.batchID, tuesday.batchID)
        XCTAssertNotEqual(monday.eatenAt, tuesday.eatenAt)
        XCTAssertNotEqual(tuesday.eatenAt, batch.cookedAt)
    }

    func testSeedShipsThreeSoupsForTheDinnerFilter() {
        let soups = MealSeed.recipes().filter { $0.form == .soup }
        XCTAssertEqual(soups.count, 3)
        XCTAssertEqual(soups.filter { $0.minAgeMonths <= 8 }.count, 3)
        // No dairy before the 8-month gate.
        let byID = Dictionary(MealSeed.foods().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for soup in soups {
            XCTAssertFalse(soup.foodIDs.contains { byID[$0]?.family == .dairy }, "\(soup.title) has dairy in it")
        }
    }

    /// Untagged recipes stay unknown — the filter must not mistake one for a soup.
    func testExistingRecipesAreNotSilentlyCalledSoups() {
        let byID = Dictionary(MealSeed.recipes().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        XCTAssertNil(byID["r2"]?.form)
        XCTAssertNil(byID["r5"]?.form)
    }

    // MARK: - Dinner rule (month 8)

    func testMonthEightDinnerSuggestsSoupsOnly() {
        let recipes = MealSeed.recipes()
        let suggested = DinnerRule.suggestions(from: recipes, slot: .dinner, ageMonths: 8)
        XCTAssertFalse(suggested.isEmpty)
        XCTAssertTrue(suggested.allSatisfy { $0.form == .soup })
    }

    func testTheRuleOnlyAppliesToDinnerAndOnlyAtMonthEight() {
        let recipes = MealSeed.recipes()
        // Lunch at 8 months is untouched.
        XCTAssertTrue(DinnerRule.suggestions(from: recipes, slot: .lunch, ageMonths: 8)
            .contains { $0.form != .soup })
        // Dinner at 9 months is untouched.
        XCTAssertTrue(DinnerRule.suggestions(from: recipes, slot: .dinner, ageMonths: 9)
            .contains { $0.form != .soup })
        // And at 7.
        XCTAssertNil(DinnerRule.allowedForms(slot: .dinner, ageMonths: 7))
        XCTAssertNotNil(DinnerRule.allowedForms(slot: .dinner, ageMonths: 8))
    }

    func testSuggestionsStillRespectAge() {
        let recipes = MealSeed.recipes()
        let suggested = DinnerRule.suggestions(from: recipes, slot: .dinner, ageMonths: 8)
        XCTAssertTrue(suggested.allSatisfy { $0.minAgeMonths <= 8 })
    }

    /// CRITICAL — a filter, never a block.
    func testOffPlanDinnerIsFlaggedButNeverRefused() {
        let porridge = MealSeed.recipes().first { $0.id == "r1" }!
        XCTAssertTrue(DinnerRule.isOffPlan(porridge, slot: .dinner, ageMonths: 8))
        // `isOffPlan` is the whole API — there is no "canLog" to say no.
        let soup = MealSeed.recipes().first { $0.id == "s1" }!
        XCTAssertFalse(DinnerRule.isOffPlan(soup, slot: .dinner, ageMonths: 8))
        XCTAssertFalse(DinnerRule.isOffPlan(porridge, slot: .dinner, ageMonths: 9))
    }

    func testTextureNudgeFiresOnAWeekOfNothingButPuree() {
        let soft = MealSeed.recipes().filter { $0.form == .soup }
        XCTAssertTrue(DinnerRule.needsTextureNudge(recipes: soft, ageMonths: 8))

        var withFinger = soft
        withFinger.append(Recipe(id: "f", title: "Toast fingers", minAgeMonths: 8,
                                 foodIDs: [], ingredients: [], steps: [], form: .fingerFood))
        XCTAssertFalse(DinnerRule.needsTextureNudge(recipes: withFinger, ageMonths: 8))
        XCTAssertFalse(DinnerRule.needsTextureNudge(recipes: soft, ageMonths: 7))
    }

    // MARK: - Batch safety

    func testCoolingReminderFiresNinetyMinutesAfterCooking() {
        let cooked = day(0).addingTimeInterval(12 * 3600)
        let batch = SoupBatch(recipeID: "s1", cookedAt: cooked, spanDays: 2, startDate: day(0))
        XCTAssertFalse(BatchSafety.coolingOverdue(for: batch, now: cooked.addingTimeInterval(60 * 60)))
        XCTAssertTrue(BatchSafety.coolingOverdue(for: batch, now: cooked.addingTimeInterval(91 * 60)))
    }

    func testRefrigeratedPortionExpiresAfterTwentyFourHours() {
        let cooked = day(0).addingTimeInterval(12 * 3600)
        let batch = SoupBatch(recipeID: "s1", cookedAt: cooked, spanDays: 2, startDate: day(0))
        batch.setStorage(.refrigerated, on: day(1))

        XCTAssertEqual(BatchSafety.expiry(for: batch, on: day(1), now: cooked.addingTimeInterval(20 * 3600)), .fine)
        let late = BatchSafety.expiry(for: batch, on: day(1), now: cooked.addingTimeInterval(26 * 3600))
        XCTAssertFalse(late.isServable)
        XCTAssertNotNil(late.reason)
    }

    /// Freezing halts the conversion, so a frozen portion does not age out here.
    func testFrozenPortionDoesNotExpire() {
        let cooked = day(0).addingTimeInterval(12 * 3600)
        let batch = SoupBatch(recipeID: "s1", cookedAt: cooked, spanDays: 2, startDate: day(0))
        batch.applyDefaultStorage()
        XCTAssertEqual(batch.storage(on: day(1)), .frozen)
        XCTAssertEqual(BatchSafety.expiry(for: batch, on: day(1), now: cooked.addingTimeInterval(72 * 3600)), .fine)
    }

    func testDiscardedBatchIsNeverServable() {
        let batch = SoupBatch(recipeID: "s1", cookedAt: day(0), spanDays: 2, startDate: day(0))
        batch.discardedAt = day(0)
        XCTAssertEqual(BatchSafety.expiry(for: batch, on: day(0)), .discarded)
    }

    func testOnlyTheSecondDayNeedsTheFridgeWarning() {
        let batch = SoupBatch(recipeID: "s1", cookedAt: day(0), spanDays: 2, startDate: day(0))
        XCTAssertFalse(BatchSafety.needsSecondDayWarning(for: batch, on: day(0)))
        XCTAssertTrue(BatchSafety.needsSecondDayWarning(for: batch, on: day(1)))
    }

    func testRiceChangesTheReheatAdvice() {
        XCTAssertTrue(BatchSafety.reheatRule(containsRice: true).localizedCaseInsensitiveContains("rice"))
        XCTAssertFalse(BatchSafety.reheatRule(containsRice: false).localizedCaseInsensitiveContains("rice"))
    }

    // MARK: - Batch planning

    @MainActor
    func testTwoDayBatchCountsAsTwoExposures() {
        let byID = Dictionary(MealSeed.foods().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let soup = MealSeed.recipes().first { $0.id == "s1" }!

        let plan = BatchPlanner.makePlan(recipe: soup, startDate: day(0), spanDays: 2,
                                         cookedAt: day(0), foodsByID: byID)
        XCTAssertEqual(plan.entries.count, 2, "one menu entry per day — that is what makes it two exposures")
        XCTAssertTrue(plan.entries.allSatisfy { $0.foodIDs.contains("morcov") })
        XCTAssertEqual(plan.entries.map { MealRules.startOfDay($0.date) },
                       [day(0), day(1)])
    }

    /// Accents ride along in the dish but must not fill a rotation slot.
    @MainActor
    func testBatchEntriesLeaveAccentsOutOfRotation() {
        let byID = Dictionary(MealSeed.foods().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let soup = MealSeed.recipes().first { $0.id == "s1" }!
        XCTAssertTrue(soup.foodIDs.contains("uleimasline"), "precondition: the recipe has olive oil in it")

        let plan = BatchPlanner.makePlan(recipe: soup, startDate: day(0), spanDays: 2,
                                         cookedAt: day(0), foodsByID: byID)
        XCTAssertFalse(plan.entries[0].foodIDs.contains("uleimasline"))
    }

    /// A high-nitrate soup cannot be stretched to two days by asking for two.
    @MainActor
    func testHighNitrateBatchIsClampedToOneDay() {
        var foods = MealSeed.foods()
        foods.append(Food(id: "spanac2", name: "Spinach", category: "Vegetables",
                          colorHex: "#3F6B34", status: .accepted, kind: .veg,
                          nitrateRisk: .high))
        let byID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let soup = Recipe(id: "sx", title: "Spinach soup", minAgeMonths: 8,
                          foodIDs: ["spanac2", "cartof"], ingredients: [], steps: [], form: .soup)

        let plan = BatchPlanner.makePlan(recipe: soup, startDate: day(0), spanDays: 2,
                                         cookedAt: day(0), foodsByID: byID)
        XCTAssertEqual(plan.batch.spanDays, 1)
        XCTAssertEqual(plan.entries.count, 1)
        XCTAssertNotNil(BatchSafety.spanLockReason(risk: .high))
    }

    @MainActor
    func testBatchEntriesCarryTheBatchID() {
        let byID = Dictionary(MealSeed.foods().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let soup = MealSeed.recipes().first { $0.id == "s1" }!
        let plan = BatchPlanner.makePlan(recipe: soup, startDate: day(0), spanDays: 2,
                                         cookedAt: day(0), foodsByID: byID)
        XCTAssertTrue(plan.entries.allSatisfy { $0.batchID == plan.batch.id })
    }

    // MARK: - Generated week honours the dinner rule

    /// Eight months old on the week being planned.
    private func eightMonthBirthDate(for weekStart: Date) -> Date {
        MealRules.calendar.date(byAdding: .month, value: -8, to: weekStart) ?? weekStart
    }

    func testGeneratedWeekPlansSoupsForDinnerAtMonthEight() {
        let weekStart = MealRules.mondayOf(day(0))
        let birth = eightMonthBirthDate(for: weekStart)
        let recipesByID = Dictionary(MealSeed.recipes().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        let plan = MealPlanner.plan(
            weekStart: weekStart, birthDate: birth,
            foods: MealSeed.foods(), recipes: MealSeed.recipes(),
            menu: [], logs: []
        )

        let dinners = plan.meals.filter { $0.slot == .dinner }
        XCTAssertEqual(dinners.count, 7, "every evening gets a dinner")
        for dinner in dinners {
            let recipe = dinner.recipeID.flatMap { recipesByID[$0] }
            XCTAssertEqual(recipe?.form, .soup, "\(dinner.dish) is not a soup")
        }
    }

    /// One pot, two evenings.
    func testSoupDinnersComeInConsecutivePairs() {
        let weekStart = MealRules.mondayOf(day(0))
        let plan = MealPlanner.plan(
            weekStart: weekStart, birthDate: eightMonthBirthDate(for: weekStart),
            foods: MealSeed.foods(), recipes: MealSeed.recipes(),
            menu: [], logs: []
        )

        let byDay = plan.meals
            .filter { $0.slot == .dinner }
            .sorted { $0.date < $1.date }
            .map { $0.recipeID ?? "" }

        XCTAssertEqual(byDay.count, 7)
        // Days 0–1, 2–3, 4–5 are pairs; day 6 is the tail of the rotation.
        XCTAssertEqual(byDay[0], byDay[1])
        XCTAssertEqual(byDay[2], byDay[3])
        XCTAssertEqual(byDay[4], byDay[5])
        XCTAssertNotEqual(byDay[1], byDay[2], "a new pot on day three")
    }

    /// Accents ride along in the dish but never fill a rotation slot.
    func testGeneratedSoupDinnersKeepAccentsOutOfRotation() {
        let weekStart = MealRules.mondayOf(day(0))
        let plan = MealPlanner.plan(
            weekStart: weekStart, birthDate: eightMonthBirthDate(for: weekStart),
            foods: MealSeed.foods(), recipes: MealSeed.recipes(),
            menu: [], logs: []
        )
        let dinners = plan.meals.filter { $0.slot == .dinner }
        XCTAssertFalse(dinners.contains { $0.foodIDs.contains("uleimasline") })
    }

    /// At nine months the rule lets go and dinner goes back to normal.
    func testDinnerReturnsToNormalAtNineMonths() {
        let weekStart = MealRules.mondayOf(day(0))
        let birth = MealRules.calendar.date(byAdding: .month, value: -9, to: weekStart)!
        let recipesByID = Dictionary(MealSeed.recipes().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        let plan = MealPlanner.plan(
            weekStart: weekStart, birthDate: birth,
            foods: MealSeed.foods(), recipes: MealSeed.recipes(),
            menu: [], logs: []
        )
        let dinners = plan.meals.filter { $0.slot == .dinner }
        XCTAssertFalse(dinners.isEmpty)
        XCTAssertFalse(dinners.allSatisfy { ($0.recipeID.flatMap { recipesByID[$0] })?.form == .soup })
    }

    /// A hand-written dinner is never overwritten, soup rule or not.
    func testAHandWrittenDinnerSurvivesPlanning() {
        let weekStart = MealRules.mondayOf(day(0))
        let mine = MenuEntry(date: weekStart, slot: .dinner, dish: "Whatever we had",
                             foodIDs: ["pui"], calendar: MealRules.calendar)

        let plan = MealPlanner.plan(
            weekStart: weekStart, birthDate: eightMonthBirthDate(for: weekStart),
            foods: MealSeed.foods(), recipes: MealSeed.recipes(),
            menu: [mine], logs: []
        )
        let mondayDinner = plan.meals.first {
            $0.slot == .dinner && MealRules.startOfDay($0.date) == weekStart
        }
        XCTAssertNil(mondayDinner, "the planner leaves an occupied slot alone")
    }

    // MARK: - Bringing an already-planned week in line

    /// Returns the **container**, not the context. A `ModelContext` does not keep
    /// its container alive, so handing back `container.mainContext` from a helper
    /// lets the container deallocate and the next fetch traps inside SwiftData.
    @MainActor
    private func seededContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Food.self, Recipe.self, MenuEntry.self, MealLog.self, SoupBatch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        MealSeed.foods().forEach { container.mainContext.insert($0) }
        MealSeed.recipes().forEach { container.mainContext.insert($0) }
        try container.mainContext.save()
        return container
    }

    @MainActor
    func testStaleGeneratedDinnersAreReplacedWithSoups() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let weekStart = MealRules.mondayOf(day(0))
        let birth = eightMonthBirthDate(for: weekStart)

        // A dinner from before the rule existed, marked as the planner's work.
        let old = MenuEntry(date: weekStart, slot: .dinner, dish: "Broccoli + potato",
                            foodIDs: ["broccoli", "cartof"], calendar: MealRules.calendar)
        old.isGenerated = true
        context.insert(old)
        try context.save()

        let replaced = MealPlanner.refreshDinnersForRule(
            weekStart: weekStart, birthDate: birth, in: context)
        XCTAssertGreaterThan(replaced, 0)

        let recipes = Dictionary(MealSeed.recipes().map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let entries = (try context.fetch(FetchDescriptor<MenuEntry>()))
            .filter { $0.slot == .dinner && MealRules.startOfDay($0.date) == weekStart }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.recipeID.flatMap { recipes[$0] }?.form, .soup)
    }

    /// CRITICAL — a dinner typed by hand is never rewritten by a rule change.
    @MainActor
    func testHandWrittenDinnersAreLeftAloneByTheRefresh() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let weekStart = MealRules.mondayOf(day(0))

        let mine = MenuEntry(date: weekStart, slot: .dinner, dish: "Leftover risotto",
                             foodIDs: ["cartof"], calendar: MealRules.calendar)
        mine.isGenerated = false
        context.insert(mine)
        try context.save()

        MealPlanner.refreshDinnersForRule(
            weekStart: weekStart, birthDate: eightMonthBirthDate(for: weekStart), in: context)

        let still = (try context.fetch(FetchDescriptor<MenuEntry>()))
            .first { $0.slot == .dinner && MealRules.startOfDay($0.date) == weekStart }
        XCTAssertEqual(still?.dish, "Leftover risotto")
    }

    /// Outside the window the refresh does nothing at all.
    @MainActor
    func testRefreshIsANoOpAtNineMonths() throws {
        let container = try seededContainer()
        let context = container.mainContext
        let weekStart = MealRules.mondayOf(day(0))
        let birth = MealRules.calendar.date(byAdding: .month, value: -9, to: weekStart)!

        let old = MenuEntry(date: weekStart, slot: .dinner, dish: "Broccoli + potato",
                            foodIDs: ["broccoli", "cartof"], calendar: MealRules.calendar)
        old.isGenerated = true
        context.insert(old)
        try context.save()

        XCTAssertEqual(MealPlanner.refreshDinnersForRule(
            weekStart: weekStart, birthDate: birth, in: context), 0)
    }

    // MARK: - Period starts (cycle spec, Part 1)

    func testPeriodStartNormalisesToTheDay() {
        let afternoon = day(0).addingTimeInterval(15 * 3600 + 42 * 60)
        let entry = PeriodStart(startDate: afternoon)
        XCTAssertEqual(entry.startDate, PeriodStart.calendar.startOfDay(for: afternoon))
        XCTAssertEqual(entry.dayKey, PeriodStart.dayKey(afternoon))
    }

    /// Two taps on the same day land on different instants but the same key —
    /// which is what the store's uniqueness rule hangs on.
    func testSameDayAtDifferentTimesSharesOneKey() {
        let morning = day(0).addingTimeInterval(7 * 3600)
        let night = day(0).addingTimeInterval(23 * 3600)
        XCTAssertNotEqual(morning, night)
        XCTAssertEqual(PeriodStart(startDate: morning).dayKey,
                       PeriodStart(startDate: night).dayKey)
    }

    func testMovingAnEntryKeepsTheKeyInStep() {
        let entry = PeriodStart(startDate: day(0))
        entry.move(to: day(3).addingTimeInterval(11 * 3600))
        XCTAssertEqual(entry.startDate, PeriodStart.calendar.startOfDay(for: day(3)))
        XCTAssertEqual(entry.dayKey, PeriodStart.dayKey(day(3)))
    }

    /// Spotting is logged, but never counted as the start of a cycle.
    func testSpottingIsExcludedFromCycleMaths() {
        XCTAssertTrue(PeriodStart(startDate: day(0)).countsForCycleLength)
        XCTAssertFalse(PeriodStart(startDate: day(0), isSpotting: true).countsForCycleLength)
    }

    /// One row per calendar day, enforced by the store rather than by a screen.
    @MainActor
    func testTheStoreKeepsOnlyOneEntryPerDay() throws {
        let container = try ModelContainer(
            for: PeriodStart.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        context.insert(PeriodStart(startDate: day(0).addingTimeInterval(8 * 3600)))
        try context.save()
        context.insert(PeriodStart(startDate: day(0).addingTimeInterval(20 * 3600)))
        try context.save()

        let rows = try context.fetch(FetchDescriptor<PeriodStart>())
        XCTAssertEqual(rows.count, 1, "a second entry for the same day replaces the first")
    }

    @MainActor
    func testDifferentDaysAreKeptSeparately() throws {
        let container = try ModelContainer(
            for: PeriodStart.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        context.insert(PeriodStart(startDate: day(0)))
        context.insert(PeriodStart(startDate: day(28)))
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<PeriodStart>()).count, 2)
    }
}
