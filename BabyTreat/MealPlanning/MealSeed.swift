import Foundation
import SwiftData

/// First-run seed, ported from `design/baby-meal-planner.html` and translated to
/// English (D-10). Food **IDs stay in Romanian** — they are opaque keys that
/// recipes, menu entries and the rule engine reference, so renaming them would
/// break every cross-reference for no gain.
///
/// This is the data recovered from the *Meal Planning Reference v1.0* document —
/// treat it as the record until that document is re-imported (OQ-1).
enum MealSeed {

    /// `yyyy-MM-dd` in the current calendar, at start of day.
    static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = MealRules.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string) ?? .now
    }

    // MARK: - Baby

    static let birthDate = date("2025-12-23")
    static let formula = "Töpfer HA 1"
    static let dairyHoldUntil = date("2026-08-23")

    // Category names. Referenced by `Food.kind`'s fallback and by the Foods tab's
    // section order — change them in all three places or not at all.
    static let categoryVegetables = "Vegetables"
    static let categoryFruit      = "Fruit"
    static let categoryGrains     = "Grains"
    static let categoryProtein    = "Protein"
    static let categoryFats       = "Fats"
    static let categoryPlanned    = "Planned"

    /// Baseline last-exposure dates, used until the journal has entries of its own.
    static let allergenBaselines: [String: Date] = [
        "ou":      date("2026-07-22"),
        "arahide": date("2026-07-21"),
        "somon":   date("2026-07-21"),
    ]

    // MARK: - Foods

    static func foods() -> [Food] {
        [
            // ---- Vegetables ----
            Food(id: "dovlecel",  name: "Zucchini",     category: categoryVegetables, colorHex: "#7FA65C", status: .accepted, rating: 4, groups: [.veg]),
            Food(id: "broccoli",  name: "Broccoli",     category: categoryVegetables, colorHex: "#4E7A3A", status: .accepted, rating: 4, groups: [.veg]),
            Food(id: "cartofd",   name: "Sweet potato", category: categoryVegetables, colorHex: "#D97A34", status: .accepted, rating: 5, groups: [.veg, .amidon]),
            Food(id: "cartof",    name: "White potato", category: categoryVegetables, colorHex: "#E3D2AE", status: .accepted, rating: 4, groups: [.amidon]),
            Food(id: "pastarnac", name: "Parsnip",      category: categoryVegetables, colorHex: "#EADCBE", status: .accepted, rating: 3, groups: [.veg, .amidon]),
            Food(id: "radpatr",   name: "Parsley root", category: categoryVegetables, colorHex: "#E0D4B4", status: .accepted, rating: 3, groups: [.veg]),
            Food(id: "telina",    name: "Celeriac",     category: categoryVegetables, colorHex: "#E8E0C8", status: .accepted, rating: 3, groups: [.veg]),
            Food(id: "ardei",     name: "Bell pepper",  category: categoryVegetables, colorHex: "#D6462F", status: .accepted, rating: 3, groups: [.veg]),
            Food(id: "usturoi",   name: "Garlic",       category: categoryVegetables, colorHex: "#EDE6DC", status: .accepted, rating: 3, groups: [.veg]),

            // ---- Fruit ----
            Food(id: "mar",      name: "Apple",       category: categoryFruit, colorHex: "#C24C4C", status: .accepted, rating: 5, groups: [.fruct]),
            Food(id: "para",     name: "Pear",        category: categoryFruit, colorHex: "#BFC96F", status: .accepted, rating: 5, groups: [.fruct]),
            Food(id: "banana",   name: "Banana",      category: categoryFruit, colorHex: "#EFCF6B", status: .accepted, rating: 5, groups: [.fruct, .amidon]),
            Food(id: "afine",    name: "Blueberries", category: categoryFruit, colorHex: "#4B4A8C", status: .accepted, rating: 4, groups: [.fruct]),
            Food(id: "piersica", name: "Peach",       category: categoryFruit, colorHex: "#E9A05C", status: .accepted, rating: 4, groups: [.fruct]),
            Food(id: "pepene",   name: "Watermelon",  category: categoryFruit, colorHex: "#E0556B", status: .accepted, rating: 4, groups: [.fruct]),
            Food(id: "mango",    name: "Mango",       category: categoryFruit, colorHex: "#E9A93B", status: .weak,     rating: 1, groups: [.fruct],
                 triedOn: date("2026-07-23"), retryOn: date("2026-08-17"),
                 note: "First introduced 23 July — refused. Retry without pressure."),

            // ---- Grains ----
            Food(id: "ovaz", name: "Oats",        category: categoryGrains, colorHex: "#D9C7A3", status: .accepted, rating: 5, groups: [.amidon]),
            Food(id: "hipp", name: "HiPP cereal", category: categoryGrains, colorHex: "#C9B18C", status: .accepted, rating: 4, groups: [.amidon, .fier]),

            // ---- Protein ----
            Food(id: "ou",     name: "Egg",     category: categoryProtein, colorHex: "#F0C244", status: .accepted, rating: 4, groups: [.proteina, .asf, .grasime, .fier], isAllergen: true),
            Food(id: "pui",    name: "Chicken", category: categoryProtein, colorHex: "#E3C9A8", status: .accepted, rating: 4, groups: [.proteina, .asf, .fier]),
            Food(id: "curcan", name: "Turkey",  category: categoryProtein, colorHex: "#D9B893", status: .accepted, rating: 4, groups: [.proteina, .asf, .fier]),
            Food(id: "somon",  name: "Salmon",  category: categoryProtein, colorHex: "#E88060", status: .accepted, rating: 3, groups: [.proteina, .asf, .grasime, .omega3], isAllergen: true),
            Food(id: "linte",  name: "Lentils", category: categoryProtein, colorHex: "#A8763E", status: .weak,     rating: 2, groups: [.proteina, .amidon, .fier]),

            // ---- Fats ----
            Food(id: "avocado", name: "Avocado",       category: categoryFats, colorHex: "#6E8C3F", status: .accepted, rating: 4, groups: [.veg, .grasime]),
            Food(id: "arahide", name: "Peanut butter", category: categoryFats, colorHex: "#B57A3C", status: .accepted, rating: 4, groups: [.grasime, .proteina], isAllergen: true),

            // ---- Planned ----
            Food(id: "vita", name: "Beef", category: categoryPlanned, colorHex: "#8C3A32", status: .planned,
                 kind: .proteina, groups: [.proteina, .asf, .fier], isPriority: true,
                 note: "Cleared by the doctor on 24 July. First portion: Monday 27 July."),
            Food(id: "conopida",    name: "Cauliflower", category: categoryPlanned, colorHex: "#EFEBE0", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9, 10, 11], isPriority: true),
            Food(id: "mazare",      name: "Peas",        category: categoryPlanned, colorHex: "#7BA05B", status: .planned, kind: .veg, groups: [.veg, .proteina], season: [5, 6, 7]),
            Food(id: "dovleac",     name: "Pumpkin",     category: categoryPlanned, colorHex: "#E08A2E", status: .planned, kind: .veg, groups: [.veg], season: [9, 10, 11, 12]),
            Food(id: "fasoleverde", name: "Green beans", category: categoryPlanned, colorHex: "#6E9B4E", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9]),
            Food(id: "spanac",      name: "Spinach",     category: categoryPlanned, colorHex: "#3F6B34", status: .planned, kind: .veg, groups: [.veg, .fier], season: [3, 4, 5, 9, 10, 11]),
            Food(id: "morcov",      name: "Carrot",      category: categoryPlanned, colorHex: "#E07B2A", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9, 10, 11], isPriority: true),
            Food(id: "sfecla",      name: "Beetroot",    category: categoryPlanned, colorHex: "#8E2547", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9, 10, 11]),
            Food(id: "gulie",       name: "Kohlrabi",    category: categoryPlanned, colorHex: "#BFCBA8", status: .planned, kind: .veg, groups: [.veg], season: [5, 6, 7, 8, 9]),
            Food(id: "rosii",       name: "Tomatoes",    category: categoryPlanned, colorHex: "#CC3A28", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9],
                 note: "Acidic — can irritate the skin around the mouth. Many sources defer these to 9–10 months."),
            Food(id: "vinete",      name: "Aubergine",   category: categoryPlanned, colorHex: "#5B3A63", status: .planned, kind: .veg, groups: [.veg], season: [7, 8, 9],
                 note: "Peel and cook well. Usually after 8–10 months."),

            Food(id: "caisa",     name: "Apricot",      category: categoryPlanned, colorHex: "#E8A24F", status: .planned, kind: .fruct, groups: [.fruct], season: [6, 7]),
            Food(id: "kiwi",      name: "Kiwi",         category: categoryPlanned, colorHex: "#8FA83E", status: .planned, kind: .fruct, groups: [.fruct], season: [11, 12, 1, 2, 3]),
            Food(id: "capsuni",   name: "Strawberries", category: categoryPlanned, colorHex: "#D2374C", status: .planned, kind: .fruct, groups: [.fruct], season: [5, 6]),
            Food(id: "prune",     name: "Plums",        category: categoryPlanned, colorHex: "#5C3B6E", status: .planned, kind: .fruct, groups: [.fruct], season: [7, 8, 9], isPriority: true,
                 note: "Laxative effect — useful for constipation, but start with a small portion."),
            Food(id: "nectarine", name: "Nectarines",   category: categoryPlanned, colorHex: "#E8823F", status: .planned, kind: .fruct, groups: [.fruct], season: [7, 8, 9]),
            Food(id: "pepeneg",   name: "Cantaloupe",   category: categoryPlanned, colorHex: "#EFC46A", status: .planned, kind: .fruct, groups: [.fruct], season: [7, 8, 9]),
            Food(id: "zmeura",    name: "Raspberries",  category: categoryPlanned, colorHex: "#C7325A", status: .planned, kind: .fruct, groups: [.fruct], season: [6, 7, 8]),
            Food(id: "mure",      name: "Blackberries", category: categoryPlanned, colorHex: "#3B2A52", status: .planned, kind: .fruct, groups: [.fruct], season: [7, 8, 9]),

            // Dairy stays out of suggestions until the APLV question is settled.
            Food(id: "iaurt",  name: "Yogurt",         category: categoryPlanned, colorHex: "#F2EEE4", status: .planned, kind: .proteina, groups: [.asf, .proteina, .lactate], holdUntil: dairyHoldUntil),
            Food(id: "branza", name: "Cottage cheese", category: categoryPlanned, colorHex: "#F5F1E6", status: .planned, kind: .proteina, groups: [.asf, .proteina, .lactate], holdUntil: dairyHoldUntil),

            Food(id: "naut",   name: "Chickpeas", category: categoryPlanned, colorHex: "#D7B57E", status: .planned, kind: .proteina, groups: [.proteina, .amidon, .fier]),
            Food(id: "quinoa", name: "Quinoa",    category: categoryPlanned, colorHex: "#D6C9A8", status: .planned, kind: .cereale,  groups: [.amidon, .proteina]),
            Food(id: "mei",    name: "Millet",    category: categoryPlanned, colorHex: "#E0CFA0", status: .planned, kind: .cereale,  groups: [.amidon]),
        ]
    }

    // MARK: - Recipes

    static func recipes() -> [Recipe] {
        [
            Recipe(
                id: "r1", title: "Oat porridge with pear and carob", minAgeMonths: 6,
                foodIDs: ["ovaz", "para"],
                ingredients: ["3 tbsp fine oat flakes", "150 ml water (or coconut milk)", "1/2 ripe pear", "1 tsp carob"],
                steps: ["Simmer the oats in water 5–6 min, stirring.", "Grate the pear and add it at the end, off the heat.", "Sprinkle the carob and stir through."],
                spoonNote: "Creamy, slightly thick — takes well on a spoon.",
                blwNote: "Thick slices of raw, well-ripened pear alongside, held in the hand.",
                freezeNote: "Yes — 60 ml portions, up to 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["fibre", "plant iron", "calcium"], rating: 5
            ),
            Recipe(
                id: "r2", title: "Salmon with broccoli and potato", minAgeMonths: 6, proteinFoodID: "somon",
                foodIDs: ["somon", "broccoli", "cartof"],
                ingredients: ["40 g skinless salmon fillet", "2 broccoli florets", "1 small potato", "1 tsp olive oil"],
                steps: ["Steam everything 12–14 min.", "Check the salmon for bones, then flake it.", "Mash the potato and mix with the oil."],
                spoonNote: "Potato mash with flaked salmon, broccoli puréed on top.",
                blwNote: "Whole broccoli floret with the stalk left on as a natural handle, plus a potato baton.",
                freezeNote: "Yes, but the purée only — 1 month.", storeNote: "Fridge 24h (fish).",
                nutrients: ["omega-3", "protein", "vitamin C"], allergens: ["fish"], rating: 3
            ),
            Recipe(
                id: "r3", title: "Turkey with zucchini and potato", minAgeMonths: 6, proteinFoodID: "curcan",
                foodIDs: ["curcan", "dovlecel", "cartof"],
                ingredients: ["40 g turkey breast", "1/2 small zucchini", "1 small potato", "1 tsp olive oil"],
                steps: ["Simmer the turkey 20 min on low.", "Add the vegetables for the last 10 min.", "Purée with 2–3 tbsp of the broth."],
                spoonNote: "Fine purée, thinned with the cooking liquid.",
                blwNote: "Finger-thick strips of turkey plus batons of cooked zucchini.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["iron", "protein", "potassium"], rating: 4
            ),
            Recipe(
                id: "r4", title: "Beef with broccoli and sweet potato", minAgeMonths: 7, proteinFoodID: "vita",
                foodIDs: ["vita", "broccoli", "cartofd"],
                ingredients: ["40 g beef leg", "2 broccoli florets", "1/2 sweet potato", "1 tsp olive oil"],
                steps: ["Braise the beef 45–50 min, until it falls apart.", "Add the vegetables for the last 12 min.", "Purée, or chop very finely."],
                spoonNote: "Sweet potato mash with very finely chopped beef.",
                blwNote: "A long-braised strip of beef that shreds in the mouth, plus a sweet potato baton.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["heme iron", "zinc", "vitamin C", "beta-carotene"], rating: 0
            ),
            Recipe(
                id: "r5", title: "Fluffy egg with avocado", minAgeMonths: 6, proteinFoodID: "ou",
                foodIDs: ["ou", "avocado"],
                ingredients: ["1 whole egg", "1 tsp olive oil", "1/4 ripe avocado"],
                steps: ["Beat the egg and cook it on low until completely set.", "Mash the avocado separately.", "Serve them side by side, not mixed."],
                spoonNote: "Mashed avocado with small pieces of egg.",
                blwNote: "Omelette cut into 2 cm strips — holds very well in a fist.",
                freezeNote: "No.", storeNote: "Eat the same day.",
                nutrients: ["choline", "protein", "healthy fats"], allergens: ["egg"], rating: 4
            ),
            Recipe(
                id: "r6", title: "Oats with banana and peanut butter", minAgeMonths: 6, proteinFoodID: "arahide",
                foodIDs: ["ovaz", "banana", "arahide"],
                ingredients: ["3 tbsp oat flakes", "150 ml water", "1/2 banana", "1 level tsp 100% peanut butter"],
                steps: ["Simmer the oats 5–6 min.", "Mash the banana and add it.", "Dissolve the peanut butter into the warm porridge — never in lumps."],
                spoonNote: "Creamy; thin with a little water if it goes too thick.",
                blwNote: "Half a banana with the peel left on at the base, as a handle.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["fibre", "healthy fats", "magnesium"], allergens: ["peanut"], rating: 5
            ),
            Recipe(
                id: "r7", title: "Lentils with sweet potato and zucchini", minAgeMonths: 6, proteinFoodID: "linte",
                foodIDs: ["linte", "cartofd", "dovlecel"],
                ingredients: ["2 tbsp red lentils", "1/2 sweet potato", "1/2 small zucchini", "1 tsp olive oil"],
                steps: ["Rinse the lentils well and simmer 15 min.", "Add the diced vegetables for another 10 min.", "Purée partially — texture with some body."],
                spoonNote: "Thick orange purée.",
                blwNote: "Small patties can be pressed from the cooled mixture.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["plant iron", "fibre", "protein"],
                flag: "Weak acceptance so far — retry without pressure.", rating: 2
            ),
            Recipe(
                id: "r8", title: "Oat porridge with coconut milk", minAgeMonths: 6,
                foodIDs: ["ovaz"],
                ingredients: ["3 tbsp fine oat flakes", "100 ml coconut milk + 50 ml water", "1 ripe fruit (pear, apricot, banana)", "1 tsp carob (optional)"],
                steps: ["Simmer the oats in the coconut and water mix, 5–6 min, on low.", "Off the heat, add the grated or mashed fruit.", "If using carob, sprinkle it now and stir through."],
                spoonNote: "Creamier than the water version — thin with water if too thick.",
                blwNote: "Thick slices of the same fruit alongside, held in the hand.",
                freezeNote: "Yes — 60 ml portions, up to 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["fibre", "healthy fats", "plant iron"],
                flag: "Coconut milk is used only in recipes, 1–2 times a week. Never as a replacement for formula.",
                rating: 0
            ),
        ]
    }

    // MARK: - Menu (three weeks seeded)

    private struct SeedEntry {
        let day: String
        let slot: MealSlot
        let dish: String
        let foodIDs: [String]
        var recipeID: String?
        var isNew: Bool = false
    }

    static func menu() -> [MenuEntry] {
        // Note: dishes that name an oil satisfy the lunch fat requirement — the
        // rule engine looks for "oil" in the dish name (see MealRules.lunchGaps).
        let seed: [SeedEntry] = [
            // ---- 20–26 July · current week · new food: mango (retry) ----
            .init(day: "2026-07-20", slot: .breakfast, dish: "Oats + peach", foodIDs: ["ovaz", "piersica"]),
            .init(day: "2026-07-20", slot: .lunch, dish: "Turkey + broccoli + white potato", foodIDs: ["curcan", "broccoli", "cartof"]),
            .init(day: "2026-07-21", slot: .breakfast, dish: "Oats + banana + peanut butter", foodIDs: ["ovaz", "banana", "arahide"], recipeID: "r6"),
            .init(day: "2026-07-21", slot: .lunch, dish: "Salmon + zucchini + sweet potato", foodIDs: ["somon", "dovlecel", "cartofd"]),
            .init(day: "2026-07-22", slot: .breakfast, dish: "HiPP cereal + blueberries", foodIDs: ["hipp", "afine"]),
            .init(day: "2026-07-22", slot: .lunch, dish: "Egg + avocado + broccoli", foodIDs: ["ou", "avocado", "broccoli"], recipeID: "r5"),
            .init(day: "2026-07-23", slot: .breakfast, dish: "Mango + oats", foodIDs: ["mango", "ovaz"], isNew: true),
            .init(day: "2026-07-23", slot: .lunch, dish: "Chicken + celeriac + white potato + bell pepper", foodIDs: ["pui", "telina", "cartof", "ardei"]),
            .init(day: "2026-07-24", slot: .breakfast, dish: "Oats + pear", foodIDs: ["ovaz", "para"]),
            .init(day: "2026-07-24", slot: .lunch, dish: "Turkey + zucchini + garlic", foodIDs: ["curcan", "dovlecel", "usturoi"]),
            .init(day: "2026-07-25", slot: .breakfast, dish: "HiPP cereal + watermelon", foodIDs: ["hipp", "pepene"]),
            .init(day: "2026-07-25", slot: .lunch, dish: "Lentils + chicken + sweet potato", foodIDs: ["linte", "pui", "cartofd"]),
            .init(day: "2026-07-26", slot: .breakfast, dish: "Oats + apple", foodIDs: ["ovaz", "mar"]),
            .init(day: "2026-07-26", slot: .lunch, dish: "Salmon + broccoli + white potato", foodIDs: ["somon", "broccoli", "cartof"], recipeID: "r2"),

            // ---- 27 July – 2 August · new vegetable: cauliflower · new fruit: apricot · new protein: beef
            //      Starch reduced: 3 of 7 lunches without potato or grain. ----
            .init(day: "2026-07-27", slot: .breakfast, dish: "Oat porridge with coconut milk + pear", foodIDs: ["ovaz", "para"], recipeID: "r8"),
            .init(day: "2026-07-27", slot: .lunch, dish: "Beef + broccoli + sweet potato + olive oil", foodIDs: ["vita", "broccoli", "cartofd"], recipeID: "r4", isNew: true),
            .init(day: "2026-07-28", slot: .breakfast, dish: "HiPP cereal + blueberries", foodIDs: ["hipp", "afine"]),
            .init(day: "2026-07-28", slot: .lunch, dish: "Salmon + zucchini + broccoli", foodIDs: ["somon", "dovlecel", "broccoli"]),
            .init(day: "2026-07-29", slot: .breakfast, dish: "Oats + banana + peanut butter", foodIDs: ["ovaz", "banana", "arahide"], recipeID: "r6"),
            .init(day: "2026-07-29", slot: .lunch, dish: "Turkey + cauliflower + sweet potato + olive oil", foodIDs: ["curcan", "conopida", "cartofd"], isNew: true),
            .init(day: "2026-07-30", slot: .breakfast, dish: "Oats + pear + carob", foodIDs: ["ovaz", "para"], recipeID: "r1"),
            .init(day: "2026-07-30", slot: .lunch, dish: "Egg + avocado + broccoli", foodIDs: ["ou", "avocado", "broccoli"], recipeID: "r5"),
            .init(day: "2026-07-31", slot: .breakfast, dish: "Oat porridge with coconut milk + apricot", foodIDs: ["ovaz", "caisa"], recipeID: "r8", isNew: true),
            .init(day: "2026-07-31", slot: .lunch, dish: "Chicken + celeriac + bell pepper + sweet potato + olive oil", foodIDs: ["pui", "telina", "ardei", "cartofd"]),
            .init(day: "2026-08-01", slot: .breakfast, dish: "HiPP cereal + apple", foodIDs: ["hipp", "mar"]),
            .init(day: "2026-08-01", slot: .lunch, dish: "Beef + cauliflower + zucchini + olive oil", foodIDs: ["vita", "conopida", "dovlecel"], recipeID: "r4"),
            .init(day: "2026-08-02", slot: .breakfast, dish: "HiPP cereal + carob + peach", foodIDs: ["hipp", "piersica"]),
            .init(day: "2026-08-02", slot: .lunch, dish: "Salmon + broccoli + sweet potato", foodIDs: ["somon", "broccoli", "cartofd"], recipeID: "r2"),
        ]

        return seed.map {
            MenuEntry(
                date: date($0.day),
                slot: $0.slot,
                dish: $0.dish,
                foodIDs: $0.foodIDs,
                recipeID: $0.recipeID,
                isNewFood: $0.isNew,
                calendar: MealRules.calendar
            )
        }
    }

    // MARK: - Shopping

    static let shoppingCategories = ["Vegetables", "Fruit", "Protein", "Pantry"]

    /// Typical amounts for a week, by food ID. A food with no hint falls back to
    /// the number of meals it appears in — better an honest "2 meals" than a
    /// made-up weight.
    static let quantityHints: [String: String] = [
        "broccoli": "3 heads", "dovlecel": "3", "cartof": "1 kg", "cartofd": "3",
        "telina": "1 root", "ardei": "1", "usturoi": "1 bulb", "avocado": "2",
        "piersica": "2", "banana": "3", "afine": "1 punnet", "mango": "1",
        "para": "2", "pepene": "1 slice", "mar": "2",
        "curcan": "250 g", "somon": "200 g", "pui": "250 g", "ou": "6",
        "linte": "1 bag", "vita": "250 g",
        "ovaz": "1 bag", "hipp": "1 box", "arahide": "1 jar",
    ]

    /// Recipe ingredients that are not modelled as foods, so the menu can never
    /// surface them. Always on the list.
    static let pantryStaples: [(name: String, quantity: String)] = [
        ("Olive oil", "—"),
        ("Coconut milk", "1 tin"),
    ]

    /// Which shopping section a food belongs under. Planned foods have no
    /// section of their own — a new vegetable is shopped for as a vegetable.
    static func shoppingCategory(for food: Food) -> String {
        switch food.category {
        case categoryVegetables: return "Vegetables"
        case categoryFruit:      return "Fruit"
        case categoryProtein:    return "Protein"
        case categoryGrains, categoryFats: return "Pantry"
        default: break
        }
        switch food.kind {
        case .veg:      return "Vegetables"
        case .fruct:    return "Fruit"
        case .proteina: return "Protein"
        default:        return "Pantry"
        }
    }

    /// Builds the week's list from the week's menu, so newly introduced foods —
    /// the whole point of planning ahead — are actually bought.
    static func shopping(weekStart: Date, menu: [MenuEntry], foodsByID: [String: Food]) -> [ShoppingItem] {
        var items = MealRules.foodsUsed(weekStart: weekStart, menu: menu).compactMap { used -> ShoppingItem? in
            guard let food = foodsByID[used.id] else { return nil }
            let quantity = quantityHints[food.id] ?? "\(used.meals) meal\(used.meals == 1 ? "" : "s")"
            return ShoppingItem(
                category: shoppingCategory(for: food),
                name: food.name,
                quantity: quantity,
                weekStart: weekStart,
                foodID: food.id,
                calendar: MealRules.calendar
            )
        }

        items += pantryStaples.map {
            ShoppingItem(category: "Pantry", name: $0.name, quantity: $0.quantity,
                         weekStart: weekStart, calendar: MealRules.calendar)
        }
        return items
    }

    // MARK: - Install

    /// Bump when the seed content changes in a way that should reach devices
    /// that already installed an older seed. v1 was the Romanian port; v2 is the
    /// English translation (D-10).
    static let version = 2
    private static let versionKey = "mealSeedVersion"

    /// Installs the seed on first run, and reinstalls it when `version` moves.
    ///
    /// A reinstall **replaces** foods, recipes, menu and shopping list — so
    /// status and rating edits made against the old seed are lost. `MealLog` is
    /// deliberately left alone: the journal is the caregiver's own record, and it
    /// re-associates by date and slot.
    @MainActor
    static func installIfNeeded(in context: ModelContext) {
        let installed = UserDefaults.standard.integer(forKey: versionKey)
        let foodCount = (try? context.fetchCount(FetchDescriptor<Food>())) ?? 0
        guard foodCount == 0 || installed < version else { return }

        if foodCount > 0 {
            try? context.delete(model: Food.self)
            try? context.delete(model: Recipe.self)
            try? context.delete(model: MenuEntry.self)
            try? context.delete(model: ShoppingItem.self)
        }

        let seedFoods = foods()
        let seedMenu = menu()
        seedFoods.forEach { context.insert($0) }
        recipes().forEach { context.insert($0) }
        seedMenu.forEach { context.insert($0) }

        let byID = Dictionary(seedFoods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        shopping(weekStart: MealRules.planningWeekStart(for: .now), menu: seedMenu, foodsByID: byID)
            .forEach { context.insert($0) }

        try? context.save()
        UserDefaults.standard.set(version, forKey: versionKey)
    }
}
