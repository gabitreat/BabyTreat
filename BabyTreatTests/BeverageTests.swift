import XCTest
import SwiftData
@testable import BabyTreat

/// Part 7 tests 1, 2, 7 and 16, plus the arithmetic they rest on.
final class BeverageTests: XCTestCase {

    // MARK: - Test 1 · density

    /// 330 mL of regular cola at 40 kcal/100 g.
    ///
    /// 330 × 1.043 = 344.19 g → 137.68 kcal. Treating millilitres as grams
    /// gives 132.0, which is 4.3% low — small enough to look right and large
    /// enough to matter across a habit.
    func testColaUsesDensityNotVolume() {
        let kcal = BeverageCalculator.kcal(
            volumeML: 330,
            densityGPerML: BeverageDensity.colaRegular,
            kcalPer100g: 40
        )
        XCTAssertEqual(kcal, 137.7, accuracy: 0.2)
        XCTAssertNotEqual(kcal, 132.0, accuracy: 0.2, "millilitres were treated as grams")
    }

    func testGramsIsVolumeTimesDensity() {
        XCTAssertEqual(
            BeverageCalculator.grams(volumeML: 330, densityGPerML: BeverageDensity.colaRegular),
            344.19, accuracy: 0.01)
    }

    /// A negative volume is a typo, not a drink that gives calories back.
    func testNegativeVolumeIsClampedToZero() {
        XCTAssertEqual(
            BeverageCalculator.kcal(volumeML: -250, densityGPerML: 1.043, kcalPer100g: 42),
            0, accuracy: 0.0001)
    }

    // MARK: - Test 2 · the flat white

    /// 240 mL, two shots: 60 mL espresso + 180 mL whole milk.
    /// Milk 180 × 1.030 = 185.4 g → 118.66 kcal. Espresso 60 g → 1.2 kcal.
    func testFlatWhiteWithWholeMilk() {
        let entry = BeverageTemplate.flatWhite.entry()
        XCTAssertEqual(BeverageCalculator.nutrition(of: entry).kcal, 120, accuracy: 2)
    }

    /// The same cup with skimmed milk. The 54 kcal gap between this and the one
    /// above is the entire reason a flat white is composed and not looked up.
    func testFlatWhiteWithSkimmedMilk() {
        let entry = BeverageTemplate.flatWhite.entry(baseID: BeverageLibrary.skimmedMilkID)
        XCTAssertEqual(BeverageCalculator.nutrition(of: entry).kcal, 66, accuracy: 2)
    }

