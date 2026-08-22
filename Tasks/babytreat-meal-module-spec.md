# BabyTreat — Meal Timestamps, Reaction Attribution & Ingredient Roles

Work on the `feature/baby` branch. This is a **spec, not code** — implement it your way, but do not substitute or simplify the rules marked CRITICAL. If something conflicts with existing code, stop and ask before changing it.

Stack: SwiftUI + SwiftData, iOS 17, Tuist. New files go under `BabyTreat/Models/` and `BabyTreat/Services/` — Tuist's `sources: ["BabyTreat/**"]` glob picks them up automatically, no `Project.swift` change needed.

---

## Part 1 — MealLog model

New file `BabyTreat/Models/MealLog.swift`.

Fields:

| Field | Type | Rule |
|---|---|---|
| `eatenAt` | `Date` | When the food was actually eaten. User-editable. **Round to the minute on save.** |
| `loggedAt` | `Date` | `.now` at insert. Audit only — never edited, never shown as the meal time. |
| `timeZoneID` | `String` | `TimeZone.current.identifier` captured at save. |
| `slot` | `MealSlot` | Set explicitly by the user. |
| `foodIDs` | `[String]` | References into the food database. |
| `portion` | `Portion` | `full` / `half` / `fewSpoons` / `refused` |
| `notes` | `String` | Optional. |

`enum MealSlot: String, Codable { case breakfast, lunch, dinner, snack }`

CRITICAL — `slot` is **semantic and must never be derived from the clock**. A 10:30 lunch during travel is still `.lunch`. Do not write any helper that infers a slot from a timestamp, not even as a default. The picker may default to the last-used slot, never to a time-of-day guess.

Age gating (read `babyAgeMonths` from `@AppStorage`, already in `SettingsView`):
- `breakfast`, `lunch` — always available
- `dinner` — unlocks at 8 months
- `snack` — locked until 12 months

Locked slots render disabled with the unlock age as a caption, not hidden.

CRITICAL — `portion == .refused` still records a real `eatenAt`, but a refused meal does **not** count as allergen re-exposure and must be excluded from rotation counting. Taste refusal is not intolerance: a refused food stays in the suggestion pool and must never be auto-suppressed.

---

## Part 2 — ReactionLog model

New file `BabyTreat/Models/ReactionLog.swift`.

| Field | Type | Rule |
|---|---|---|
| `observedAt` | `Date` | Independent user-set timestamp. Minute precision. |
| `severity` | `Severity` | `dislike` / `mild` / `moderate` / `severe` |
| `symptoms` | `[String]` | Multi-select. |
| `notes` | `String` | Optional. |

CRITICAL — `ReactionLog` has **no relationship to `MealLog`**. Do not add a `meal` property, a foreign key, or an "attach to last meal" convenience. Auto-attaching to the most recent meal systematically blames dinner and is the single failure mode this design exists to prevent. Attribution is computed at read time only (Part 3).

`severity == .dislike` is a taste signal, not a reaction — exclude it from attribution scoring entirely.

---

## Part 3 — Attribution engine

New file `BabyTreat/Services/ReactionAttribution.swift`. Pure functions, no SwiftData writes.

For a given `ReactionLog`, find every `MealLog` whose `eatenAt` falls within 48 h before `observedAt` and assign each a weight from hours elapsed:

| Δt since `eatenAt` | Weight | Dominant mechanism |
|---|---|---|
| 0–2 h | 1.00 | IgE-mediated (classified by onset within 2 h) |
| 2–4 h | 0.80 | acute FPIES — repetitive vomiting 1–4 h post-ingestion |
| 4–10 h | 0.50 | FPIES diarrhoea, typically 5–10 h |
| 10–24 h | 0.25 | non-IgE GI |
| 24–48 h | 0.10 | T-cell mediated / eczema flare (>24 h) |
| > 48 h | 0.00 | discard |

Rules:
- Meals with `portion == .refused` get weight `0`.
- A meal's weight is split across its `foodIDs` — three foods in one meal each get `weight / 3`, so a suspect eaten alone scores higher than one buried in a mixed bowl.
- Output a ranked `[(foodID, score)]`. Never return a single "the cause" — the UI shows candidates, ordered.
- Include the mechanism label alongside the score so the UI can say why a 3-hour-old meal is a candidate.

