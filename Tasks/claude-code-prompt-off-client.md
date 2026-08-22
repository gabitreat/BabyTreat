# Claude Code Prompt — Open Food Facts client layer (BabyTreat)

> Paste everything below this line into Claude Code.

---

## 0. Before you start

- Confirm you are on branch `feature/baby`. If not, stop and tell me.
- Run `git status` and report any uncommitted work before making changes.
- Stack: SwiftUI, SwiftData, iOS 17, Tuist. `sources: ["BabyTreat/**"]` — new subfolders need no `Project.swift` change.
- Do not modify existing modules (Sleep, Playtime, Nursing, Medicine, Temperature).

## 1. Goal

Build the networking + model layer that looks up food products from Open Food Facts, for the **parent calorie budget tracker**. This task is the data layer only — no UI, no barcode scanning, no calorie math.

## 2. Files to create

```
BabyTreat/Services/OpenFoodFacts/
  OFFClient.swift          // protocol + live implementation
  OFFEndpoint.swift        // URL construction
  OFFDTO.swift             // Codable structs mirroring the API response
  OFFError.swift           // typed errors
  OFFMapper.swift          // DTO -> domain
  MockOFFClient.swift      // deterministic fixtures for previews/tests

BabyTreat/Models/
  FoodProduct.swift        // @Model, domain + local cache
  NutritionFacts.swift     // value type, always per 100 g/ml
  WeightBasis.swift        // enum: raw, dry, cooked
```

## 3. Non-negotiable requirements

These are the reasons this spec exists. Do not "simplify" any of them.

1. **Custom `User-Agent` is mandatory on every request.**
   Format: `BabyTreat/1.0 (iOS) - <contact-email>`. Read it from a single constant. Requests without it get throttled or blocked.
2. **All nutrition is computed from `nutriments` per-100g values only.**
   Never read `serving_size` or `serving_quantity` for arithmetic — they are free-text and unreliable. `serving_size` may be stored as a display-only string.
3. **"Not found" is a normal, expected outcome, not an error state.**
   Romanian-market coverage is thin. The API returns HTTP 200 with `status: 0`. Model this as a distinct success case (`.notFound`), not a thrown error, so the caller can route straight to manual entry.
4. **Every `NutritionFacts` carries a `WeightBasis`.** OFF data is always `.raw` (as-sold). Do not default it implicitly elsewhere.
5. **No force unwraps, no `try!`, no silent `?? 0` on nutrition fields.** Missing nutrient = `nil`, not zero. Zero and unknown are different facts.

## 4. API contract

**Base:** `https://ro.openfoodfacts.org`
Romanian subdomain queries the same global database — it changes language/country ranking, not the dataset.

**Product by barcode**
```
GET /api/v2/product/{barcode}.json?lc=ro&cc=ro&fields=<csv>
```
Request only these fields:
```
code, product_name, product_name_ro, generic_name_ro, brands, quantity,
categories_tags, allergens_tags, traces_tags, ingredients_text_ro,
nutriments, nutriscore_grade, nova_group,
image_front_small_url, image_front_url
```

**Free-text search** (fallback when the user types a name)
```
GET /cgi/search.pl?search_terms=<q>&lc=ro&cc=ro&json=1&page_size=20
```

**Response handling**
- `status == 1` → product present in `product`
- `status == 0` → `.notFound` (check `status_verbose` only for logging)
- Non-2xx → throw `OFFError.http(statusCode:)`

**Rate limits** — respect them, they are enforced server-side:
- product lookups: 100 req/min
- search: 10 req/min

Implement a lightweight in-memory token bucket per endpoint class. On 429, surface `OFFError.rateLimited(retryAfter:)`; do not auto-retry in a loop.

## 5. Field mapping rules

**Display name** — first non-empty of: `product_name_ro` → `product_name` → `generic_name_ro` → `brands` → `code`.

**Energy** — prefer `energy-kcal_100g`. If absent but `energy_100g` (kJ) exists, derive `kcal = kJ / 4.184` and set a flag `energyWasDerived: Bool` on the result. If both absent, `kcal == nil`.

**Macros** to map, all `_100g`, all optional `Double`:
`proteins`, `carbohydrates`, `sugars`, `fat`, `saturated-fat`, `fiber`, `salt`, `sodium`.

**Allergens** — `allergens_tags` and `traces_tags` come prefixed (`en:milk`, `en:gluten`). Strip the language prefix and keep the raw tag string. Do **not** map them onto the app's `AllergenFamily` enum in this task — that mapping belongs to the baby-food side and has its own FDA-grounded rules. Store the raw tags.

**Unit basis** — if `quantity` parses to millilitres, mark the product as liquid (`per100 == .millilitres`), otherwise grams. Default to grams when ambiguous.

## 6. Caching

`FoodProduct` is a SwiftData `@Model` used as a local cache and as the record of manually entered foods.

Required fields: `barcode: String?` (nil for manual entries), `name`, `brand: String?`, `nutrition` (flattened optional Doubles — SwiftData does not store nested value types well; flatten and document it), `weightBasis`, `source: ProductSource` (`.openFoodFacts` / `.manual`), `fetchedAt: Date?`, `imageURL: String?`, `rawAllergenTags: [String]`.

Rules:
- Lookup order: local cache by barcode → network → `.notFound`.
- Cache entries older than 30 days are refetched on next lookup; keep the stale copy if the network fails.
- Design fields to be Supabase-portable: no Swift-only types in stored properties, `barcode` unique where non-nil.
- Adding a new `@Model` means I must delete the app from the simulator before first run — remind me in your summary.

## 7. Errors

```swift
enum OFFError: Error {
    case http(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case decoding(underlying: Error)
    case network(underlying: Error)
    case invalidBarcode
}
```
`notFound` is deliberately **not** in this enum — see requirement 3.

## 8. Tests

Add unit tests covering, with local JSON fixtures (no live network in tests):
1. A well-populated product decodes with all macros.
2. A product with `energy_100g` but no `energy-kcal_100g` derives kcal correctly and sets `energyWasDerived`.
3. `status: 0` returns `.notFound` and throws nothing.
4. A product missing `proteins_100g` yields `nil`, not `0`.
5. Allergen tags have their `en:` prefix stripped.
6. Display-name fallback chain picks `product_name` when `product_name_ro` is an empty string (not just nil).

## 9. Out of scope — do not build

Barcode scanning (Vision), calorie budget math, BMR/lactation logic, Apple Health, any SwiftUI views, and any `AllergenFamily` mapping.

## 10. Deliverable

When done: summary of files added, the User-Agent constant location, confirmation that all six tests pass, and the simulator-delete reminder. Do not commit — leave changes staged for my review.
