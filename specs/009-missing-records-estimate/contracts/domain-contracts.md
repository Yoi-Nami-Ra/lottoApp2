# Contracts: Missing Records Estimate

## §1 — `DrawCadence` (Domain)

```swift
nonisolated struct DrawCadence: Equatable, Sendable {
    let drawsInWindow: Int                       // ≥ 1
    var drawsPerDay: Double { Double(drawsInWindow) / 14 }
    static func measure(drawDates: [Date], calendar: Calendar) -> DrawCadence?
    func missing(since latestRecord: Date, now: Date) -> Int
}
extension Calendar { static let drawWeeks: Calendar }   // Gregorian, UTC, firstWeekday = 2
```

| Input | Result |
| --- | --- |
| `[]` | `nil` |
| earliest draw after `W0 − 14d` | `nil` |
| no draw in `[W0 − 14d, W0)` | `nil` |
| 6 draws in the window | `drawsInWindow == 6` |
| a draw exactly at `W0 − 14d` | counted; history is long enough |
| a draw exactly at `W0` | not counted (it is in the latest week) |
| `missing`, 6 in window, 7 days | 3 |
| `missing`, 6 in window, 1 day | 0 |
| `missing`, `now < since` | 0 |

## §2 — Persistence (Data)

- `LocalStore.save` writes `SourceMeta.drawsInWindow = DrawCadence.measure(merged dates, .drawWeeks)?.drawsInWindow`.
- A failed or cancelled sync writes nothing, so the stored value is unchanged.
- `meta.json` without the key decodes as `nil`.
- `SourceMeta.source(displayName:)` maps it to `Source.cadence`.

## §3 — Card state (Presentation)

| `lastSync` | `cadence` | `latestRecord` | `missingEstimate` | `lastSyncSeverity` |
| --- | --- | --- | --- | --- |
| nil | any | any | nil | `.notSynced` |
| set | nil | any | nil | day-based (unchanged) |
| set | set | nil | nil | day-based |
| set | set | set | n | n = 0 → `.low`, 1 → `.medium`, ≥2 → `.high` |

## §4 — View

The `RecordDateDetail(kind: .latest, date:, missing:)` line is shown only when `missing > 0`. It reads
"~N missing" (locale grouping) with a decorative icon, and VoiceOver hears "about N missing". It appears on
both `SourceEntryView` and `CompactSourceEntryView`.
