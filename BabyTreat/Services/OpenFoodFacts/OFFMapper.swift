import Foundation

/// DTO → domain. Pure, so every rule below is testable without a network.
enum OFFMapper {

    static func snapshot(from product: OFFDTO.Product) -> ProductSnapshot {
        let barcode = product.code ?? ""
        return ProductSnapshot(
            barcode: barcode,
            name: displayName(for: product),
            brand: nonEmpty(product.brands),
            quantity: nonEmpty(product.quantity),
            servingSizeDisplay: nonEmpty(product.servingSize),
            nutrition: nutrition(from: product),
            categoryTags: strip(product.categoriesTags),
            allergenTags: strip(product.allergensTags),
            traceTags: strip(product.tracesTags),
            ingredientsText: nonEmpty(product.ingredientsTextRO),
            nutriscore: nonEmpty(product.nutriscoreGrade),
            novaGroup: product.novaGroup?.value.map { Int($0) },
            imageURL: nonEmpty(product.imageFrontSmallURL) ?? nonEmpty(product.imageFrontURL)
        )
    }

    /// First **non-empty** of: Romanian name → generic name → brand → barcode.
    ///
    /// Non-empty, not non-nil: the API frequently returns `""` for a missing
    /// localised name, and a nil-check alone would happily display a blank row.
    static func displayName(for product: OFFDTO.Product) -> String {
        nonEmpty(product.productNameRO)
            ?? nonEmpty(product.productName)
            ?? nonEmpty(product.genericNameRO)
            ?? nonEmpty(product.brands)
            ?? nonEmpty(product.code)
            ?? "Unknown product"
    }

    static func nutrition(from product: OFFDTO.Product) -> NutritionFacts {
        let n = product.nutriments

        // kcal directly if published; otherwise derive from the kJ figure and
        // say so. If neither exists it stays nil — never zero.
        var kcal = n?.energyKcal100g?.value
        var derived = false
        if kcal == nil, let kilojoules = n?.energy100g?.value {
            kcal = kilojoules / NutritionFacts.kilojoulesPerKcal
            derived = true
        }

        return NutritionFacts(
            kcal: kcal,
            protein: n?.proteins100g?.value,
            carbs: n?.carbohydrates100g?.value,
            sugars: n?.sugars100g?.value,
            fat: n?.fat100g?.value,
            saturatedFat: n?.saturatedFat100g?.value,
            fiber: n?.fiber100g?.value,
            salt: n?.salt100g?.value,
            sodium: n?.sodium100g?.value,
            per100: unit(for: product.quantity),
            // Open Food Facts describes products as sold. Always.
            basis: .raw,
            energyWasDerived: derived
        )
    }

    /// Liquids are labelled per 100 ml. Read from the pack size, defaulting to
    /// grams when the string says nothing useful.
    static func unit(for quantity: String?) -> NutritionUnit {
        guard let quantity = quantity?.lowercased() else { return .grams }
        let liquid = ["ml", "cl", "l ", " l", "litr", "liter", "litre"]
        return liquid.contains(where: quantity.contains) ? .millilitres : .grams
    }

    /// `en:milk` → `milk`. The prefix is a language marker, not part of the tag.
    /// Tags are otherwise left raw — mapping them onto the app's allergen
    /// families is a separate concern with its own rules.
    static func strip(_ tags: [String]?) -> [String] {
        (tags ?? []).map { tag in
            guard let colon = tag.firstIndex(of: ":") else { return tag }
            return String(tag[tag.index(after: colon)...])
        }
        .filter { !$0.isEmpty }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