    func testFlatWhiteMilkTakesTheVolumeTheEspressoLeaves() {
        let parts = BeverageTemplate.flatWhite.components(sizeML: 240, units: 2)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0].volumeML, 60, accuracy: 0.001)   // espresso
        XCTAssertEqual(parts[1].volumeML, 180, accuracy: 0.001)  // milk
        XCTAssertEqual(parts.reduce(0) { $0 + $1.volumeML }, 240, accuracy: 0.001)
    }

    /// A larger cup is more milk, not more coffee.
    func testLargerFlatWhiteAddsMilkOnly() {
        let small = BeverageTemplate.flatWhite.components(sizeML: 180)
        let large = BeverageTemplate.flatWhite.components(sizeML: 300)
        XCTAssertEqual(small[0].volumeML, large[0].volumeML, accuracy: 0.001)
        XCTAssertEqual(large[1].volumeML - small[1].volumeML, 120, accuracy: 0.001)
    }

    /// The blended per-100-g figures written onto a built entry have to
    /// reproduce its total, or the day view and the recipe would disagree.
    func testBuiltEntryBlendReproducesItsOwnTotal() {
        let entry = BeverageTemplate.flatWhite.entry()
        let fromComponents = BeverageCalculator.nutrition(of: entry).kcal
        let fromBlend = BeverageCalculator.kcal(
            volumeML: entry.volumeML,
            densityGPerML: entry.densityGPerML,
            kcalPer100g: entry.kcalPer100g
        )
        XCTAssertEqual(fromComponents, fromBlend, accuracy: 0.01)
    }

    /// Milk protein is most of what a flat white contributes besides energy.
    /// Losing it would quietly under-count protein, which is the direction this
    /// module is meant to guard against.
    func testFlatWhiteCarriesMilkProtein() {
        let facts = BeverageCalculator.nutrition(of: BeverageTemplate.flatWhite.entry())
        XCTAssertEqual(facts.protein, 5.99, accuracy: 0.1)
    }

    // MARK: - Test 7 · the slot is never guessed

    /// A drink logged at one o'clock is not a lunch drink until someone says so.
    func testSlotIsNilWhenNotSet() {
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 28
        components.hour = 13; components.minute = 0
        let onePM = Calendar.current.date(from: components)!

        let entry = BeverageLibrary.item(BeverageLibrary.colaID)!
            .entry(volumeML: 330, consumedAt: onePM)

        XCTAssertNil(entry.slot)
        XCTAssertNil(entry.slotRaw)
    }

    func testSlotIsKeptWhenSet() {
        let entry = BeverageLibrary.item(BeverageLibrary.colaID)!
            .entry(volumeML: 330, slot: .lunch)
        XCTAssertEqual(entry.slot, .lunch)
    }

    // MARK: - Test 16 · the fibre convention

    /// 20 g of carbohydrate with 6 g of fibre means different things either
    /// side of the Atlantic. On a US label the fibre is inside the 20; on a
    /// Romanian one it is beside it.
    func testTotalConventionSubtractsFibre() {
        XCTAssertEqual(CarbConvention.total.availableCarbs(carbs: 20, fibre: 6), 14)
    }

    func testAvailableConventionKeepsTheStatedFigure() {
        XCTAssertEqual(CarbConvention.available.availableCarbs(carbs: 20, fibre: 6), 20)
    }

    /// No fibre figure on a US label means the conversion cannot be done.
    /// Assuming zero would count the fibre as sugar and starch.
    func testTotalConventionWithoutFibreIsUnconvertible() {
        XCTAssertNil(CarbConvention.total.availableCarbs(carbs: 20, fibre: nil))
    }

    func testUnknownConventionIsExcludedFromTheCarbTotal() {
        XCTAssertNil(CarbConvention.unknown.availableCarbs(carbs: 20, fibre: 6))
    }

    func testConventionDefaultsToAvailableForRomanianProducts() {
        XCTAssertEqual(CarbConvention.forOpenFoodFacts(countryTags: ["en:romania"]), .available)
        XCTAssertEqual(CarbConvention.forOpenFoodFacts(countryTags: []), .available)
    }

    func testConventionDefaultsToTotalForNorthAmericanProducts() {
        XCTAssertEqual(
            CarbConvention.forOpenFoodFacts(countryTags: ["en:united-states"]), .total)
        XCTAssertEqual(
            CarbConvention.forOpenFoodFacts(countryTags: ["en:romania", "en:canada"]), .total)
    }

    /// The conversion runs on the poured amount, not the per-100-g figures.
    func testAvailableCarbsOnAnEntryScalesFirst() {
        let entry = BeverageEntry(
            name: "US bran drink", volumeML: 200, densityGPerML: 1.0,
            kcalPer100g: 50, carbsPer100g: 20, fibrePer100g: 6,
            carbConvention: .total, sourceKind: .manualEntry
        )
        // 200 g poured → 40 g carbs, 12 g fibre → 28 g available.
        XCTAssertEqual(BeverageCalculator.availableCarbs(of: entry)!, 28, accuracy: 0.001)
    }

    // MARK: - Energy is never derived from the macros (C13)

    /// A drink whose stated energy disagrees with its macros keeps the stated
    /// figure. Reconciliation lands in stage 5b; it must never rewrite this.
    func testStatedEnergyIsNotRecomputedFromMacros() {
        let entry = BeverageEntry(
            name: "Odd label", volumeML: 100, densityGPerML: 1.0,
            kcalPer100g: 42,           // an Atwater sum would say 40
            proteinPer100g: 0, carbsPer100g: 10, fatPer100g: 0,
            sourceKind: .manualEntry
        )
        XCTAssertEqual(BeverageCalculator.nutrition(of: entry).kcal, 42, accuracy: 0.001)
    }

    // MARK: - The seed library

    func testSeedLibraryIdsAreUnique() {
        let ids = Set(BeverageLibrary.items.map(\.id))
        XCTAssertEqual(ids.count, BeverageLibrary.items.count)
    }

    /// Every shipped row is a Romanian label, so fibre sits outside the
    /// carbohydrate figure on all of them.
    func testSeedLibraryDeclaresItsCarbConvention() {
        for item in BeverageLibrary.items {
            XCTAssertEqual(item.carbConvention, .available, "\(item.name)")
        }
    }

    /// Cola Zero keeps its 0.3 kcal/100 g in the model. Rounding at source
    /// would be a second place where a stated value quietly gets edited.
    func testColaZeroKeepsItsRealValue() {
        let item = BeverageLibrary.item(BeverageLibrary.colaZeroID)!
        XCTAssertEqual(item.kcalPer100g, 0.3, accuracy: 0.0001)
    }

    /// The two timestamps are different facts. Typing last night's cola in this
    /// morning must not move when it was drunk.
    func testLoggedAtAndConsumedAtAreIndependent() {
        let lastNight = Date(timeIntervalSince1970: 1_756_400_000)
        let entry = BeverageLibrary.item(BeverageLibrary.colaID)!
            .entry(volumeML: 330, consumedAt: lastNight)
        XCTAssertEqual(entry.consumedAt.timeIntervalSince1970, lastNight.timeIntervalSince1970, accuracy: 60)
        XCTAssertGreaterThan(entry.loggedAt, entry.consumedAt)
    }

    func testConsumedAtIsRoundedToTheMinute() {
        let withSeconds = Date(timeIntervalSince1970: 1_756_400_037)
        let entry = BeverageLibrary.item(BeverageLibrary.colaID)!
            .entry(volumeML: 330, consumedAt: withSeconds)
        XCTAssertEqual(Calendar.current.component(.second, from: entry.consumedAt), 0)
    }

    // MARK: - It survives being stored

    @MainActor
    func testBeverageEntryRoundTripsThroughSwiftData() throws {
        let container = try ModelContainer(
            for: BeverageEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        context.insert(BeverageTemplate.flatWhite.entry(slot: .breakfast))
        try context.save()

        let stored = try context.fetch(FetchDescriptor<BeverageEntry>())
        XCTAssertEqual(stored.count, 1)
        let entry = try XCTUnwrap(stored.first)
        XCTAssertEqual(entry.slot, .breakfast)
        XCTAssertEqual(entry.sourceKind, .builtRecipe)
        XCTAssertEqual(entry.recipeComponents?.count, 2)
        XCTAssertEqual(BeverageCalculator.nutrition(of: entry).kcal, 120, accuracy: 2)
    }
}
