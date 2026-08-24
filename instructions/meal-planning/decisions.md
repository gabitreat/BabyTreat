# Meal planning — decision log

Running log. Newest at the top. One entry per decision that would be expensive to
re-derive or easy to silently reverse.

Format: **ID · date · decision · why · where it lives.** If a decision is later
overturned, mark it `Superseded by D-nn` rather than deleting it — the reversal
is usually the interesting part.

---

## Open questions

| ID | Question | Blocked on |
|----|----------|-----------|
| OQ-1 | The original *Meal Planning Reference v1.0 (July 2026)* document was elided as `[PASTED]` when the history was copied over. Most of its content is recoverable from `design/baby-meal-planner.html`, but any prose sections — routine, journal conventions, shopping habits — are lost. | Gabi re-pasting the doc, or confirming the prototype supersedes it |
| OQ-2 | Snack has no unlock date — **deferred 2026-07-26, to be decided later.** `MealSlot.snack.unlocksAtMonths` stays `nil`, so the slot never unlocks on its own and the app stays on three meals until a number is set. | Gabi, later |
| OQ-3 | ~~Was the CMPA question itself settled, or only the beef?~~ | **Answered 2026-07-26 — still unconfirmed.** See D-12 |
| OQ-7 | ~~Should the dairy hold be date-gated or confirmation-gated?~~ | **Resolved by D-14** — date-gated, with a one-off notice |
| OQ-4 | ~~Does the meal planner become part of the BabyTreat iOS app, a separate app, or stay a web tool?~~ | **Resolved by D-7** — built into the app |
| OQ-5 | ~~UI chrome is English while all food, recipe and menu data is Romanian.~~ | **Resolved by D-10** — English throughout |
| OQ-6 | ~~Tuist drift: `tuist generate` needs a network fetch for an unlinked `Charts` dependency; local project at 26.0 vs `Project.swift`'s 17.0.~~ | **Resolved by D-13** — Tuist retired |

---

## D-17 · 2026-08-03 · "Didn't like it" is not a reaction, and never suppresses

Reactions are recorded on `MealLog` at four levels. The first, `dislike`, is
deliberately not a reaction at all.

| Level | Consequence |
|-------|-------------|
| dislike | nothing. Stays on the menu. |
| mild | paused 21 days, then `.retry` |
| moderate | held indefinitely, pediatrician flag, manual clearing |
| severe | blocked, clearing needs an explicit confirmation |

**Why the split:** at the table both look identical — a refused bowl. They call
for opposite responses. A disliked food has to keep coming back; that is the only
thing that produces acceptance. A food that caused symptoms has to go away.
Collapsing them would quietly remove foods for being unpopular.

The question is **only asked when the portion was "a few spoons" or "refused"**.
Above that it would appear after nearly every meal and be tapped past within a
week.

**Attribution.** A flag is pinned on one food only when exactly one food in the
meal has fewer than two clean prior exposures. Two unproven foods → both are
paused and retested separately, because guessing gets it wrong in both
directions: it clears a real trigger and removes an innocent food. Zero unproven
foods → the reaction is recorded but nothing is suppressed; there is no candidate.

**Where:** `BabyTreat/Logic/ToleranceEngine.swift`, `Models/ToleranceLevel.swift`

## D-20 · 2026-08-24 · Day two of a soup batch is frozen by default

`SoupBatch.defaultStorage(forDayIndex:)` returns `.fresh` for day one and
`.frozen` for day two. Refrigerating a second day is possible, but only as an
explicit override with the warning shown — the app never picks it.
`NitrateRisk.high` locks a batch to a single day outright.

**Why:** general batch-cooking guidance (cool within 1–2 h, fridge up to 2 days)
does not transfer to infant vegetable purée. A published case series found
methaemoglobinaemia in infants averaging 8 months, all fed homemade mixed-veg
purée refrigerated 12–27 h. Improper storage converts nitrate to nitrite in
situ; freezing halts it, a second fridge day does not. The case-series purées
were mixed, so the rule binds the batch, not the headline ingredient — carrot
and potato being low-nitrate roots does not exempt the cook.