Expose the table as a named constant, not magic numbers inline, so it can be tuned later.

---

## Part 4 — IngredientRole & AllergenFamily

New file `BabyTreat/Models/IngredientClassification.swift`.

```swift
enum IngredientRole: String, Codable {
    case base      // counts toward rotation exposure
    case accent    // flavour / fat carrier — logged, consumes no rotation slot
    case additive  // E-numbers, hidden inside formula and packaged products
}

enum AllergenFamily: String, Codable {
    case dairy, egg, peanut, treeNut, legume, sesame, fish, shellfish,
         wheat, soy, arecaceae, none
}
```

Add to the food model: `role: IngredientRole`, `family: AllergenFamily`, and a separate `isMajorAllergen: Bool`.

CRITICAL — keep these two concerns apart:
- `family` drives **menu diversity scoring only** (avoid three legumes in one week).
- `isMajorAllergen` drives **rotation gating and exposure counting**.

Collapsing them causes false blocks. Coconut is the worked example: botanically a drupe, and the FDA's 5th-edition allergen guidance removed it from the major tree-nut list — most tree-nut-allergic children tolerate it. Tagging it `treeNut` would suppress a perfectly safe food.

Only `role == .base` consumes a rotation slot. `.accent` and `.additive` are logged, timestamped and attributable, but invisible to the rotation meter.

---

## Part 5 — Seed data

Add to the ingredient seed. Note the coconut milk split — one entry would make the calorie maths wrong by roughly a factor of six.

| Name (RO / EN) | Role | Family | Major allergen | Min age | Notes |
|---|---|---|---|---|---|
| Lapte de cocos conservă / Coconut milk, canned | accent | arecaceae | false | 6 mo (cooking only) | ~180–230 kcal/100 g, high saturated fat, often contains carrageenan |
| Lapte de cocos cutie / Coconut milk, carton | accent | arecaceae | false | 6 mo (cooking only) | ~20–40 kcal/100 g, diluted, usually fortified, often has added thickeners |
| Roșcove / Carob powder | accent | legume | false | 6 mo | Caffeine- and theobromine-free cocoa substitute |
| Gumă de roșcove E410 / Carob bean gum | additive | legume | false | — | Hidden in AR formulas and packaged foods |

Both coconut milk entries need a hard flag: **usable in cooking from 6 months, never as a drink before 12 months.** Plant milks are not formulated as a main drink under 12 months and using one as such risks serious nutritional deficiency. If the user tries to log either as a standalone drink under 12 months, block it with that explanation.

Carob's `legume` tag is for diversity only — clinical studies find little cross-reactivity between legume family members, and specifically none between carob and peanut. Do **not** let it gate on a peanut flag.

Carob bean gum earns its own row because a case exists of an infant reacting to an anti-regurgitation formula containing it. Formula ingredients need to be visible to the attribution engine as a background exposure, otherwise a real trigger stays invisible.

Also seed the rest of the accent tier so the roles get exercised: olive oil, butter, tahini, cinnamon.

---

## Part 6 — Wiring

- Register `MealLog` and `ReactionLog` in the `.modelContainer(for:)` list in `BabyTreatApp.swift`.
- Convert `GridView`'s three hardcoded `HStack` rows to a `LazyVGrid` with two flexible columns so a seventh Meal tile fits without breaking the existing six.
- Meal entry sheet: `DatePicker` for `eatenAt` defaulting to now, plus quick chips for −15 / −30 / −60 min. Slot picker separate and explicit.
- Reaction entry sheet: its own `DatePicker` for `observedAt`, defaulting to now. Do **not** prefill it from any meal.

Remind me to delete the app from the simulator before the first run — new SwiftData models will fail to migrate otherwise.

---

## Order of work

Land Parts 1–2 first and let me build and check the models before continuing. Then 4–5, then 3, then 6. Ask before touching any existing file outside `BabyTreatApp.swift` and `GridView.swift`.
