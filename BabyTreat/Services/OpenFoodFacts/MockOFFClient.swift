import Foundation

/// Deterministic fixtures for previews and tests. No network, ever.
final class MockOFFClient: OFFClient {

    var productsByBarcode: [String: OFFLookup]
    var searchResults: [ProductSnapshot]
    /// Set to make the next call fail, for exercising error paths.
    var nextError: OFFError?

    init(
        productsByBarcode: [String: OFFLookup] = MockOFFClient.defaultProducts,
        searchResults: [ProductSnapshot] = [],
        nextError: OFFError? = nil
    ) {
        self.productsByBarcode = productsByBarcode
        self.searchResults = searchResults
        self.nextError = nextError
    }

    func product(barcode: String) async throws -> OFFLookup {
        if let nextError { throw nextError }
        guard OFFEndpoint.isValidBarcode(barcode) else { throw OFFError.invalidBarcode }
        return productsByBarcode[barcode] ?? .notFound
    }

    func search(_ query: String) async throws -> [ProductSnapshot] {
        if let nextError { throw nextError }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return searchResults
    }

    static let defaultProducts: [String: OFFLookup] = [
        "5941234567890": .found(
            ProductSnapshot(
                barcode: "5941234567890",
                name: "Iaurt grecesc 10%",
                brand: "Olympus",
                quantity: "400 g",
                servingSizeDisplay: "150 g",
                nutrition: NutritionFacts(
                    kcal: 116, protein: 5.6, carbs: 3.2, sugars: 3.2,
                    fat: 10, saturatedFat: 6.5, fiber: nil, salt: 0.1, sodium: 0.04,
                    per100: .grams, basis: .raw
                ),
                categoryTags: ["dairies", "fermented-foods", "yogurts"],
                allergenTags: ["milk"],
                traceTags: [],
                ingredientsText: "Lapte pasteurizat, culturi lactice",
                nutriscore: "c", novaGroup: 3,
                imageURL: nil
            )
        ),
        // Not in the database — the common Romanian-market case.
        "5949000000000": .notFound,
    ]
}

// MARK: - JSON fixtures

/// Raw API payloads, used by the tests so decoding is exercised end to end
/// rather than starting from an already-clean struct.
enum OFFFixtures {

    /// Everything populated: kcal published directly, all macros present.
    static let fullProduct = """
    {
      "status": 1,
      "status_verbose": "product found",
      "code": "5941234567890",
      "product": {
        "code": "5941234567890",
        "product_name": "Greek Yogurt 10%",
        "product_name_ro": "Iaurt grecesc 10%",
        "brands": "Olympus",
        "quantity": "400 g",
        "serving_size": "150 g",
        "categories_tags": ["en:dairies", "en:yogurts"],
        "allergens_tags": ["en:milk"],
        "traces_tags": ["en:nuts"],
        "ingredients_text_ro": "Lapte pasteurizat, culturi lactice",
        "nutriscore_grade": "c",
        "nova_group": 3,
        "nutriments": {
          "energy-kcal_100g": 116,
          "energy_100g": 485,
          "proteins_100g": 5.6,
          "carbohydrates_100g": 3.2,
          "sugars_100g": 3.2,
          "fat_100g": 10,
          "saturated-fat_100g": 6.5,
          "fiber_100g": 0,
          "salt_100g": 0.1,
          "sodium_100g": 0.04
        }
      }
    }
    """

    /// kJ only — kcal has to be derived and flagged.
    static let kilojoulesOnly = """
    {
      "status": 1,
      "code": "1111111111111",
      "product": {
        "code": "1111111111111",
        "product_name": "Ulei de masline",
        "quantity": "500 ml",
        "nutriments": { "energy_100g": 3700, "fat_100g": "91,6" }
      }
    }
    """

    /// The database saying no, with HTTP 200.
    static let notFound = """
    { "status": 0, "status_verbose": "product not found", "code": "5949000000000" }
    """

    /// No protein figure at all, and an empty Romanian name.
    static let missingProtein = """
    {
      "status": 1,
      "code": "2222222222222",
      "product": {
        "code": "2222222222222",
        "product_name": "Apa minerala",
        "product_name_ro": "",
        "quantity": "1.5 l",
        "nutriments": { "energy-kcal_100g": 0, "fat_100g": 0 }
      }
    }
    """
}
