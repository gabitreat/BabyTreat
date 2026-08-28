import Foundation

/// Grams per millilitre, at the temperature a drink is normally served.
///
/// These exist because a drink is measured in millilitres and labelled per 100
/// **grams**, and the two are not the same number. Sugar makes a liquid denser
/// than water: 330 mL of cola weighs 344 g, so treating the millilitres as
/// grams loses 4.3% of its calories every single time.
enum BeverageDensity {
    /// Water, and anything that is essentially water — black coffee, plain tea,
    /// zero-sugar soft drinks.
    static let water: Double = 1.000
    static let blackCoffee: Double = 1.000
    static let blackTea: Double = 1.000

    static let wholeMilk: Double = 1.030
    static let semiSkimmedMilk: Double = 1.033
    static let skimmedMilk: Double = 1.035

    static let colaRegular: Double = 1.043
    static let colaZero: Double = 1.000

    static let orangeJuice: Double = 1.045
    static let appleJuice: Double = 1.048
}

/// The drinks that ship with the app, so the common cases need no typing.
///
/// A seeded row is a **fallback**, not the preferred path. For anything with a
/// barcode the scan through `OFFClient` wins, because it reads the actual
/// product rather than a category average. The rows exist so a thin Romanian
/// Open Food Facts result never leaves the user stuck.
enum BeverageLibrary {

    /// One shipped drink. Everything is per 100 g, which is the basis Open Food
    /// Facts returns and Romanian labels print.
    struct Item: Identifiable, Equatable, Hashable {
        var id: UUID
        var name: String
        var densityGPerML: Double
        var kcalPer100g: Double
        var proteinPer100g: Double
        var carbsPer100g: Double
        var sugarsPer100g: Double
        var fatPer100g: Double
        var fibrePer100g: Double
        /// Romanian labels are EU labels, so fibre sits outside the
        /// carbohydrate figure on every row here.
        var carbConvention: CarbConvention = .available
        /// True when the published figure spans a wide range and a barcode scan
        /// is the honest path. Nectar is the case — 50% fruit covers a lot of
        /// ground.
        var isApproximate: Bool = false
        /// A sensible pour, used to prefill the volume field.
        var typicalVolumeML: Double
    }

    static let colaID          = UUID(uuidString: "60C87DD8-B0F0-4AB5-BC60-D2445E1C155D")!
    static let colaZeroID      = UUID(uuidString: "9990F00E-F94A-46B3-9BEE-52659550F2D6")!
    static let orangeJuiceID   = UUID(uuidString: "90A4A79F-60AF-4C3B-B05A-CD2F22960A72")!
    static let appleJuiceID    = UUID(uuidString: "CBE2BA56-47C4-4F0A-831C-FA8F6EAA36B8")!
    static let nectarID        = UUID(uuidString: "9D7027B0-9EE1-47F6-8A92-362D725A2010")!
    static let wholeMilkID     = UUID(uuidString: "9C50CDE7-B452-459C-8A59-7311EF9CC55B")!
    static let semiSkimmedID   = UUID(uuidString: "CACB176B-B11A-4D6A-8950-1D264F6022C2")!
    static let skimmedMilkID   = UUID(uuidString: "8C3F83FE-6A9B-444D-933A-7C298F1E7BDA")!
    static let espressoID      = UUID(uuidString: "031BD0C9-A1F6-49E5-A766-0D00ABEF0DD3")!
    static let blackTeaID      = UUID(uuidString: "C6EF5BE7-5F68-4DCE-91C8-3E0DB47BFC6B")!

