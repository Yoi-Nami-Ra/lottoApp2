# Contracts: Skipped Rows Note

## §1 Sync pipeline (Data → Domain)

```text
module.fetchDraws()                      → FetchedDraws(draws, skipped)          // parser only
  .validated(against: module.gameType)   → FetchedDraws(draws′, skipped, invalid) // or throws unparseableBody
SourcesRepoImpl.fetchAndSaveDataFrom
  log warning when skipped > 0 || invalid > 0 (both counts, separately)          // FR-012
  store.save(draws′, source, now, skippedTotal)                                   // FR-002/003/004/005
  → .success(Source(…, lastSyncSkipped: skippedTotal))
```

| Response | Outcome | Stored draws | Stored `lastSyncSkipped` |
| --- | --- | --- | --- |
| all rows valid | success | all | 0 |
| k unreadable rows, rest valid | success | valid ones | k |
| j rule-breaking draws, rest valid | success | valid ones | j |
| k unreadable + j rule-breaking, ≥ 1 valid | success | valid ones | k + j |
| rows present, 0 valid | `.failure(.unreadableData)` | unchanged | unchanged |
| 0 rows (empty body) | success | unchanged (merge of nothing) | 0 |
| transport / status / store failure | `.failure(<kind>)` (spec 004) | unchanged | unchanged |
| cancelled | `.failure(.cancelled)` | unchanged | unchanged |

A rule-breaking draw that has the index of a stored valid draw never reaches `save`, so the stored draw is kept.

## §2 `listKnownSources`

Unchanged, except that `Source.lastSyncSkipped` comes from the stored meta. It is `nil` for a never-synced
source and `0` for legacy meta.

## §3 Card state mapping (Domain → Presentation)

| `Source.lastSyncSkipped` | `SourceEntry.State.skippedInLastSync` | Note |
| --- | --- | --- |
| `nil` | `nil` | hidden |
| `0` | `nil` | hidden |
| `1` | `1` | "1 record skipped in last sync" |
| `n > 1` | `n` | "n records skipped in last sync" (grouped, e.g. "1,204") |

`StartPage` calls `apply(_:now:)` only on `.success`, so on failure the card keeps its note.

## §4 Note tokens (`SourceEntryView`, `// MARK: - Resources`)

| Token | Value |
| --- | --- |
| `ImageType.skippedWarning` | `.system("exclamationmark.triangle.fill")` |
| `Color.skippedNoteIcon` | `.warningYellow` |
| `Color.skippedNoteText` | `.textPrimary` |
| background | `Color.skippedNoteIcon.opacity(colorScheme == .light ? .lightOpacity : .darkOpacity)` |
| `Font.skippedNote` | `.caption` |
| `CGFloat.skippedNoteHPadding` / `VPadding` / `Corners` / `IconSpacing` | 8 / 4 / 8 / 4 |
| `LocalizedStringKey.skippedInLastSync(_:)` | singular / plural, per §3 |

Placement: a full-width row between `headerRow` and `details`. The text has no line limit, and the icon is
hidden from accessibility.
