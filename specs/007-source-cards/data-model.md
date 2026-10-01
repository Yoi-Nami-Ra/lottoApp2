# Data Model: Compact and Wide Source Cards

The Domain and Data layers do not change. `Source`, `SourceMeta` and the stores are as they were after spec 005.
The only state change is a Presentation flag.

## SourceEntry.State (Presentation, changed)

| Field | Type | Default | Change | Rule |
| --- | --- | --- | --- | --- |
| `isExpanded` | `Bool` | `false` | **new** | This compact card's details are shown. Only the compact card reads it; the full card ignores it. It is never persisted (FR-010). |
| `id`, `name`, `lastSync`, `lastSyncSeverity`, `firstRecordDate`, `lastRecordDate`, `recordsCount`, `skippedInLastSync`, `isRefreshing`, `isSelected`, `alert` | — | — | unchanged | — |

### Transitions

| Trigger | `isExpanded` |
| --- | --- |
| `Source.sourceEntryState(now:)` (first load, new source) | `false` |
| `SourceEntry.Action.disclosureButtonTapped` | toggled |
| `StartPage` `.sourcesResponse` for a surviving id | copied from the previous entry |
| `StartPage` `.sourcesResponse`, id gone | discarded with the entry |
| `SourceEntry.State.apply(_:now:)` (refresh success) | unchanged |
| refresh failure / cancellation | unchanged |
| `cardTapped`, `refreshButtonTapped`, selection rules | unchanged |
| app relaunch | `false` (state is not stored) |

## SourceEntry.Action (Presentation, changed)

| Case | Change | Effect |
| --- | --- | --- |
| `disclosureButtonTapped` | **new** | `state.isExpanded.toggle()`, `.none`; no delegate |
| `refreshButtonTapped`, `cardTapped`, `delegate`, `alert` | unchanged | — |

## StartPage.State (Presentation, unchanged shape)

No new fields. `.sourcesResponse` adds `isExpanded` to the transient fields it carries over (`isRefreshing`,
`alert`). See research R3.

## Approved design (repository asset)

| Item | Before | After |
| --- | --- | --- |
| `design/proposal/28-source-cards.html` / `.png` | present | removed |
| `design/final/source-cards.html` / `.png` | — | present, updated for the clarifications |
| `.tickets/28.yaml` `designs` / `status` | proposal / `ready` | `[design/final/source-cards.html]` / `done` |
| `.tickets/29.yaml` `designs` / `blocked_by` | `[]` / `[28]` | `[design/final/source-cards.html]` / `[]` |