    static let items: [Item] = [
        Item(id: colaID, name: "Coca-Cola",
             densityGPerML: BeverageDensity.colaRegular,
             kcalPer100g: 42, proteinPer100g: 0, carbsPer100g: 10.6,
             sugarsPer100g: 10.6, fatPer100g: 0, fibrePer100g: 0,
             typicalVolumeML: 330),

        // 0.3 kcal/100 g is kept in the model and shown as 0. Rounding it away
        // at source would be a second place where a stated value gets edited.
        Item(id: colaZeroID, name: "Coca-Cola Zero",
             densityGPerML: BeverageDensity.colaZero,
             kcalPer100g: 0.3, proteinPer100g: 0, carbsPer100g: 0,
             sugarsPer100g: 0, fatPer100g: 0, fibrePer100g: 0,
             typicalVolumeML: 330),

        Item(id: orangeJuiceID, name: "Suc natural de portocale",
             densityGPerML: BeverageDensity.orangeJuice,
             kcalPer100g: 45, proteinPer100g: 0.7, carbsPer100g: 10.4,
             sugarsPer100g: 8.9, fatPer100g: 0.2, fibrePer100g: 0.2,
             typicalVolumeML: 250),

        Item(id: appleJuiceID, name: "Suc natural de mere",
             densityGPerML: BeverageDensity.appleJuice,
             kcalPer100g: 46, proteinPer100g: 0.1, carbsPer100g: 11.3,
             sugarsPer100g: 9.6, fatPer100g: 0.1, fibrePer100g: 0.1,
             typicalVolumeML: 250),

        Item(id: nectarID, name: "Nectar de fructe (50%)",
             densityGPerML: BeverageDensity.orangeJuice,
             kcalPer100g: 55, proteinPer100g: 0.2, carbsPer100g: 13.0,
             sugarsPer100g: 12.5, fatPer100g: 0.1, fibrePer100g: 0.2,
             isApproximate: true, typicalVolumeML: 250),

        Item(id: wholeMilkID, name: "Lapte integral 3,5%",
             densityGPerML: BeverageDensity.wholeMilk,
             kcalPer100g: 64, proteinPer100g: 3.2, carbsPer100g: 4.7,
             sugarsPer100g: 4.7, fatPer100g: 3.5, fibrePer100g: 0,
             typicalVolumeML: 200),

        Item(id: semiSkimmedID, name: "Lapte semidegresat 1,5%",
             densityGPerML: BeverageDensity.semiSkimmedMilk,
             kcalPer100g: 46, proteinPer100g: 3.3, carbsPer100g: 4.8,
             sugarsPer100g: 4.8, fatPer100g: 1.5, fibrePer100g: 0,
             typicalVolumeML: 200),

        Item(id: skimmedMilkID, name: "Lapte degresat 0,1%",
             densityGPerML: BeverageDensity.skimmedMilk,
             kcalPer100g: 34, proteinPer100g: 3.4, carbsPer100g: 4.9,
             sugarsPer100g: 4.9, fatPer100g: 0.1, fibrePer100g: 0,
             typicalVolumeML: 200),

        Item(id: espressoID, name: "Espresso",
             densityGPerML: BeverageDensity.blackCoffee,
             kcalPer100g: 2, proteinPer100g: 0.1, carbsPer100g: 0,
             sugarsPer100g: 0, fatPer100g: 0, fibrePer100g: 0,
             typicalVolumeML: 30),

        Item(id: blackTeaID, name: "Ceai negru neîndulcit",
             densityGPerML: BeverageDensity.blackTea,
             kcalPer100g: 1, proteinPer100g: 0, carbsPer100g: 0.3,
             sugarsPer100g: 0, fatPer100g: 0, fibrePer100g: 0,
             typicalVolumeML: 250),
    ]

    static func item(_ id: UUID) -> Item? { items.first { $0.id == id } }

    /// The three milks, in the order the builder should offer them.
    static let milkIDs: [UUID] = [wholeMilkID, semiSkimmedID, skimmedMilkID]
}

extension BeverageLibrary.Item {
    /// This item poured at a given volume, as a component of a built drink.
    func component(volumeML: Double) -> BeverageComponent {
        BeverageComponent(
            ingredientID: id, name: name, volumeML: volumeML,
            densityGPerML: densityGPerML, kcalPer100g: kcalPer100g,
            proteinPer100g: proteinPer100g, carbsPer100g: carbsPer100g,
            sugarsPer100g: sugarsPer100g, fatPer100g: fatPer100g,
            fibrePer100g: fibrePer100g
        )
    }

    /// This item logged on its own — a glass of juice, a can of cola.
    func entry(
        volumeML: Double,
        slot: MealSlot? = nil,
        consumedAt: Date = .now
    ) -> BeverageEntry {
        BeverageEntry(
            name: name, volumeML: volumeML, densityGPerML: densityGPerML,
            kcalPer100g: kcalPer100g, proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g, sugarsPer100g: sugarsPer100g,
            fatPer100g: fatPer100g, fibrePer100g: fibrePer100g,
            carbConvention: carbConvention, sourceKind: .seedLibrary,
            slot: slot, consumedAt: consumedAt
        )
    }
}
