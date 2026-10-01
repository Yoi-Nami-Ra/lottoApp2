# UI Contracts: Fetch Button on Never-Synced Sources

These are Presentation-layer contracts only. No Domain or Data contract changes.

## §1 — Reducer state: `SourceEntry`

```swift
enum SyncAction: Equatable { case fetch, refresh }    // new, nested in SourceEntry

@ObservableState struct State {
    // …existing fields, unchanged…
    var syncAction: SyncAction { lastSync == nil ? .fetch : .refresh }   // new, computed
}

enum Action { … }                                     // unchanged: Fetch sends refreshButtonTapped
```

Invariants:

- `syncAction == .fetch` ⇔ `lastSync == nil` (FR-001). It is never stored, so a reload or `apply(_:now:)` re-derives it (FR-002).
- Tapping the button while idle sends `.refreshButtonTapped` for both kinds. It is guarded while `isRefreshing`, as today (FR-005).

## §2 — Alert

```swift
static func syncFailed(_ failure: SyncFailure, sourceName: String, action: SourceEntry.SyncAction) -> AlertState
```

- `.unknown` / `.cancelled` → "Couldn't fetch \(name). Try again." for `.fetch`, and "Couldn't refresh \(name). Try again." for `.refresh` (FR-007).
- Every other failure's message is the same for both kinds (spec 004).

## §3 — Parent: `StartPage`

- `.refreshResponse(.failure(f))` (not `.cancelled`) sets `alert = .syncFailed(f, sourceName: name, action: entry.syncAction)`. The entry's `lastSync` is untouched, so the action stays as tapped (FR-006).
- `.refreshResponse(.success)` → `apply(_:now:)`. A first success turns `syncAction` into `.refresh` (US1-AS4).

## §4 — Views

| | Full card (`SourceEntryView`) | Compact card (`CompactSourceEntryView`) |
| --- | --- | --- |
| Idle, `.fetch` | fetch glyph + "Fetch" | fetch glyph, spoken "Fetch" |
| Syncing, `.fetch` | spinning sync arrows + "Fetching…" | spinning sync arrows, spoken "Fetching" |
| Idle, `.refresh` | refresh arrows + "Refresh" (as today) | refresh arrows, spoken "Refresh" (as today) |
| Syncing, `.refresh` | spinning arrows + "Refreshing…" (as today) | spinning arrows, spoken "Refreshing" (as today) |

- Both variants use the shared `SyncIcon(action:isSyncing:)` and `RefreshButtonStyle` (unchanged colours, border and corners), so the idle/syncing visuals are identical across variants (FR-009).
- The copy and the glyph are tokens in dictionaries keyed by `SyncAction` (FR-008).
- Previews (FR-010): never-synced full and compact cards, idle and fetching, light and dark; plus the full card at the largest accessibility size (US3-AS2).
