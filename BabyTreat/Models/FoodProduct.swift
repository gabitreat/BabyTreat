import Foundation
import SwiftData

enum ProductSource: String, Codable {
    case openFoodFacts
    case manual
}

/// Local cache of looked-up products, and the record of manually entered ones.
///
/// Nutrition is **flattened into individual optional Doubles** rather than
/// stored as a nested `NutritionFacts`: SwiftData does not persist nested value
/// types reliably, and flat scalar columns are also what a later Supabase port
/// wants. Read and write it through `nutrition`, never field by field.
@Model
final class FoodProduct {
    /// `nil` for a manual entry. Unique where present, so a rescan updates the
    /// existing row instead of adding a duplicate.
    @Attribute(.unique) var barcode: String?
    var name: String
    var brand: String?
    var quantity: String?
    /// Free text off the label. Display only — never used for arithmetic.
    var servingSizeDisplay: String?

    // Per 100 g/ml. Optional throughout: nil means unknown, 0 means zero.
    var kcalPer100: Double?
    var proteinPer100: Double?
    var carbsPer100: Double?
    var sugarsPer100: Double?
    var fatPer100: Double?
    var saturatedFatPer100: Double?
    var fiberPer100: Double?
    var saltPer100: Double?
    var sodiumPer100: Double?

    var per100UnitRaw: String
    var weightBasisRaw: String
    var energyWasDerived: Bool

    var sourceRaw: String
    var fetchedAt: Date?
    var imageURL: String?
    /// Language prefixes stripped, otherwise as the database has them. Not
    /// mapped onto the app's allergen families — a separate concern.
    var rawAllergenTags: [String]
    var rawTraceTags: [String]

    init(
        barcode: String? = nil,
        name: String,
        brand: String? = nil,
        quantity: String? = nil,
        servingSizeDisplay: String? = nil,
        nutrition: NutritionFacts = NutritionFacts(),
        source: ProductSource = .manual,
        fetchedAt: Date? = nil,
        imageURL: String? = nil,
        rawAllergenTags: [String] = [],
        rawTraceTags: [String] = []
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.quantity = quantity
        self.servingSizeDisplay = servingSizeDisplay
        self.kcalPer100 = nutrition.kcal
        self.proteinPer100 = nutrition.protein
        self.carbsPer100 = nutrition.carbs
        self.sugarsPer100 = nutrition.sugars
        self.fatPer100 = nutrition.fat
        self.saturatedFatPer100 = nutrition.saturatedFat
        self.fiberPer100 = nutrition.fiber
        self.saltPer100 = nutrition.salt
        self.sodiumPer100 = nutrition.sodium
        self.per100UnitRaw = nutrition.per100.rawValue
        self.weightBasisRaw = nutrition.basis.rawValue
        self.energyWasDerived = nutrition.energyWasDerived
        self.sourceRaw = source.rawValue
        self.fetchedAt = fetchedAt
        self.imageURL = imageURL
        self.rawAllergenTags = rawAllergenTags
        self.rawTraceTags = rawTraceTags
    }

    convenience init(snapshot: ProductSnapshot, fetchedAt: Date = .now) {
        self.init(
            barcode: snapshot.barcode,
            name: snapshot.name,
            brand: snapshot.brand,
            quantity: snapshot.quantity,
            servingSizeDisplay: snapshot.servingSizeDisplay,
            nutrition: snapshot.nutrition,
            source: .openFoodFacts,
            fetchedAt: fetchedAt,
            imageURL: snapshot.imageURL,
            rawAllergenTags: snapshot.allergenTags,
            rawTraceTags: snapshot.traceTags
        )
    }

    var nutrition: NutritionFacts {
        get {
            NutritionFacts(
                kcal: kcalPer100, protein: proteinPer100, carbs: carbsPer100,
                sugars: sugarsPer100, fat: fatPer100, saturatedFat: saturatedFatPer100,
                fiber: fiberPer100, salt: saltPer100, sodium: sodiumPer100,
                per100: NutritionUnit(rawValue: per100UnitRaw) ?? .grams,
                basis: WeightBasis(rawValue: weightBasisRaw) ?? .raw,
                energyWasDerived: energyWasDerived
            )
        }
        set {
            kcalPer100 = newValue.kcal
            proteinPer100 = newValue.protein
            carbsPer100 = newValue.carbs
            sugarsPer100 = newValue.sugars
            fatPer100 = newValue.fat
            saturatedFatPer100 = newValue.saturatedFat
            fiberPer100 = newValue.fiber
            saltPer100 = newValue.salt
            sodiumPer100 = newValue.sodium
            per100UnitRaw = newValue.per100.rawValue
            weightBasisRaw = newValue.basis.rawValue
            energyWasDerived = newValue.energyWasDerived
        }
    }

    var source: ProductSource {
        get { ProductSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Cache entries go stale after this. A stale entry is still returned if the
    /// refetch fails — old data beats no data.
    static let staleAfterDays = 30

    func isStale(asOf date: Date = .now) -> Bool {
        guard source == .openFoodFacts, let fetchedAt else { return false }
        let days = Calendar.current.dateComponents([.day], from: fetchedAt, to: date).day ?? 0
        return days >= Self.staleAfterDays
    }

    func update(from snapshot: ProductSnapshot, fetchedAt: Date = .now) {
        name = snapshot.name
        brand = snapshot.brand
        quantity = snapshot.quantity
        servingSizeDisplay = snapshot.servingSizeDisplay
        nutrition = snapshot.nutrition
        imageURL = snapshot.imageURL
        rawAllergenTags = snapshot.allergenTags
        rawTraceTags = snapshot.traceTags
        source = .openFoodFacts
        self.fetchedAt = fetchedAt
    }
}
