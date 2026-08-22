import Foundation

/// Nutrition **always per 100 g or 100 ml**, never per serving.
///
/// Every field is optional on purpose. A missing nutrient is `nil`, never `0`:
/// "this product contains no fibre" and "nobody recorded the fibre" are
/// different facts, and collapsing them turns a gap in the data into a
/// confident wrong number in a daily total.
struct NutritionFacts: Codable, Equatable {
    var kcal: Double?
    var protein: Double?
    var carbs: Double?
    var sugars: Double?
    var fat: Double?
    var saturatedFat: Double?
    var fiber: Double?
    var salt: Double?
    var sodium: Double?

    /// Grams or millilitres — decided from the product's `quantity` string.
    var per100: NutritionUnit
    /// Never inferred. Open Food Facts is always `.raw`.
    var basis: WeightBasis
    /// True when kcal was computed from the kJ figure rather than read directly.
    /// Surfaced so the UI can mark a derived number as slightly less certain.
    var energyWasDerived: Bool

    init(
        kcal: Double? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        sugars: Double? = nil,
        fat: Double? = nil,
        saturatedFat: Double? = nil,
        fiber: Double? = nil,
        salt: Double? = nil,
        sodium: Double? = nil,
        per100: NutritionUnit = .grams,
        basis: WeightBasis = .raw,
        energyWasDerived: Bool = false
    ) {
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.sugars = sugars
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.fiber = fiber
        self.salt = salt
        self.sodium = sodium
        self.per100 = per100
        self.basis = basis
        self.energyWasDerived = energyWasDerived
    }

    /// kJ per kcal, the factor fixed by the EU labelling regulation.
    static let kilojoulesPerKcal = 4.184

    /// Scales to an arbitrary amount. Returns `nil` for any nutrient that was
    /// `nil` — scaling an unknown gives an unknown, not zero.
    func scaled(to amount: Double) -> NutritionFacts {
        let factor = amount / 100
        func scale(_ value: Double?) -> Double? { value.map { $0 * factor } }
        return NutritionFacts(
            kcal: scale(kcal), protein: scale(protein), carbs: scale(carbs),
            sugars: scale(sugars), fat: scale(fat), saturatedFat: scale(saturatedFat),
            fiber: scale(fiber), salt: scale(salt), sodium: scale(sodium),
            per100: per100, basis: basis, energyWasDerived: energyWasDerived
        )
    }

    var hasAnyValue: Bool {
        [kcal, protein, carbs, sugars, fat, saturatedFat, fiber, salt, sodium].contains { $0 != nil }
    }
}

/// A product as the client hands it back — a plain value, not a SwiftData
/// object. Keeping the network layer free of `@Model` means it can be used from
/// a background task, a preview or a test without a `ModelContext`.
struct ProductSnapshot: Equatable {
    var barcode: String
    var name: String
    var brand: String?
    /// The pack size string as written, e.g. "400 g". Display only.
    var quantity: String?
    /// Free text and unreliable, so it is **never** used for arithmetic —
    /// stored purely so the UI can show what the label claimed.
    var servingSizeDisplay: String?
    var nutrition: NutritionFacts
    var categoryTags: [String]
    /// Language prefixes stripped, tags otherwise raw. Deliberately not mapped
    /// onto `AllergenFamily` — that mapping belongs to the baby-food side and
    /// has its own rules.
    var allergenTags: [String]
    var traceTags: [String]
    var ingredientsText: String?
    var nutriscore: String?
    var novaGroup: Int?
    var imageURL: String?
}

/// "Not found" is a normal outcome, not a failure. Romanian-market coverage is
/// thin and the API answers with HTTP 200 and `status: 0`, so the caller routes
/// straight to manual entry instead of showing an error.
enum OFFLookup: Equatable {
    case found(ProductSnapshot)
    case notFound

    var product: ProductSnapshot? {
        if case .found(let snapshot) = self { return snapshot }
        return nil
    }
}
