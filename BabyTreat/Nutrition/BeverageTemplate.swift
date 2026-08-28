import Foundation

/// A recipe for a drink that has to be composed rather than looked up.
///
/// A flat white is the worked example: essentially all of its energy is the
/// milk, so a single hardcoded "flat white — 120 kcal" row is wrong the moment
/// the milk changes. Same drink, whole milk to skimmed, is a 54 kcal swing.
///
/// The shape is deliberately data, not code: a new template is a value in
/// `all`, and adding one needs no change to `BeverageEntry` or
/// `BeverageComponent`.
struct BeverageTemplate: Identifiable, Equatable {
    var id: String
    var name: String

    /// Cup sizes offered, in millilitres.
    var sizesML: [Double]
    var defaultSizeML: Double

    /// A part poured in fixed units — espresso, at 30 mL a shot.
    var unitPart: UnitPart?
    /// The part that fills whatever volume is left.
    var base: BasePart

    struct UnitPart: Equatable {
        var ingredientID: UUID
        var volumeMLPerUnit: Double
        var defaultUnits: Int
        var minUnits: Int
        var maxUnits: Int
    }

    struct BasePart: Equatable {
        /// Offered in this order.
        var choices: [UUID]
        var defaultID: UUID
    }

    /// The parts of one drink, ready to price.
    ///
    /// Anything left `nil` takes the template's default, so the caller can pass
    /// only what the user actually changed.
    func components(sizeML: Double? = nil, baseID: UUID? = nil, units: Int? = nil) -> [BeverageComponent] {
        let size = max(0, sizeML ?? defaultSizeML)
        var parts: [BeverageComponent] = []
        var poured: Double = 0

        if let unitPart {
            let count = min(max(units ?? unitPart.defaultUnits, unitPart.minUnits), unitPart.maxUnits)
            let volume = min(size, Double(count) * unitPart.volumeMLPerUnit)
            if let item = BeverageLibrary.item(unitPart.ingredientID), volume > 0 {
                parts.append(item.component(volumeML: volume))
                poured += volume
            }
        }

        let chosen = baseID.flatMap { base.choices.contains($0) ? $0 : nil } ?? base.defaultID
        if let item = BeverageLibrary.item(chosen) {
            parts.append(item.component(volumeML: max(0, size - poured)))
        }
        return parts
    }

    /// The finished drink, named for the milk that is actually in it.
    func entry(
        sizeML: Double? = nil,
        baseID: UUID? = nil,
        units: Int? = nil,
        slot: MealSlot? = nil,
        consumedAt: Date = .now
    ) -> BeverageEntry {
        BeverageEntry.built(
            name: name,
            components: components(sizeML: sizeML, baseID: baseID, units: units),
            slot: slot,
            consumedAt: consumedAt
        )
    }
}

extension BeverageTemplate {
    /// Espresso plus milk. The espresso is 1.2 kcal and could be dropped
    /// without anyone noticing — it is here because leaving a real ingredient
    /// out of a recipe is how recipes start drifting.
    static let flatWhite = BeverageTemplate(
        id: "flat-white",
        name: "Flat white",
        sizesML: [180, 240, 300],
        defaultSizeML: 240,
        unitPart: UnitPart(
            ingredientID: BeverageLibrary.espressoID,
            volumeMLPerUnit: 30,
            defaultUnits: 2,
            minUnits: 1,
            maxUnits: 4
        ),
        base: BasePart(
            choices: BeverageLibrary.milkIDs,
            defaultID: BeverageLibrary.wholeMilkID
        )
    )

    /// The milkshake template is deliberately absent — its default components
    /// are an open question (OQ-P1). Adding it is a new value in this array.
    static let all: [BeverageTemplate] = [flatWhite]
}