An untagged food resolves by kind: an unknown **vegetable** is `.moderate`,
everything else `.low`. Guessing `.low` on something that turns out to be a
leafy green is the one error here with a clinical cost.

**Where:** `Models/MealForm.swift` (`NitrateRisk`), `Models/SoupBatch.swift`,
`Food.nitrateRisk`, `Recipe.nitrateRisk(foodsByID:)`.

## D-21 · 2026-08-24 · A batch is a back-reference, never an attribution shortcut

`MealLog.batchID` records which cook a portion came from. Nothing derives a meal
time from `cookedAt`.

**Why:** two dinners off one batch are **two independent exposures**. Attributing
a Tuesday reaction back to Monday's cook time would blame the wrong day, which is
the same failure mode `ReactionLog`'s missing meal relationship exists to prevent
(D-17). The rotation meter counts a 2-day batch as two exposures of each base
ingredient for the same reason — counting it once would let repeat batching
silently narrow the diet.

**Where:** `Models/MealLog.swift`, `Models/SoupBatch.swift`.
Test: `testBatchDoesNotCarryAMealTime`.

## D-22 · 2026-08-24 · New @Model types migrate additively — no wipe needed

The soup spec asks for the app to be deleted before first run. Checked instead of
assumed: old build installed, sentinel `Food`/`Recipe`/`MealLog` rows written
through `sqlite3`, new build installed over the top without uninstalling.
`ZSOUPBATCH` was created, `ZNITRATERISKRAW` / `ZFORMRAW` / `ZBATCHID` were added,
all three sentinel rows survived, and the app stayed up.

**Why:** a new entity plus optional attributes is what lightweight migration
handles. Wiping the store would have destroyed a real feeding journal for no
reason.

**Where:** verified on simulator `iPhone 17`, 2026-08-24. Same technique as the
`eatenAt` check.

## D-19 · 2026-08-22 · Botanical family is seeded, and backfilled onto old rows

`AllergenFamily` is set on the seed's base foods (`ou` → egg, `somon` → fish,
`arahide` → peanut, `linte`/`mazare`/`naut` → legume, `iaurt`/`branza` → dairy).
Foods whose family is genuinely uncertain — `hipp`, `ovaz` — stay `.none` rather
than being guessed at. `MealSeed.backfillClassification(in:)` runs on every
launch and writes the seeded classification onto any stored row that is still
unset.

**Why:** the family attribute shipped before the tags did, so every existing
pantry had `.none` everywhere and diversity scoring counted nothing at all —
a rule that is live in the code and dead in the data. The backfill treats the
stored default as unset, not as intent, because nothing in the app can set a
family: there is no user choice to overwrite. Foods the seed doesn't know are
left alone.

**Where:** `MealPlanning/MealSeed.swift` (`accents()`, `backfillClassification`),
called from `Views/MealsView.swift`. Tests: `testBackfillUpgradesTheStoredDefault`,
`testBackfillIgnoresUnseededFoods`, `testThreeLegumeMealsAreFlaggedAsCrowded`.

## D-18 · 2026-08-03 · Combination effects are measured on the pair, not the food

`PairEffectEngine` compares how two foods score together against how they score
apart, in both directions — a combination that gets refused, and a carrier that
rescues something otherwise rejected.

```
rateA    = mean portion score of meals with A and NOT B
rateB    = mean portion score of meals with B and NOT A
expected = (rateA + rateB) / 2
observed = mean of meals with both
delta    = observed − expected
```

**The `NOT B` exclusion is the load-bearing part.** Score A over every meal
containing A and the shared meals are counted in both terms, so a food only ever
served alongside one partner has `rateA == observed` and a delta pinned near
zero — invisible in exactly the case worth finding. Verified: with rice served
5× alone and 6× with fish, excluding fish gives `rate(rice) = 1.00`; including it
gives 0.78.

**A confirmed negative blocks the pair, not either food.** Both stay individually
available, because individually there is nothing wrong with either. Downgrading a
food for something that only happens in combination is the failure this exists to
prevent.

