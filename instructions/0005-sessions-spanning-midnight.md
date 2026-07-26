# 0005. Sessions that cross midnight are split for display

- **Status:** Proposed
- **Date:** 2026-07-26
- **Severity:** Correctness — affects the primary metric

## Context

In `HistoryView.segmentsForDay(_:)` records are selected with
`r.startTime >= dayStart && r.startTime < dayEnd`, and the end is clamped with
`min(e, 24)`.

For a baby app the headline number is **night sleep**, which by definition
crosses midnight. A sleep from 22:00 to 07:00:

- appears on the start day, truncated to 2 hours
- does not appear at all on the following day
- 7 hours vanish from every total, chart and summary card

The same clamp exists in `monthTimeBlocks`.

## Decision

Introduce a single helper that, given a record and a day window, returns the
overlapping portion:

```
overlap(record, dayStart, dayEnd) -> (startHour, endHour)?
```

Select records by **interval overlap**, not by `startTime` membership, and let a
record contribute a segment to every day it touches. Storage stays unchanged —
one record per real session. Only display splits.

## Consequences

- Positive: totals become correct; night sleep is visible on both days.
- Negative: `segmentsForDay` needs a wider query window (day ± 1) or a
  precomputed index. Negligible at this data volume.
- Test: a 22:00→07:00 record must yield 2h on day N and 7h on day N+1.
