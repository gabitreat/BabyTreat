# BabyTreat — Cycle Section: Period Start Calendar

Branch: `feature/baby`. This is a **spec, not code**. Do not simplify anything marked CRITICAL. Ask before changing files outside those named here.

Replaces the current single cycle-day input in the parent calorie module with a logged history of period start dates.

---

## Part 1 — PeriodStart model

New file `BabyTreat/Models/PeriodStart.swift`.

| Field | Type | Rule |
|---|---|---|
| `startDate` | `Date` | Day-precision. Normalise to `Calendar.startOfDay`. |
| `loggedAt` | `Date` | `.now` at insert. Audit only. |
| `timeZoneID` | `String` | Same convention as `MealLog`. |
| `isSpotting` | `Bool` | Default false. Spotting is excluded from cycle-length maths. |
| `notes` | `String` | Optional. |

CRITICAL — store a **list of start dates**, not a single "last period" field and not a fixed cycle length. Everything downstream is derived from the gaps between consecutive entries. A stored `cycleLength` constant will silently go stale and is the thing this feature exists to remove.

Uniqueness: one entry per calendar day. Tapping an already-marked day removes it.

---

## Part 2 — Calendar UI

New file `BabyTreat/Views/CycleCalendarView.swift`. Reached from the existing cycle section.

- Month grid, swipe or arrows between months, Romanian locale, week starting Monday (`Calendar.current.firstWeekday` respected, not hardcoded).
- Tap any day to mark or unmark it as a period start.
- Future dates are not tappable.
- Marked days: filled dot. Predicted next start (Part 3): hollow dot, visibly different, never confusable with a logged entry.
- Long-press a marked day to edit — toggle `isSpotting`, add a note, delete.
- Below the grid: a list of the last 6 logged starts with the gap in days between each, so the user can eyeball their own variability.
- Empty state: explain that at least 2 entries are needed before anything is calculated, and 3 before the calorie budget adjusts.

Use SwiftUI + `Calendar` directly. Do not add a third-party calendar package.

---

## Part 3 — Derived values

New file `BabyTreat/Services/CycleCalculator.swift`. Pure functions.

From the sorted start dates, excluding any entry where `isSpotting == true`:

- `cycleLengths: [Int]` — gaps between consecutive starts.
- `typicalCycleLength: Int?` — **median**, not mean. One missed log creates a double-length gap that would drag a mean badly off.
- `variability: Int?` — max minus min of the last 6 gaps.
- `currentCycleDay: Int?` — days since the most recent start, +1.
- `predictedNextStart: Date?` — most recent start + `typicalCycleLength`.

Guards, all CRITICAL:

1. Fewer than 2 entries → all derived values `nil`. Show the calendar, calculate nothing.
2. Fewer than 3 entries → show `currentCycleDay` only. No prediction, no calorie adjustment.
3. Any gap outside 21–45 days → flag the cycle as irregular and exclude that gap from the median.
4. `variability > 9` days → treat the cycle as irregular: keep displaying `currentCycleDay`, suppress `predictedNextStart` and suppress the calorie adjustment entirely.
5. Never extrapolate past `typicalCycleLength × 1.5`. Past that, show "late / no data" rather than a running negative countdown.
6. Never display a fertility, ovulation or conception estimate. This is a nutrition feature, not a contraception one.

---

## Part 4 — Calorie budget wiring

The existing cycle-phase adjustment reads `currentCycleDay` from this calculator instead of a manual entry. Phase boundaries derive from `typicalCycleLength`, with the luteal phase anchored at a fixed **14 days before the predicted next start** — luteal length is the stable part; follicular length is what varies between women and between cycles.

CRITICAL — cap the mid-luteal adjustment at **+100 kcal/day**, and keep it as a single tunable constant.

Reasoning, so this doesn't get inflated:

- A systematic review of RMR across the menstrual cycle found luteal-phase increases of roughly 30–120 kcal/day, about 3–5%, small enough to overlap with ordinary day-to-day variation and measurement error.
- A controlled REE study found the luteal phase only about 40 kcal/day higher than the follicular phase.
- Self-reported *intake* rises far more than expenditure does — meta-analysis puts it near 168 kcal/day, and individual studies report 300–500. Budgeting to the intake figure would be budgeting to appetite, not to physiology.

So: modest sine curve, peak at mid-luteal, amplitude capped at 100 kcal. The existing safety floor (BMR, or 1800 kcal while lactating) still overrides everything.

If the calculator returns `nil` or flags irregularity, the budget falls back to the unadjusted value **silently in the maths but visibly in the UI** — a one-line caption saying the cycle adjustment is off and why.

---

## Part 5 — Postpartum handling

The cycle section must handle "no period yet" as a normal state, not a data gap.

- If `babyAgeMonths` is set and there are zero logged starts, show a neutral message: absent periods while breastfeeding are expected, and the section will start working once there's something to log. No prompt, no nagging, no red state.
- Expect early cycles to be erratic. Postpartum periods are commonly irregular at first, and among women who menstruate before six months postpartum a high proportion of first menses are anovulatory. Guard 4 above will suppress the adjustment during this phase, which is the correct behaviour — say so in the caption rather than hiding it.
- Do not treat a long first gap as an error or ask the user to correct it.

---

## Part 6 — Wiring

- Register `PeriodStart` in `.modelContainer(for:)` in `BabyTreatApp.swift`.
- Migrate any existing manual cycle-day setting: read it once, offer to convert it into a single `PeriodStart` entry, then retire the `@AppStorage` key.
- Keep `PeriodStart` Supabase-portable — flat fields, no relationships.

---

## Order of work

1. `PeriodStart` model + container registration — stop here, let me build
2. `CycleCalculator` with the guards, plus unit tests for: 2 entries, 3 entries, one skipped log, a 60-day gap, high variability
3. `CycleCalendarView`
4. Calorie budget wiring and the caption states

Delete the app from the simulator before the first run — new `@Model` type.