Guards: 3 shared meals minimum, 6 to confirm, and 4 *non-shared* meals for each
food. Below that it reports what needs serving apart instead of a verdict.
Physiological flags are excluded from the taste maths — a reaction is not a
preference — but dislikes are kept, since a taste refusal is the signal itself.

**Where:** `BabyTreat/Logic/PairEffectEngine.swift`, `Views/Meals/PairInsightsView.swift`

## D-15 · 2026-08-03 · The week is generated from the existing rules, not new ones

`MealPlanner` builds a week of meals. It adds **no nutrition rules of its own** —
every decision it makes is one of the rules already in `MealRules`, and it
verifies its own output with `weekNutrition` and `lunchGaps` rather than
asserting correctness because it followed them.

**Constraints it applies, in the order it resolves them:**

1. Allergen days first — each allergen lands on the day its 7-day loop falls due,
   clamped into the week, and no two share a day.
2. Introductions next — the new vegetable and new fruit from `suggestNewFood`,
   spaced apart and kept **off** allergen days.
3. Protein rotation — spread first, longest-unserved next, never the same
   protein two days running.
4. Lunch composition, then the daily targets (animal-source food, fruit and
   vegetable, iron), then the starch-free heuristic.

**Deliberate properties:**

- **Deterministic.** Same inputs, same week. A plan that cannot be re-derived
  cannot be argued with.
- **Only fills empty slots.** A meal written or edited by hand is never
  overwritten; `MenuEntry.isGenerated` is cleared the moment one is edited, and
  "Plan again" only discards meals that still carry the flag.
- **Auto-runs once per week**, when the Meals section opens, and only if the week
  ahead is completely empty. A week deliberately cleared stays cleared.

**Known-soft:** dinner composition. `rules.md` specifies only lunch, so a
generated dinner is a vegetable, a starch and oil — the day's protein and
animal-source food come from lunch. This is a choice, not a rule; it needs
confirming before dinner unlocks on 2026-08-23.

**Where:** `BabyTreat/MealPlanning/MealPlanner.swift`, `MealsWeekView.planner`

## D-16 · 2026-08-03 · Menu and shopping list share one week turnover, on Sunday

`shoppingWeekStart` became `planningWeekStart` and now drives the Week tab, the
auto-planner and the shopping list alike. From Sunday it means the week that
starts tomorrow.

**Why:** Sunday is the planning day. A list that appears on Monday arrives after
the shopping, and a menu that turns over on a different day from the list it is
built from is how the list ends up missing the week's new foods.

**Where:** `MealRules.planningWeekStart(for:)`, `MealsWeekView.weekStart`,
`MealsShoppingView.currentWeek`

## D-7 · 2026-07-26 · Meal planning ships inside the BabyTreat iOS app

Resolves OQ-4. Not a separate app, not a web tool.

**Consequences taken on:**

- SwiftData models `Food`, `Recipe`, `MenuEntry`, `MealLog`, `ShoppingItem` join
  the existing container in `BabyTreatApp`. The prototype's table shapes carried
  over directly, so the Supabase port stays open — it is not foreclosed.
- The rule engine is a plain `enum MealRules` with no SwiftData or SwiftUI
  imports, so it can be reasoned about and eventually tested on its own.
- `Meals` is a full-width tile on the home grid, below the six logging tiles —
  it is a section, not a single logging action.
- The meal section follows the **prototype's** visual language (`MealTheme`,
  ported from the HTML `:root`), not the flat colour-block style of the existing
  tiles. That was the point of the design reference.

**Where:** `BabyTreat/Models/`, `BabyTreat/MealPlanning/`, `BabyTreat/Views/Meals/`

## D-8 · 2026-07-26 · Baby age comes from a birth date, not a stored month count

`SettingsView` had `@AppStorage("babyAgeMonths"): Int`, written by a stepper and
**read by nothing**. Replaced with `babyBirthDate`, with age computed from it.

**Why:** every age gate in the meal module — dinner at 8 months, dairy hold to
23 Aug, recipe availability, the milestone bar — depends on knowing the real age
on the day it is asked. A stored month count is wrong the day after it is
entered. This also closes part of FINDINGS #5.

