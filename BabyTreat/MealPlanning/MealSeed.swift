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
            Food(id: "dovlecel",  name: "Zucchini",     category: categoryVegetables, colorHex: "#7FA65C", status: .accepted, rating: 4, groups: [.veg], nitrateRisk: .moderate),
            Food(id: "broccoli",  name: "Broccoli",     category: categoryVegetables, colorHex: "#4E7A3A", status: .accepted, rating: 4, groups: [.veg]),
            Food(id: "cartofd",   name: "Sweet potato", category: categoryVegetables, colorHex: "#D97A34", status: .accepted, rating: 5, groups: [.veg, .amidon]),
            Food(id: "cartof",    name: "White potato", category: categoryVegetables, colorHex: "#E3D2AE", status: .accepted, rating: 4, groups: [.amidon], nitrateRisk: .low),
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
            Food(id: "ou",     name: "Egg",     category: categoryProtein, colorHex: "#F0C244", status: .accepted, rating: 4, groups: [.proteina, .asf, .grasime, .fier], isAllergen: true, family: .egg),
            Food(id: "pui",    name: "Chicken", category: categoryProtein, colorHex: "#E3C9A8", status: .accepted, rating: 4, groups: [.proteina, .asf, .fier]),
            Food(id: "curcan", name: "Turkey",  category: categoryProtein, colorHex: "#D9B893", status: .accepted, rating: 4, groups: [.proteina, .asf, .fier]),
            Food(id: "somon",  name: "Salmon",  category: categoryProtein, colorHex: "#E88060", status: .accepted, rating: 3, groups: [.proteina, .asf, .grasime, .omega3], isAllergen: true, family: .fish),
            Food(id: "linte",  name: "Lentils", category: categoryProtein, colorHex: "#A8763E", status: .weak,     rating: 2, groups: [.proteina, .amidon, .fier], family: .legume),

            // ---- Fats ----
            Food(id: "avocado", name: "Avocado",       category: categoryFats, colorHex: "#6E8C3F", status: .accepted, rating: 4, groups: [.veg, .grasime]),
            Food(id: "arahide", name: "Peanut butter", category: categoryFats, colorHex: "#B57A3C", status: .accepted, rating: 4, groups: [.grasime, .proteina], isAllergen: true, family: .peanut),

            // ---- Planned ----
            Food(id: "vita", name: "Beef", category: categoryPlanned, colorHex: "#8C3A32", status: .planned,
                 kind: .proteina, groups: [.proteina, .asf, .fier], isPriority: true,
                 note: "Cleared by the doctor on 24 July. First portion: Monday 27 July."),
            Food(id: "conopida",    name: "Cauliflower", category: categoryPlanned, colorHex: "#EFEBE0", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9, 10, 11], isPriority: true),
            Food(id: "mazare",      name: "Peas",        category: categoryPlanned, colorHex: "#7BA05B", status: .planned, kind: .veg, groups: [.veg, .proteina], season: [5, 6, 7], family: .legume),
            Food(id: "dovleac",     name: "Pumpkin",     category: categoryPlanned, colorHex: "#E08A2E", status: .planned, kind: .veg, groups: [.veg], season: [9, 10, 11, 12], nitrateRisk: .moderate),
            Food(id: "fasoleverde", name: "Green beans", category: categoryPlanned, colorHex: "#6E9B4E", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9], nitrateRisk: .moderate),
            Food(id: "spanac",      name: "Spinach",     category: categoryPlanned, colorHex: "#3F6B34", status: .planned, kind: .veg, groups: [.veg, .fier], season: [3, 4, 5, 9, 10, 11], nitrateRisk: .high),
            Food(id: "morcov",      name: "Carrot",      category: categoryPlanned, colorHex: "#E07B2A", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9, 10, 11], isPriority: true, nitrateRisk: .moderate),
            Food(id: "sfecla",      name: "Beetroot",    category: categoryPlanned, colorHex: "#8E2547", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9, 10, 11], nitrateRisk: .high),
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
            Food(id: "iaurt",  name: "Yogurt",         category: categoryPlanned, colorHex: "#F2EEE4", status: .planned, kind: .proteina, groups: [.asf, .proteina, .lactate], family: .dairy, holdUntil: dairyHoldUntil),
            Food(id: "branza", name: "Cottage cheese", category: categoryPlanned, colorHex: "#F5F1E6", status: .planned, kind: .proteina, groups: [.asf, .proteina, .lactate], family: .dairy, holdUntil: dairyHoldUntil),

            Food(id: "naut",   name: "Chickpeas", category: categoryPlanned, colorHex: "#D7B57E", status: .planned, kind: .proteina, groups: [.proteina, .amidon, .fier], family: .legume),
            Food(id: "quinoa", name: "Quinoa",    category: categoryPlanned, colorHex: "#D6C9A8", status: .planned, kind: .cereale,  groups: [.amidon, .proteina]),
            Food(id: "mei",    name: "Millet",    category: categoryPlanned, colorHex: "#E0CFA0", status: .planned, kind: .cereale,  groups: [.amidon]),

            // ---- More vegetables to introduce ----
            // Seasons are Romanian. Nitrate tags matter for batch storage only
            // (D-20) — fennel and chard are the two the case series is about.
            Food(id: "praz",       name: "Leek",             category: categoryPlanned, colorHex: "#9CBF6A", status: .planned, kind: .veg, groups: [.veg], season: [9, 10, 11, 12, 1, 2, 3], nitrateRisk: .moderate),
            Food(id: "ceapa",      name: "Onion",            category: categoryPlanned, colorHex: "#E4D9C0", status: .planned, kind: .veg, groups: [.veg], nitrateRisk: .low),
            Food(id: "varza",      name: "Cabbage",          category: categoryPlanned, colorHex: "#C8DBB0", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9, 10, 11], nitrateRisk: .moderate),
            Food(id: "varzabr",    name: "Brussels sprouts", category: categoryPlanned, colorHex: "#7FA35A", status: .planned, kind: .veg, groups: [.veg], season: [9, 10, 11, 12], nitrateRisk: .moderate),
            Food(id: "sparanghel", name: "Asparagus",        category: categoryPlanned, colorHex: "#7FA86B", status: .planned, kind: .veg, groups: [.veg], season: [4, 5, 6], nitrateRisk: .moderate),
            Food(id: "castravete", name: "Cucumber",         category: categoryPlanned, colorHex: "#A9CE7E", status: .planned, kind: .veg, groups: [.veg], season: [5, 6, 7, 8, 9], nitrateRisk: .moderate),
            Food(id: "nap",        name: "Turnip",           category: categoryPlanned, colorHex: "#E6DCC6", status: .planned, kind: .veg, groups: [.veg], season: [9, 10, 11, 12], nitrateRisk: .moderate),
            Food(id: "porumb",     name: "Sweetcorn",        category: categoryPlanned, colorHex: "#F2CE5B", status: .planned, kind: .veg, groups: [.veg, .amidon], season: [7, 8, 9], nitrateRisk: .low),
            Food(id: "fenicul",    name: "Fennel",           category: categoryPlanned, colorHex: "#DCE7C4", status: .planned, kind: .veg, groups: [.veg], season: [6, 7, 8, 9, 10], nitrateRisk: .high,
                 note: "High nitrate — fine to serve, but a batch containing it is a single day only."),
            Food(id: "mangold",    name: "Swiss chard",      category: categoryPlanned, colorHex: "#4F7F3E", status: .planned, kind: .veg, groups: [.veg, .fier], season: [5, 6, 7, 8, 9, 10], nitrateRisk: .high,
                 note: "High nitrate — cook fresh and serve the same day."),

            // ---- More fruit to introduce ----
            Food(id: "cirese",     name: "Cherries",     category: categoryPlanned, colorHex: "#A32335", status: .planned, kind: .fruct, groups: [.fruct], season: [5, 6, 7],
                 note: "Stone out, halved or mashed — a whole cherry is a choking risk."),
            Food(id: "struguri",   name: "Grapes",       category: categoryPlanned, colorHex: "#7B5EA7", status: .planned, kind: .fruct, groups: [.fruct], season: [8, 9, 10],
                 note: "Quartered lengthways, never whole or halved crossways."),
            Food(id: "portocala",  name: "Orange",       category: categoryPlanned, colorHex: "#EE8B21", status: .planned, kind: .fruct, groups: [.fruct], season: [11, 12, 1, 2, 3]),
            Food(id: "mandarine",  name: "Clementines",  category: categoryPlanned, colorHex: "#F09A35", status: .planned, kind: .fruct, groups: [.fruct], season: [11, 12, 1, 2]),
            Food(id: "ananas",     name: "Pineapple",    category: categoryPlanned, colorHex: "#EFC03F", status: .planned, kind: .fruct, groups: [.fruct]),
            Food(id: "gutui",      name: "Quince",       category: categoryPlanned, colorHex: "#E3C75F", status: .planned, kind: .fruct, groups: [.fruct], season: [9, 10, 11],
                 note: "Always cooked — raw quince is hard and astringent."),
            Food(id: "smochine",   name: "Figs",         category: categoryPlanned, colorHex: "#8E6A9B", status: .planned, kind: .fruct, groups: [.fruct], season: [8, 9]),
            Food(id: "coacaze",    name: "Blackcurrants",category: categoryPlanned, colorHex: "#3D2A55", status: .planned, kind: .fruct, groups: [.fruct], season: [6, 7, 8],
                 note: "Mashed — the skins are tough on their own."),
            Food(id: "papaya",     name: "Papaya",       category: categoryPlanned, colorHex: "#F2934E", status: .planned, kind: .fruct, groups: [.fruct]),
        ] + accents()
    }

    /// The accent tier: flavour and fat carriers, plus the additives that hide
    /// inside formula and packaged food.
    ///
    /// None of these consume a rotation slot — they are logged, timestamped and
    /// attributable, but counting a teaspoon of oil as an exposure would fill
    /// the rotation meter with things that were never the point.
    static func accents() -> [Food] {
        [
            // Two entries, not one. Canned is roughly 180–230 kcal/100 g and
            // carton roughly 20–40 — a single row would make the calorie maths
            // wrong by about a factor of six.
            Food(id: "coconutcan", name: "Coconut milk, canned", category: categoryFats, colorHex: "#F3EFE7",
                 status: .accepted, rating: 3, kind: .grasime, groups: [.grasime],
                 role: .accent, family: .arecaceae, minAgeMonths: 6, drinkBlockedUnderMonths: 12,
                 note: "~180–230 kcal/100 g, high in saturated fat, often contains carrageenan. Cooking only."),
            Food(id: "coconutbox", name: "Coconut milk, carton", category: categoryFats, colorHex: "#F7F4EE",
                 status: .accepted, rating: 3, kind: .grasime, groups: [.grasime],
                 role: .accent, family: .arecaceae, minAgeMonths: 6, drinkBlockedUnderMonths: 12,
                 note: "~20–40 kcal/100 g, diluted, usually fortified and often thickened. Cooking only."),

            // Legume by family — for diversity scoring only. Studies find little
            // cross-reactivity between legume members and specifically none
            // between carob and peanut, so this must never gate on a peanut flag.
            Food(id: "roscove", name: "Carob powder", category: categoryFats, colorHex: "#7A5230",
                 status: .accepted, rating: 4, kind: .altul, groups: [],
                 role: .accent, family: .legume, minAgeMonths: 6,
                 note: "Caffeine- and theobromine-free cocoa substitute."),

            // Its own row because a case exists of an infant reacting to an
            // anti-regurgitation formula containing it. A background exposure
            // nobody chose still has to be visible to the attribution engine.
            Food(id: "e410", name: "Carob bean gum (E410)", category: categoryFats, colorHex: "#C9BBA6",
                 status: .accepted, rating: 0, kind: .altul, groups: [],
                 role: .additive, family: .legume,
                 note: "Thickener in AR formulas and packaged foods. Logged so it can be a candidate."),

            Food(id: "uleimasline", name: "Olive oil", category: categoryFats, colorHex: "#8A9A3B",
                 status: .accepted, rating: 5, kind: .grasime, groups: [.grasime],
                 role: .accent, family: .none, minAgeMonths: 6),
            Food(id: "unt", name: "Butter", category: categoryFats, colorHex: "#F2D98B",
                 status: .planned, rating: 0, kind: .grasime, groups: [.grasime, .lactate],
                 role: .accent, family: .dairy, minAgeMonths: 6, holdUntil: dairyHoldUntil),
            Food(id: "tahini", name: "Tahini", category: categoryFats, colorHex: "#D8C79B",
                 status: .planned, rating: 0, kind: .grasime, groups: [.grasime, .proteina],
                 isAllergen: true, role: .accent, family: .sesame, minAgeMonths: 6),
            Food(id: "scortisoara", name: "Cinnamon", category: categoryFats, colorHex: "#A9603A",
                 status: .accepted, rating: 3, kind: .altul, groups: [],
                 role: .accent, family: .none, minAgeMonths: 6),
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
                nutrients: ["fibre", "plant iron", "calcium"], rating: 5, form: .puree
            ),
            Recipe(
                id: "r2", title: "Salmon with broccoli and potato", minAgeMonths: 6, proteinFoodID: "somon",
                foodIDs: ["somon", "broccoli", "cartof"],
                ingredients: ["40 g skinless salmon fillet", "2 broccoli florets", "1 small potato", "1 tsp olive oil"],
                steps: ["Steam everything 12–14 min.", "Check the salmon for bones, then flake it.", "Mash the potato and mix with the oil."],
                spoonNote: "Potato mash with flaked salmon, broccoli puréed on top.",
                blwNote: "Whole broccoli floret with the stalk left on as a natural handle, plus a potato baton.",
                freezeNote: "Yes, but the purée only — 1 month.", storeNote: "Fridge 24h (fish).",
                nutrients: ["omega-3", "protein", "vitamin C"], allergens: ["fish"], rating: 3, form: .mashed
            ),
            Recipe(
                id: "r3", title: "Turkey with zucchini and potato", minAgeMonths: 6, proteinFoodID: "curcan",
                foodIDs: ["curcan", "dovlecel", "cartof"],
                ingredients: ["40 g turkey breast", "1/2 small zucchini", "1 small potato", "1 tsp olive oil"],
                steps: ["Simmer the turkey 20 min on low.", "Add the vegetables for the last 10 min.", "Purée with 2–3 tbsp of the broth."],
                spoonNote: "Fine purée, thinned with the cooking liquid.",
                blwNote: "Finger-thick strips of turkey plus batons of cooked zucchini.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["iron", "protein", "potassium"], rating: 4, form: .puree
            ),
            Recipe(
                id: "r4", title: "Beef with broccoli and sweet potato", minAgeMonths: 7, proteinFoodID: "vita",
                foodIDs: ["vita", "broccoli", "cartofd"],
                ingredients: ["40 g beef leg", "2 broccoli florets", "1/2 sweet potato", "1 tsp olive oil"],
                steps: ["Braise the beef 45–50 min, until it falls apart.", "Add the vegetables for the last 12 min.", "Purée, or chop very finely."],
                spoonNote: "Sweet potato mash with very finely chopped beef.",
                blwNote: "A long-braised strip of beef that shreds in the mouth, plus a sweet potato baton.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["heme iron", "zinc", "vitamin C", "beta-carotene"], rating: 0, form: .mashed
            ),
            Recipe(
                id: "r5", title: "Fluffy egg with avocado", minAgeMonths: 6, proteinFoodID: "ou",
                foodIDs: ["ou", "avocado"],
                ingredients: ["1 whole egg", "1 tsp olive oil", "1/4 ripe avocado"],
                steps: ["Beat the egg and cook it on low until completely set.", "Mash the avocado separately.", "Serve them side by side, not mixed."],
                spoonNote: "Mashed avocado with small pieces of egg.",
                blwNote: "Omelette cut into 2 cm strips — holds very well in a fist.",
                freezeNote: "No.", storeNote: "Eat the same day.",
                nutrients: ["choline", "protein", "healthy fats"], allergens: ["egg"], rating: 4, form: .fingerFood
            ),
            Recipe(
                id: "r6", title: "Oats with banana and peanut butter", minAgeMonths: 6, proteinFoodID: "arahide",
                foodIDs: ["ovaz", "banana", "arahide"],
                ingredients: ["3 tbsp oat flakes", "150 ml water", "1/2 banana", "1 level tsp 100% peanut butter"],
                steps: ["Simmer the oats 5–6 min.", "Mash the banana and add it.", "Dissolve the peanut butter into the warm porridge — never in lumps."],
                spoonNote: "Creamy; thin with a little water if it goes too thick.",
                blwNote: "Half a banana with the peel left on at the base, as a handle.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["fibre", "healthy fats", "magnesium"], allergens: ["peanut"], rating: 5, form: .puree
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
                flag: "Weak acceptance so far — retry without pressure.", rating: 2, form: .puree
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
                rating: 0, form: .puree
            ),

            // ---- Breakfasts ----
            // The oat porridges were doing all the work here. These widen the
            // grains, and two of them are finger food on purpose: dinner stays
            // liquid at month 8, so breakfast is where texture has to move.
            Recipe(
                id: "b1", title: "Millet porridge with apricot and cinnamon", minAgeMonths: 6,
                foodIDs: ["mei", "caisa"],
                ingredients: ["3 tbsp millet flakes", "150 ml water", "1 ripe apricot", "a pinch of cinnamon"],
                steps: ["Simmer the millet 8–10 min, stirring.", "Mash the apricot and stir it in off the heat.", "Dust with cinnamon."],
                spoonNote: "Softer than oats and a little sweeter.",
                blwNote: "Apricot halves alongside, skin off.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["plant iron", "magnesium", "beta-carotene"],
                rating: 0, form: .puree
            ),
            Recipe(
                id: "b2", title: "Quinoa porridge with pear", minAgeMonths: 6,
                foodIDs: ["quinoa", "para"],
                ingredients: ["3 tbsp quinoa flakes", "150 ml water", "1/2 ripe pear", "1 tsp tahini"],
                steps: ["Rinse the quinoa well, then simmer 10 min.", "Grate the pear in at the end.", "Stir the tahini through for fat and calcium."],
                spoonNote: "Thicker than oats — loosen with water.",
                blwNote: "Ripe pear slices in the hand.",
                freezeNote: "Yes — 1 month.", storeNote: "Fridge 48h.",
                nutrients: ["complete protein", "calcium", "fibre"], allergens: ["sesame"],
                rating: 0, form: .puree
            ),
            Recipe(
                id: "b3", title: "Banana and egg pancakes", minAgeMonths: 8, proteinFoodID: "ou",
                foodIDs: ["ou", "banana", "ovaz"],
                ingredients: ["1 ripe banana", "1 egg", "2 tbsp fine oat flakes", "a little butter for the pan"],
                steps: ["Mash the banana smooth and beat in the egg.", "Stir in the oats and let it sit 5 min.", "Cook small pancakes on low until set right through."],
                spoonNote: "Torn into pieces if the spoon is still the way in.",
                blwNote: "Perfect strips — holds together in a fist and takes real chewing.",
                freezeNote: "Yes, between sheets of paper — 1 month.", storeNote: "Fridge 24h.",
                nutrients: ["protein", "choline", "potassium"], allergens: ["egg"],
                rating: 0, form: .fingerFood
            ),
            Recipe(
                id: "b4", title: "Scrambled egg with tomato", minAgeMonths: 8, proteinFoodID: "ou",
                foodIDs: ["ou", "rosii", "uleimasline"],
                ingredients: ["1 egg", "1 small ripe tomato, skinned", "1 tsp olive oil"],
                steps: ["Soften the skinned, chopped tomato in the oil 3–4 min.", "Pour the beaten egg over and scramble on low.", "Cook until completely set, then cool."],
                spoonNote: "Chop the curds small.",
                blwNote: "Leave the curds large enough to pick up.",
                freezeNote: "No.", storeNote: "Eat the same day.",
                nutrients: ["protein", "lycopene", "vitamin C"], allergens: ["egg"],
                rating: 0, form: .mashed
            ),
            Recipe(
                id: "b5", title: "Oat fingers with apple and cinnamon", minAgeMonths: 8,
                foodIDs: ["ovaz", "mar"],
                ingredients: ["4 tbsp oat flakes", "1 apple, grated", "1 tbsp water", "a pinch of cinnamon"],
                steps: ["Mix everything into a stiff paste.", "Press flat on a lined tray, about 1 cm thick.", "Bake 20 min at 180 °C, then cut into fingers and cool."],
                spoonNote: "Crumble one into warm water for a quick porridge.",
                blwNote: "The point of the recipe — a firm finger that softens as it is chewed.",
                freezeNote: "Yes — 1 month.", storeNote: "Airtight, 3 days.",
                nutrients: ["fibre", "beta-glucan"],
                rating: 0, form: .fingerFood
            ),
            Recipe(
                id: "b6", title: "Yogurt with blueberries and carob", minAgeMonths: 8,
                foodIDs: ["iaurt", "afine"],
                ingredients: ["3 tbsp full-fat plain yogurt", "a small handful of blueberries", "1 tsp carob"],
                steps: ["Crush the blueberries so there are no whole ones left.", "Fold them through the yogurt.", "Stir the carob in."],
                spoonNote: "Cold and thick — good on a hot morning.",
                blwNote: "Loaded on a spoon the baby holds.",
                freezeNote: "No.", storeNote: "Eat the same day.",
                nutrients: ["calcium", "protein", "anthocyanins"], allergens: ["dairy"],
                flag: "Dairy. The CMPA question is still unconfirmed — check before this becomes a regular.",
                rating: 0, form: .puree
            ),

            // ---- Soups, for the month-8 dinner rule ----
            // The dinner filter matches `form == .soup` exactly, so these three
            // exist to give it something to rotate against. No dairy — the
            // 8-month gate is still closed.
            Recipe(
                id: "s1", title: "Carrot and potato soup", minAgeMonths: 6,
                foodIDs: ["morcov", "cartof", "uleimasline"],
                ingredients: ["1 medium carrot", "1 small potato", "250 ml water", "1 tsp olive oil"],
                steps: ["Simmer the diced carrot and potato in the water, 20 min, until soft.", "Blend with enough of the cooking liquid to make it spoonable.", "Stir the olive oil in off the heat."],
                spoonNote: "Thin and smooth — the plain soup, and the batch base.",
                blwNote: "Hold back a few soft carrot batons before blending.",
                freezeNote: "Yes — freeze the second day's portion straight after cooking.",
                storeNote: "Carrot is moderate-nitrate: day two goes in the freezer, not the fridge.",
                nutrients: ["beta-carotene", "potassium"],
                rating: 0, form: .soup
            ),
            Recipe(
                id: "s2", title: "Turkey, zucchini and parsnip soup", minAgeMonths: 8, proteinFoodID: "curcan",
                foodIDs: ["curcan", "dovlecel", "pastarnac", "uleimasline"],
                ingredients: ["40 g turkey breast", "1/2 small zucchini", "1/2 parsnip", "300 ml water", "1 tsp olive oil"],
                steps: ["Simmer the turkey 20 min on low, skimming.", "Add the diced vegetables for the last 10 min.", "Blend, loosening with the broth. Stir the oil in off the heat."],
                spoonNote: "Blend fully, or leave a little texture as the month goes on.",
                blwNote: "Keep back a strip of turkey and a zucchini baton.",
                freezeNote: "Yes — 1 month.",
                storeNote: "Zucchini is moderate-nitrate: day two goes in the freezer.",
                nutrients: ["iron", "protein", "potassium"],
                rating: 0, form: .soup
            ),
            Recipe(
                id: "s3", title: "Chicken and broccoli soup", minAgeMonths: 8, proteinFoodID: "pui",
                foodIDs: ["pui", "broccoli", "cartof", "uleimasline"],
                ingredients: ["40 g chicken breast", "2 broccoli florets", "1 small potato", "300 ml water", "1 tsp olive oil"],
                steps: ["Simmer the chicken 20 min on low.", "Add the potato for 10 min, then the broccoli for the last 6.", "Blend to the thickness you want and stir in the oil."],
                spoonNote: "Goes green and keeps well on a spoon.",
                blwNote: "A whole floret with the stalk on, as a handle.",
                freezeNote: "Yes — 1 month.",
                storeNote: "Fridge 24h, or freeze the second day's portion.",
                nutrients: ["protein", "vitamin C", "iron"],
                rating: 0, form: .soup
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
    /// Inserts foods the store does not have yet, and touches nothing else.
    ///
    /// Deliberately not a `version` bump: a reinstall wipes foods, menu and
    /// shopping list, taking every status and rating edit with it. Adding the
    /// accent tier is no reason to lose a month of acceptance history, so new
    /// foods arrive additively and existing rows are left exactly as they are.
    @MainActor
    @discardableResult
    static func installMissingFoods(in context: ModelContext) -> Int {
        let existing = Set(((try? context.fetch(FetchDescriptor<Food>())) ?? []).map(\.id))
        guard !existing.isEmpty else { return 0 }   // first run is handled by installIfNeeded

        let missing = foods().filter { !existing.contains($0.id) }
        guard !missing.isEmpty else { return 0 }
        missing.forEach { context.insert($0) }
        try? context.save()
        return missing.count
    }

    /// Fills in classification (`role`, `family`, age gates) on rows that predate
    /// those attributes. A store seeded before D-18 has them all nil, so diversity
    /// scoring would see a pantry with no botanical families in it at all.
    ///
    /// Writes only where the stored value is unset. `nil` means the row predates
    /// the attribute; the defaults — `.base` and `.none` — mean it was written by
    /// a build that had the attribute but not yet the tag, and since nothing in
    /// the app can set either one, a stored default carries no intent to protect.
    /// The recipe counterpart of `installMissingFoods`. Without it the soups
    /// added for the month-8 dinner rule would only ever appear on a fresh
    /// install, and the filter would have nothing to offer on an existing one.
    @MainActor
    @discardableResult
    static func installMissingRecipes(in context: ModelContext) -> Int {
        let existing = Set(((try? context.fetch(FetchDescriptor<Recipe>())) ?? []).map(\.id))
        guard !existing.isEmpty else { return 0 }   // first run is handled by installIfNeeded

        let missing = recipes().filter { !existing.contains($0.id) }
        guard !missing.isEmpty else { return 0 }
        missing.forEach { context.insert($0) }
        try? context.save()
        return missing.count
    }

    /// Fills in `form` on recipes that predate it. Only ever writes over nil —
    /// an untagged recipe is unknown, not assumed, and the dinner filter treats
    /// unknown as "not a soup".
    @MainActor
    @discardableResult
    static func backfillRecipeForms(in context: ModelContext) -> Int {
        let stored = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        guard !stored.isEmpty else { return 0 }

        let seeded = Dictionary(recipes().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var touched = 0
        for recipe in stored where recipe.formRaw == nil {
            guard let form = seeded[recipe.id]?.formRaw else { continue }
            recipe.formRaw = form
            touched += 1
        }
        guard touched > 0 else { return 0 }
        try? context.save()
        return touched
    }

    @MainActor
    @discardableResult
    static func backfillClassification(in context: ModelContext) -> Int {
        let stored = (try? context.fetch(FetchDescriptor<Food>())) ?? []
        guard !stored.isEmpty else { return 0 }

        let seeded = Dictionary(foods().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var touched = 0

        for food in stored {
            guard let template = seeded[food.id] else { continue }
            var changed = false

            if food.role == .base, template.role != .base {
                food.role = template.role
                changed = true
            }
            if food.family == .none, template.family != .none {
                food.family = template.family
                changed = true
            }
            if food.minAgeMonths == nil, let age = template.minAgeMonths {
                food.minAgeMonths = age
                changed = true
            }
            if food.drinkBlockedUnderMonths == nil, let months = template.drinkBlockedUnderMonths {
                food.drinkBlockedUnderMonths = months
                changed = true
            }
            // Unlike role and family, an unset nitrate risk really is nil —
            // `Food.init` only writes the raw value when one was given — so a
            // plain nil check is the whole test here.
            if food.nitrateRiskRaw == nil, let risk = template.nitrateRiskRaw {
                food.nitrateRiskRaw = risk
                changed = true
            }

            if changed { touched += 1 }
        }

        guard touched > 0 else { return 0 }
        try? context.save()
        return touched
    }

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
