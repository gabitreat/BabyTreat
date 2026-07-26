# BabyTreat — code audit, 2026-07-26

Reviewed: `Project.swift`, 5 models, 10 views. Ranked by risk.

## Blocking (silent wrong data)

| # | Finding | Where | ADR |
|---|---------|-------|-----|
| 1 | Nursing saves tick-accumulated time; iOS suspends the timer when the phone locks, so durations silently under-count | `NursingView.saveSession` | 0004 |
| 2 | Sleep crossing midnight is truncated at 24h and never appears on the second day — night sleep, the headline metric, is lost | `HistoryView.segmentsForDay`, `monthTimeBlocks` | 0005 |
| 3 | Temperature stores a per-row unit but charts the raw value; switching °C→°F mixes 37.0 and 98.6 in one dataset | `TemperatureReading`, `HistoryView` | 0006 |

## High

| # | Finding | Where | ADR |
|---|---------|-------|-----|
| 4 | Medicine is a catalog with no dose log — cannot answer "when was the last dose?" | `Medicine`, `MedicineView` | 0007 |
| 5 | Baby age stored as an `Int` in AppStorage; goes stale the day after it is entered. No birth date, no baby entity, no sync | `SettingsView` | 0008 |
| 6 | "Load Mock Data" ships in the production build; `mockDataLoaded` is `@State`, so it resets and re-inserts duplicates | `HistoryView` | — wrap in `#if DEBUG` |
| 7 | Fever threshold hardcoded at 38.0 °C with no measurement site recorded; axillary and rectal are not interchangeable | `TemperatureView` | 0006 |

## Medium

| # | Finding | Where |
|---|---------|-------|
| 8 | `DiaperView` is a stub — no model, no persistence | `DiaperView` |
| 9 | `FormulaView` has no `modelContext` and no model; the bottle UI discards every value | `FormulaView` |
| 10 | `danielgindi/Charts` declared and pinned but never linked (`dependencies: []`); `import Charts` actually resolves to Apple Swift Charts — a module-name collision waiting to happen | `Package.swift`, `Project.swift` |
| 11 | No way to edit or delete a saved record; mistaps are permanent | all views |
| 12 | Bundle ID is still `com.yourcompany.babytreat` | `Project.swift` |
| 13 | `NavigationView` is deprecated; `.navigationBarHidden(true)` is applied outside it, so it does nothing | `GridView`, `HistoryView` |
| 14 | No tests of any kind | — |
| 15 | AppIcon asset catalog has no images | `Assets.xcassets` |

## Suggested order

1. ADR 0004 + 0005 — stop losing data. Nothing else matters until logging is trustworthy.
2. ADR 0006 — normalize before the row count grows.
3. ADR 0008 — the `Baby` migration is cheapest now.
4. ADR 0007 — the product's actual core loop.
5. Finding 6, 12, 15 — a five-minute pre-TestFlight sweep.