**Where:** `SettingsView.swift`, `MealRules.ageMonths(on:birthDate:)`

## D-14 · 2026-07-26 · The dairy hold stays date-gated, with a one-off notice

Resolves OQ-7. The hold still expires on 2026-08-23 by date. On the day it does,
the Today tab shows a dismissible card: yogurt and cottage cheese can now be
suggested, CMPA was last recorded as unconfirmed, confirm with the pediatrician
first.

**Why not gate on a CMPA status field:** it would need a setting that has to be
kept accurate to stay useful, and a stale "unconfirmed" would block dairy
indefinitely with no prompt to revisit. The notice puts the caveat in front of
the caregiver at the moment it matters and leaves the judgement with them.

**Known limitation, accepted:** the suggestion appears whether or not the notice
is acted on. Dismissing the card is not the same as clearing CMPA. If dairy
should be genuinely blocked rather than flagged, that needs the status field.

**Where:** `MealsTodayView.dairyHoldNotice`, `@AppStorage("dairyHoldNoticeSeen")`

## D-13 · 2026-07-26 · Tuist retired; the .xcodeproj is the source of truth

Resolves OQ-6. `tuist generate` could not run without a network fetch for a
`Charts` dependency the target declares and never links (FINDINGS #10).

- `.gitignore` no longer excludes `*.xcodeproj`, `*.xcworkspace` or `Derived/`.
  The project is now tracked source, and `Derived/` holds generated files the
  project compiles, so it is tracked too.
- `Project.swift` and `Package.swift` are kept for reference but are **inactive**.
  Running `tuist generate` would overwrite the real project — don't.
- New files are added with `tools/add_files_to_xcodeproj.py`, or through Xcode.

**Deployment target moved 26.0 → 17.0.** That was the value `Project.swift`
always intended; the 26.0 was drift introduced when the project was last touched
in Xcode. **Verified** — the whole target, meal code included, builds clean at
17.0, so this is no longer the unverified claim recorded in D-9. The practical
effect is that the app supports iOS 17 devices again rather than iOS 26 only.

## D-12 · 2026-07-26 · CMPA remains unconfirmed — the dairy hold stands

Answers OQ-3. Beef was cleared by the doctor on 24 July and goes ahead on the
27th, but the underlying cow's-milk-protein allergy question was **not** settled.

**No code change.** The current behaviour is already correct for this answer:
`iaurt` and `branza` carry `holdUntil: 2026-08-23`, and `suggestNewFood` filters
out held foods, so neither is proposed.

**But the hold is date-gated, not reason-gated** — raised as OQ-7. On 23 August
the date passes and the suggester will begin proposing dairy regardless of
whether CMPA has been ruled out by then. The hold encodes *"wait until month 8"*
when what is actually meant is *"wait until CMPA is cleared, and not before
month 8."* Those come apart in four weeks.

## D-10 · 2026-07-26 · The meal section is English throughout

Resolves OQ-5. Chrome, food names, recipe titles, ingredients, method steps,
menu dishes and the shopping list are all English. The prototype's Romanian is
kept only in `design/baby-meal-planner.html`, which stays as the design record.

**Food IDs stay Romanian** (`dovlecel`, `cartofd`, `arahide`). They are opaque
keys that recipes, menu entries, allergen baselines and the rule engine all
reference; renaming them would break every cross-reference and buy nothing.
Expect to read `foodIDs: ["vita", "broccoli", "cartofd"]` and see "Beef,
Broccoli, Sweet potato" on screen.

**One rule had to move with the text.** `lunchGaps` credits the fat requirement
when the dish name mentions an oil — it matched `"ulei"`, and now matches
`"oil"`. A dish renamed to English without that change would have silently
started failing the lunch check.

Flaveur section labels are translated as *descriptions*; the pages they link to
are still Romanian. The tag on the dairy-free and egg-free sections reads CMPA
rather than APLV.

**Where:** `MealSeed.swift`, `MealRules.lunchGaps`, `MealSlot`, `MealPortion`,
`RecipeSource`, all five tab views.

## D-11 · 2026-07-26 · Seed data is versioned, and reinstalling replaces it

`installIfNeeded` used to seed only an empty store, so a device that already had
the v1 Romanian seed would never see the English one. It now compares
`MealSeed.version` against a stored value and replaces foods, recipes, menu and
shopping list when it moves.

**`MealLog` is deliberately exempt.** The journal is the caregiver's own record,
not seed content, and it re-associates by date and slot. Everything else is
replaced, so **status and rating edits made against an older seed are lost** —
acceptable while the seed is a day old, not acceptable once real acceptance
history accumulates. Revisit before the next bump.

## D-9 · 2026-07-26 · Edit the local Xcode project directly rather than regenerating

`tuist generate` fails without `tuist install`, which needs a network fetch for
the `Charts` dependency the target never links (FINDINGS #10). So the 14 new
files were added to the checked-out `.xcodeproj` directly, to get a build.

**This is a local workaround, not a committed change.** `.gitignore` treats
`*.xcodeproj` and `*.xcworkspace` as Tuist artifacts, so the edit is untracked
and disposable. `Project.swift` remains the source of truth, and its
`sources: ["BabyTreat/**"]` glob already covers every new file — a regenerated
project picks them all up with no further work.

**Consequence to know about:** the local project builds at
`IPHONEOS_DEPLOYMENT_TARGET = 26.0`; `Project.swift` says `17.0`. Regenerating
will move the build to 17.0. Nothing in the meal code needs more than iOS 17
(`@Bindable`, `UnevenRoundedRectangle` are the newest APIs used), but the target
has not been *compiled* at 17.0 — only at 26.0. Verify after the first
regeneration.

**How:** `tools/add_files_to_xcodeproj.py` — deterministic IDs, idempotent,
`plutil`-validated, re-runnable for further files.

---

## D-6 · 2026-07-26 · Keep the prototype in `design/` as the design reference

The HTML prototype is the reference for both look and behaviour, not a throwaway.
Rules extracted into `rules.md` cite its line numbers so drift is detectable.

**Why:** the chat's description of the rules and the code's actual rules had
already diverged once (starch requirement, off-by-one on age). Citing the code
keeps the doc honest.

**Where:** `design/baby-meal-planner.html`, `instructions/meal-planning/rules.md`

## D-5 · 2026-07-26 · Track meal-planning decisions in the repo, not in chat

History, rules and decisions live under `instructions/meal-planning/`, following
the existing ADR convention in `instructions/`.

**Why:** the prior conversation established roughly twenty rules across several
turns, with two of them revised mid-conversation. None of that was recoverable
outside the chat, and the share link could not be re-read.

**Where:** this folder.

## D-4 · 2026-07-26 · Close the rotation gap — propose, don't just flag

`rotationReturns` actively names tolerated foods to bring back into the week
being planned. Recently-accepted foods sort first, marked as at risk of dropping
out. Already-scheduled foods are suppressed; proposals show on planned weeks too.

**Why:** detection alone told you *after* you'd already planned the week wrong.
The failure case that mattered was a hard-won accepted food quietly disappearing
after a single exposure.

**Where:** `design/baby-meal-planner.html` L890+

## D-3 · 2026-07-26 · Allergen counter reads the journal, not the plan

A meal logged as `refuzat` does not reset the 7-day clock. Any amount actually
eaten does.

**Why:** a planned exposure that the baby refused is not an exposure. Counting it
would silently under-expose.

**Where:** `allergenState`, L764–782

## D-2 · 2026-07-26 · Lunch requires protein + vegetable + fat; starch optional

Revised down from the original protein + vegetable + fat + starch after checking
WHO guidance, which says to minimize starch rather than require it.

**Why:** the original rule made every lunch starchy by construction.

**Where:** `LUNCH_REQUIRED`, L786–790. Caveat on the "2 starch-free meals/week"
number recorded in `rules.md` § Known-soft rules.

## D-1 · 2026-07-26 · External recipes are linked, never copied

Flaveur recipes stored as title + URL + category only.

**Why:** copyright.

**Where:** `SOURCES`, L696–713
