# Parent calorie module — decision log

Running log. Newest at the top. One entry per decision that would be expensive to
re-derive or easy to silently reverse.

Format: **ID · date · decision · why · where it lives.** If a decision is later
overturned, mark it `Superseded by P-nn` rather than deleting it — the reversal
is usually the interesting part.

Companion log to `instructions/meal-planning/decisions.md`, which covers the
baby's side of the app. This one covers the parent's energy budget only.

---

## P-1 · 2026-08-28 · The lactating floor keeps the lactation add-on inside it

`babytreat-beverages-and-active-energy-spec.md` Part 4.2 and its test 5 both
state the lactating floor as `max(BMR, 1800)`. The shipped code says
`max(BMR + lactationAdd, 1800)` — `EnergyEngine.floor(bmr:lactationAdd:isBreastfeeding:)`,
`BabyTreat/Nutrition/EnergyEngine.swift:238`.

For the spec's own worked example (68 kg, 168 cm, 32, BMR 1417, exclusive
breastfeeding, +500 lactation) the two disagree: the spec floors at **1800**,
the code floors at **1917**.

**Gabi chose the existing code.** Asked 2026-08-28, answered "The existing one."

Why it is the safer of the two: milk production runs on the day's intake, so a
deficit should not be allowed to eat into the lactation add-on. The spec's
version lets a 500 kcal goal deficit reach 117 kcal below the milk allowance
before anything stops it; the code's version stops it at the allowance.

**Consequences for the spec, which is now wrong on this point:**

- Part 4.2's second branch is restated: on a zero-activity day
  `1700 + 0 + 500 − 500 = 1700`, clamped up to **1917**, not 1800.
- Test 5 asserts against `max(BMR + lactationAdd, 1800)`.
- `lactatingFloor` stays 1800 as the absolute minimum for a parent whose
  computed floor lands below it (`EnergyEngine.swift:234`).
- C5 is untouched — the floor is still the last operation, applied after every
  credit including the new active-energy credit.

---

## Open questions

| ID | Question | Blocked on |
|----|----------|-----------|
| OQ-P1 | The milkshake template's default components. Spec 3.4 defers them deliberately; Prompt 1 says Gabi will specify separately. The builder must accept a template later without a model change. | Gabi |
| OQ-P2 | Spec Part 0 and Prompt 0 both assume a HealthKit integration and a home-cooked meal calculator already exist in the module. Neither does — stage 3 builds Health from zero, and 3.4's "same principle as the home-cooked meal calculator already in the module" refers to nothing. Does a home-cooked calculator need building too, or was `ServingCalculator` (per-serving, from a label photo) what was meant? | Gabi |
