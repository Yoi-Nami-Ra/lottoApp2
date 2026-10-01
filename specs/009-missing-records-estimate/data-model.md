# Data Model: Missing Records Estimate

## DrawCadence (Domain, new — `Domain/BLogic/DrawCadence.swift`)

| Field | Type | Rule |
| --- | --- | --- |
| `drawsInWindow` | `Int` | ≥ 1: the stored draws dated in `[W0 − 14 days, W0)`, where `W0` is the start of the UTC Monday-first week holding the latest draw (research R3) |
| `drawsPerDay` | `Double` (computed) | `drawsInWindow / 14` |

`measure(drawDates:calendar:) -> DrawCadence?` returns `nil` when there are no dates, when the earliest date is
after `W0 − 14 days`, or when the window holds 0 draws.
`missing(since:now:) -> Int` returns `⌊drawsInWindow × max(0, now − since) / 1,209,600 s⌋`.
`Calendar.drawWeeks` is a Gregorian calendar in UTC with `firstWeekday = 2`.

## Source (Domain, changed)

| Field | Change |
| --- | --- |
| `cadence: DrawCadence?` | **new**; `nil` before the first sync, for metadata written before this feature, or without enough history |

## SourceMeta (Data, changed)

| Field | Change |
| --- | --- |
| `drawsInWindow: Int?` | **new**; written by `LocalStore.meta(…)` on every successful save; `decodeIfPresent` → `nil` for older files |

## SourceEntry.State (Presentation, changed)

| Field | Change | Rule |
| --- | --- | --- |
| `missingEstimate: Int?` | **new** | `cadence.missing(since: latestRecord, now:)` when both exist, else `nil` |
| `lastSyncSeverity` | rule changed | not synced → `.notSynced`; estimate 0/1/≥2 → `.low`/`.medium`/`.high`; no estimate → day-based rule, unchanged |

Both are set by `sourceEntryState(now:)` and `apply(_:now:)` through one shared mapping.
