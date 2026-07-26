import Foundation
import SwiftData

/// A recipe references foods by **ID, never by name**. That is what lets the
/// colour strips and protein rotation work without duplicating data — see
/// `instructions/meal-planning/rules.md` § Data model.
@Model
final class Recipe {
    @Attribute(.unique) var id: String
    var title: String
    var minAgeMonths: Int
    var proteinFoodID: String?
    var foodIDs: [String]
    var ingredients: [String]
    var steps: [String]
    var spoonNote: String
    var blwNote: String
    var freezeNote: String
    var storeNote: String
    var nutrients: [String]
    var allergens: [String]
    /// Standing caveat shown on the card, e.g. the coconut-milk limit.
    var flag: String?
    var rating: Int

    init(
        id: String,
        title: String,
        minAgeMonths: Int,
        proteinFoodID: String? = nil,
        foodIDs: [String],
        ingredients: [String],
        steps: [String],
        spoonNote: String = "",
        blwNote: String = "",
        freezeNote: String = "",
        storeNote: String = "",
        nutrients: [String] = [],
        allergens: [String] = [],
        flag: String? = nil,
        rating: Int = 0
    ) {
        self.id = id
        self.title = title
        self.minAgeMonths = minAgeMonths
        self.proteinFoodID = proteinFoodID
        self.foodIDs = foodIDs
        self.ingredients = ingredients
        self.steps = steps
        self.spoonNote = spoonNote
        self.blwNote = blwNote
        self.freezeNote = freezeNote
        self.storeNote = storeNote
        self.nutrients = nutrients
        self.allergens = allergens
        self.flag = flag
        self.rating = rating
    }
}

/// External recipe sources are stored as **link only** — title, URL, category.
/// The content stays at the source. This is a copyright decision (D-1), not a
/// convenience one; do not cache article bodies here.
struct RecipeSource: Identifiable, Hashable {
    struct Section: Identifiable, Hashable {
        var id: String { url }
        let label: String
        let url: String
        var minAgeMonths: Int?
        var tag: String?
    }

    let id: String
    let name: String
    let author: String
    let url: String
    let blurb: String
    let sections: [Section]

    func searchURL(for query: String) -> URL? {
        let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "\(url)/?s=\(escaped)")
    }

    static let all: [RecipeSource] = [
        RecipeSource(
            id: "flaveur",
            name: "Flaveur",
            author: "Cristina Nenu",
            url: "https://flaveur.ro",
            blurb: "Recipes and weaning, in Romanian. Has dairy-free and egg-free categories — useful while the CMPA question is unconfirmed.",
            // Labels are our descriptions; the pages themselves are in Romanian.
            sections: [
                .init(label: "Lunch, 7 months",     url: "https://flaveur.ro/category/retete-bebelusi-7-luni-pranz/", minAgeMonths: 7),
                .init(label: "Breakfast, 7 months", url: "https://flaveur.ro/category/retete-bebelusi-7-luni-mic-dejun/", minAgeMonths: 7),
                .init(label: "Lunch, 8 months+",    url: "https://flaveur.ro/category/retete-bebelusi-8-luni-pranz/", minAgeMonths: 8),
                .init(label: "Dinner, 8 months+",   url: "https://flaveur.ro/category/retete-bebelusi-8-luni-cina/", minAgeMonths: 8),
                .init(label: "Dairy-free",          url: "https://flaveur.ro/category/retete-fara-lactate/", tag: "CMPA"),
                .init(label: "Egg-free",            url: "https://flaveur.ro/category/retete-fara-ou/", tag: "CMPA"),
                .init(label: "For constipation",    url: "https://flaveur.ro/category/retete-pentru-tratarea-constipatiei/"),
                .init(label: "Weekly menus",        url: "https://flaveur.ro/category/meniuri-saptamanale-8-luni/", minAgeMonths: 8),
            ]
        )
    ]
}
