# 0004. Timers derive elapsed time from wall clock, not tick accumulation

- **Status:** Proposed
- **Date:** 2026-07-26
- **Severity:** Data loss

## Context

`SleepView`, `PlaytimeView` and `NursingView` all run
`Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { elapsedTime += 1 }`.

iOS suspends timers when the app is backgrounded or the screen locks. Parents
lock the phone during a feed or a nap — that is the normal case, not the edge case.

Two different failure modes:

| View | On save | Result |
|------|---------|--------|
| Sleep, Playtime | `stopTime: Date()` vs stored `startTime` | Duration correct; **display** freezes while backgrounded |
| Nursing | saves the accumulated `leftElapsedTime` / `rightElapsedTime` | **Duration is wrong** — silently under-counts |

A nursing session where the parent locks the phone for 12 minutes records
roughly zero. The user has no signal that the data is wrong.

There is a second gap: no timer state is persisted. If iOS terminates the app
mid-nap, the in-progress session is gone entirely.

## Decision

1. Store `startTime: Date` (and per-breast accumulated intervals as
   `[(start, end)]` for nursing). Compute elapsed as `Date().timeIntervalSince(start)`.
2. The `Timer` only triggers a UI refresh. It never owns the value.
3. Persist in-progress sessions so a cold launch restores them.
4. Consider a `.backgroundTask` or live activity for long naps.

## Consequences

- Positive: correct durations regardless of app lifecycle.
- Negative: nursing needs an interval list rather than a single `TimeInterval`
  per side — a SwiftData migration.
