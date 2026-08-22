import Foundation

/// Codable structs mirroring the Open Food Facts response, one-for-one.
///
/// No cleaning happens here — that is `OFFMapper`'s job. The only concession is
/// `LenientDouble`, because the API genuinely returns numbers as both JSON
/// numbers and JSON strings for the same field, product to product.
enum OFFDTO {

    struct ProductResponse: Decodable {
        /// `1` = found, `0` = not in the database.
        let status: Int?
        let statusVerbose: String?
        let code: String?
        let product: Product?

        enum CodingKeys: String, CodingKey {
            case status
            case statusVerbose = "status_verbose"
            case code
            case product
        }
    }

    struct SearchResponse: Decodable {
        let count: Int?
        let products: [Product]?
    }

    struct Product: Decodable {
        let code: String?
        let productName: String?
        let productNameRO: String?
        let genericNameRO: String?
        let brands: String?
        let quantity: String?
        let servingSize: String?
        let categoriesTags: [String]?
        let allergensTags: [String]?
        let tracesTags: [String]?
        let ingredientsTextRO: String?
        let nutriments: Nutriments?
        let nutriscoreGrade: String?
        let novaGroup: LenientDouble?
        let imageFrontSmallURL: String?
        let imageFrontURL: String?

        enum CodingKeys: String, CodingKey {
            case code
            case productName = "product_name"
            case productNameRO = "product_name_ro"
            case genericNameRO = "generic_name_ro"
            case brands
            case quantity
            case servingSize = "serving_size"
            case categoriesTags = "categories_tags"
            case allergensTags = "allergens_tags"
            case tracesTags = "traces_tags"
            case ingredientsTextRO = "ingredients_text_ro"
            case nutriments
            case nutriscoreGrade = "nutriscore_grade"
            case novaGroup = "nova_group"
            case imageFrontSmallURL = "image_front_small_url"
            case imageFrontURL = "image_front_url"
        }
    }

    /// Only the per-100 fields. `serving_quantity` is intentionally absent:
    /// it is free text on the producer's side and unfit for arithmetic.
    struct Nutriments: Decodable {
        let energyKcal100g: LenientDouble?
        let energy100g: LenientDouble?
        let proteins100g: LenientDouble?
        let carbohydrates100g: LenientDouble?
        let sugars100g: LenientDouble?
        let fat100g: LenientDouble?
        let saturatedFat100g: LenientDouble?
        let fiber100g: LenientDouble?
        let salt100g: LenientDouble?
        let sodium100g: LenientDouble?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case energy100g = "energy_100g"
            case proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case sugars100g = "sugars_100g"
            case fat100g = "fat_100g"
            case saturatedFat100g = "saturated-fat_100g"
            case fiber100g = "fiber_100g"
            case salt100g = "salt_100g"
            case sodium100g = "sodium_100g"
        }
    }

    /// A number that may arrive as `12.5`, `"12.5"` or `"12,5"`.
    ///
    /// Decoding failure yields `value == nil` rather than throwing: one badly
    /// typed nutrient must not lose the whole product. Unknown stays unknown.
    struct LenientDouble: Decodable, Equatable {
        let value: Double?

        init(_ value: Double?) { self.value = value }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let double = try? container.decode(Double.self) {
                value = double
            } else if let string = try? container.decode(String.self) {
                value = Double(string.replacingOccurrences(of: ",", with: "."))
            } else {
                value = nil
            }
        }
    }
}
