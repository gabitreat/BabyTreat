# Meal planning — established rules

- **Date:** 2026-07-26
- **Status:** Accepted (carried over from the prototype)
- **Source of truth:** `design/baby-meal-planner.html`. Every rule below was read
  out of that file's code, not from the chat's description of it — line
  references included so they can be re-verified after edits.
- **History:** [source-transcript.md](source-transcript.md)

## Baby profile

| Field | Value | Where |
|-------|-------|-------|
| DOB | 2025-12-23 | `BABY.dob`, L472 |
| Formula | Töpfer HA 1 | `BABY.formula`, L472 |
| Supplement | Vitamin D, drops, daily | `BABY.supplements`, L473 |
| Active hold | Dairy until 2026-08-23 — APLV unconfirmed, awaiting month 8 | `BABY.holds`, L474 |

The "stages roll over on the 23rd" rule is not a separate rule — it falls out of
the birth date. Age in months is computed from `dob`.

## Meal slots and age gates

`SLOTS`, L478–483. `from` = months completed; `null` = date not yet set.

| Slot | Unlocks at | Real date |
|------|-----------|-----------|
| Mic dejun | 0 mo | active |
| Prânz | 0 mo | active |
| Cină | 8 mo | 2026-08-23 |
| Gustare | — | undecided |

## Meal composition

- **Lunch must have protein + vegetable + fat.** Starch is *optional*, not
  implied — revised down from the original after the WHO check. `LUNCH_REQUIRED`,
  L786–790.
- Fat is satisfied either by a food in the `grasime` group **or** by the word
  *ulei* appearing in the dish name. `lunchGaps`, L794.
- Sweet potato counts as vegetable **and** starch; it appears in both groups.
  `GROUPS.cartofd`, L559.
- Coconut milk only inside recipes, 1–2×/week, never replacing formula.
  `RECIPES.r8.flag`, L659.
- No added salt or sugar.

## Weekly nutrition targets

Checked automatically per WHO 2023 + ESPGHAN. `weekNutrition`, L802–829.

- Animal-source food (`asf`) every day.
- Fruit **and** vegetable every day (counted together as one pass/fail).
- An iron source every day.
- Starch limited — reported as `starchFree` meals and `starchPct`.
- Vitamin D daily, marked as given.

## New food introductions

- One new vegetable + one new fruit per week where possible.
- Only one new food per day, spaced apart within the week.
- New foods proposed from the planned pool, ranked **in-season → priority flag →
  list order**. `suggestNew`, L849–866.
- Foods under a `hold` are excluded until the hold date — this is what keeps
  yogurt and cheese out of suggestions before 8 months. L858.

## Allergen re-exposure

`ALLERGENS`, L590–594; `allergenState`, L764–782. Target: every 7 days.

| Allergen | Baseline last exposure |
|----------|------------------------|
| Ou | 2026-07-22 |
| Unt de arahide | 2026-07-21 |
| Somon | 2026-07-21 |

The count runs off the **journal, not the plan** — a meal logged as `refuzat`
does not count as an exposure. Any amount actually eaten does.

## Rotation

Two halves, both now implemented:

1. **Detect** — accepted foods absent for >14 days are flagged, with
   recently-introduced ones (within 42 days) sorted first. `rotationCheck`,
   L869–885.
2. **Propose** — `rotationReturns` (L890+) actively names tolerated foods to put
   back into the week being planned, before they cross the 14-day threshold. It
   suppresses anything already scheduled that week, and it renders on planned
   weeks too, not just empty ones.

Protein rotation across: pui, curcan, somon, vită, ou, linte. L1142.

## Individual food holds

| Food | Rule | Where |
|------|------|-------|
| Mango | Tried 2026-07-23, refused. Retry 2026-08-17, no pressure. | L503–504 |
| Roșii | Acidic, can irritate skin around the mouth; many sources defer to 9–10 mo | L532–533 |
| Vinete | Peel and cook well; generally after 8–10 mo | L534–535 |
| Prune | Laxative — useful for constipation, start with a small portion | L536–537 |
| Iaurt, Brânză de vaci | Hold until 2026-08-23 (APLV) | L543–544 |
| Vită | Cleared by the doctor on 24 July. First portion Monday 27 July. | L518–519 |

## Generating a week

`MealPlanner` (D-15) composes the rules above into a week. It introduces nothing
new — the order it resolves them in is the only thing it adds:

1. **Allergen days.** Each allergen goes on the day its 7-day loop falls due,
   clamped into the week. No two share a day, so a reaction stays attributable.
2. **Introductions.** New vegetable and new fruit from `suggestNew`, spaced
   apart and kept off allergen days.
3. **Protein rotation.** Least-used this week, then longest-unserved; never the
   same protein two days running. A lentil lunch gets a non-allergen meat
   alongside it, because lentils are the one rotation protein that is not an
   animal-source food.
4. **Composition.** Lunch = protein + vegetable + fat. Three lunches are planned
   starch-free (see § Known-soft rules).
5. **Iron.** Salmon is the one rotation protein without iron, so a salmon day
   gets the iron-fortified cereal at breakfast.

It fills empty slots only, and checks the finished week with `weekNutrition`
before reporting on it.

**Dinner composition is not specified anywhere.** Until it is, a generated
dinner is a vegetable, a starch and oil, with the day's protein coming from
lunch. Dinner unlocks 2026-08-23.

## Reactions and combinations

Both feed back into the planner as `MealPlanner.Constraints` (D-17, D-18):

- A paused, held or blocked food is not scheduled at all.
- A food whose pause has expired outranks everything else — an unresolved
  question is worth more than an untested food.
- A confirmed negative pair is kept off the same plate. **Neither food is
  downgraded**; both stay available separately.

`MealRules` is untouched by either engine: these come from observed reactions,
not from nutrition guidance, and they change as flags are cleared.

## The planning week starts on Sunday

Menu and shopping list turn over together, on `MealRules.planningWeekStart`:
from Sunday, "this week" means the week that starts tomorrow (D-16). Sunday is
the planning day, so the new menu and the list to shop for it appear before the
shopping rather than after.

## Copyright

External recipes are **linked to source only, never copied in**. `SOURCES`,
L696–713 — Flaveur (Cristina Nenu, flaveur.ro), stored as title + URL + category
plus a search-by-ingredient helper. The two "fără lactate" / "fără ou" sections
are there specifically because APLV is unconfirmed.

## Known-soft rules

Flagged honestly at the time, still unresolved:

- **The starch-free threshold is a heuristic.** WHO says "minimize" without a
  number; "at least 2 meals per week without starch" was chosen, not derived.
- **The 14-day rotation window is arbitrary.** With only three weeks of menus
  seeded it flags almost nothing yet, so it is largely untested in practice.

## Data model

The prototype's constants are deliberately shaped as tables, intended to become
the schema close to directly (L466–469):

```
babies · foods · recipes · menu_entries · journal · shopping
```

Recipes reference food **IDs**, not names — that is what makes the colour strips
and protein rotation work without duplicating data. Preserve this when porting.

## Design language

Every food carries its own real colour (`FOODS[].color`). Accepted foods render
solid, weakly-accepted fade out, planned ones are dashed outlines. The Foods tab
therefore grows more colourful as acceptance grows, and the colour strip on a
meal card shows at a glance whether a meal is varied or beige.
