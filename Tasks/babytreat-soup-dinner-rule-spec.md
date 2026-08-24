# BabyTreat — Month 8 Dinner Rule: Soups Only, 2-Day Batches

Branch: `feature/baby`. This is a **spec, not code**. Do not simplify the parts marked CRITICAL. Ask before changing anything outside the files named here.

Depends on `MealSlot`, `MealLog` and `IngredientRole` from the meal module spec. Build that first.

---

## Part 1 — DinnerRule

New file `BabyTreat/Services/DinnerRule.swift`.

At `babyAgeMonths == 8`, the dinner slot suggestion engine returns **soups only**. Recipes need a `form` field:

```swift
enum MealForm: String, Codable {
    case soup        // liquid/blended, spoon-fed
    case puree
    case mashed
    case fingerFood
}
```

Rule: `slot == .dinner && ageMonths >= 8 && ageMonths < 9` → filter suggestions to `form == .soup`.

Constraints:
- This is a **suggestion filter, not a hard block**. If the user manually logs a non-soup dinner, accept it silently. Never refuse a log of food that was actually eaten — the log must reflect reality, not the plan.
- Keep the age window and form set in a single tunable struct so the rule can be extended to other months without touching the engine.
- All other slots at month 8 are unaffected.

Note in the UI copy: soup-only is a **household preference**, not a clinical requirement. By 8 months babies should also be progressing toward lumpier textures and finger foods, so surface a one-line reminder that lunch/breakfast should carry the texture progression while dinner stays liquid.

---

## Part 2 — SoupBatch model

New file `BabyTreat/Models/SoupBatch.swift`. A batch is one cook covering **1 or 2 consecutive days**.

| Field | Type | Rule |
|---|---|---|
| `recipeID` | `String` | e.g. carrot & potato soup |
| `cookedAt` | `Date` | When cooking finished. Minute precision. |
| `spanDays` | `Int` | 1 or 2 only |
| `startDate` | `Date` | First day the batch covers |
| `portionStorage` | `[Date: StorageMethod]` | Per covered day |
| `timeZoneID` | `String` | Same convention as `MealLog` |

```swift
enum StorageMethod: String, Codable { case fresh, refrigerated, frozen }
```

Day 1 portion → `.fresh`. Day 2 portion → see Part 3.

Logging a dinner from a batch creates a normal `MealLog` with its own user-set `eatenAt` — do not derive `eatenAt` from `cookedAt`. Store `batchID` on the `MealLog` so attribution can tell that Monday and Tuesday dinner were the same food.

CRITICAL for the attribution engine: two dinners from one batch are **two independent exposures**, not one. A reaction on Tuesday must not be attributed back to Monday's cook time.

---

## Part 3 — Storage safety rules

CRITICAL — the day-2 portion defaults to `.frozen`, and refrigerating it for a second day requires an explicit override with a warning shown.

Reasoning, so this doesn't get "simplified" to a plain 48-hour fridge rule:

- General NHS batch-cooking guidance is cool within 1–2 hours, then fridge for up to 2 days.
- But vegetable purées for infants are a special case. A published case series found methaemoglobinaemia in infants averaging 8 months old, all fed homemade mixed-vegetable purée prepared in advance and refrigerated for 12–27 hours. Food-safety guidance for infant vegetable purée recommends consuming immediately, or if storage is unavoidable keeping it under 12 hours refrigerated below 4 °C, and freezing beyond that.
- Improper storage of cooked vegetables converts nitrate to nitrite in situ, which is the mechanism behind that risk. Freezing halts it; a second day in the fridge does not.
- Carrot and potato are both root vegetables and lower-nitrate than leafy greens, but the case-series purées were mixed vegetables, so the rule applies to the batch, not the headline ingredient.

Implement:

1. Tag ingredients with `nitrateRisk: .low / .moderate / .high`. High: spinach, chard, beetroot, lettuce, fennel. Moderate: carrot, courgette, green beans, squash. Low: potato, meat, rice, most fruit.
2. Any batch containing a `.high` ingredient → `spanDays` locked to 1. Explain why inline.
3. `.moderate` or `.low` → 2 days allowed, day-2 portion `.frozen` by default.
4. Cooling reminder fires 90 minutes after `cookedAt`: portion and chill or freeze now.
5. Reheat rule: steaming hot throughout, cooled before serving, **reheated once only** — any uneaten reheated portion is discarded. If the batch contains rice, cap fridge storage at 24 hours and never reheat rice more than once.
6. Never offer a batch whose day-2 portion was left `.refrigerated` and is now more than 24 h past `cookedAt`. Mark it expired in the planner.

---

## Part 4 — Planner UI

In the weekly planner, a 2-day batch renders as one card spanning both days (Mon–Tue), showing recipe name, `cookedAt`, and per-day storage badge.

- Creating a batch: pick recipe → pick 1 or 2 days → confirm storage for day 2.
- Rotation meter counts a 2-day batch as **two exposures of each base ingredient**, not one. Carrot on Monday and Tuesday means carrot appeared twice this week — the diversity score must see that, or repeat batching will silently narrow the diet.
- Accent ingredients in the soup (olive oil, herbs) still consume no rotation slot.
- Expired or discarded batches: let the user mark the batch as discarded, which voids any unlogged planned meals without touching meals already logged.

---

## Part 5 — Seed

Add carrot & potato soup as a seeded recipe: `form == .soup`, `nitrateRisk == .moderate` (carrot), minimum age 6 months, `spanDays` up to 2. Add two more month-8 soup options so the dinner filter has something to rotate against — pick from ingredients already seeded, no dairy before the 8-month gate.

---

## Order of work

1. `MealForm` + `nitrateRisk` tagging + seed
2. `SoupBatch` model — stop here and let me build
3. `DinnerRule` filter
4. Storage rules and reminders
5. Planner UI

Delete the app from the simulator before the first run — new `@Model` types won't migrate.
