# 0007. Log medicine administrations, not just a medicine catalog

- **Status:** Proposed
- **Date:** 2026-07-26
- **Severity:** Safety-relevant

## Context

The `Medicine` model holds `name`, `details`, `createdAt`. `MedicineView` lets a
parent add and delete entries and view them. Nothing records that a dose was
**given**.

The app therefore cannot answer the one question a parent at 3am actually asks:
*when was the last dose, and is it safe to give another?* It also cannot help two
caregivers avoid double-dosing when neither knows what the other did.

This is the app's largest gap relative to its own premise. `HistoryView` has no
medicine query at all, so doses are absent from the timeline that everything
else appears on.

## Evidence

| Claim | Source | Type | Link |
|-------|--------|------|------|
| Home medication administration errors are common, especially with liquid preparations and multi-caregiver schedules | AAP, *Preventing Home Medication Administration Errors*, Pediatrics 2021 | Clinical report | https://publications.aap.org/pediatrics/article/148/6/e2021054666/183379/Preventing-Home-Medication-Administration-Errors |
| Over 40% of caregivers make errors dosing liquid medications | Yin et al., Acad Pediatr | Study | https://pmc.ncbi.nlm.nih.gov/articles/PMC4034520/ |
| Medication errors by caregivers occurred in 66.3% of infants under 3 months after NICU discharge | Arch Dis Child | Cross-sectional study | https://pubmed.ncbi.nlm.nih.gov/28468867/ |
| Coordination across multiple caregivers is a named contributor to pediatric dosing error | AAP scoping review, Pediatrics 2023 | Review | https://publications.aap.org/pediatrics/article/152/6/e2023061281/195645/Measurement-of-Ambulatory-Medication-Errors-in |

## Decision

Add `MedicineDose` — `medicine` relationship, `administeredAt: Date`,
`amount: Double?`, `unit: String?`, `givenBy: String?`, `note: String?`.
Surface time-since-last-dose on the medicine row, and plot doses on the History
timeline alongside sleep, nursing and temperature.

## Explicitly out of scope

BabyTreat **does not** calculate doses, recommend amounts, suggest intervals, or
state whether another dose is safe. It records what the caregiver entered and
shows elapsed time. Any of the above would make this a clinical decision support
tool, with the regulatory and liability posture that implies.

Interval and maximum-daily-dose fields, if added, are values the caregiver types
in from their own prescription label — never defaults we ship.

## Consequences

- Positive: closes the core use case; the timeline becomes complete.
- Negative: the "do not advise" line needs holding under feature pressure.
- Revisit when: a clinician is on the team and regulatory scope is assessed.
