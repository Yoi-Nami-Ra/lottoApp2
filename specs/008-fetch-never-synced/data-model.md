# Data Model: Fetch Button on Never-Synced Sources

No Domain or persisted model changes. One Presentation-layer value is added.

## SourceEntry.SyncAction (new, Presentation)

```text
enum SyncAction: Equatable { case fetch, refresh }
```

- `fetch`: the source has no successful sync (`lastSync == nil`).
- `refresh`: the source has synced at least once.

## SourceEntry.State.syncAction (new, computed)

- Derived only from `lastSync`: `lastSync == nil ? .fetch : .refresh`. Never stored.

| Event | `lastSync` | `syncAction` |
| --- | --- | --- |
| Never-synced source loaded (`sourceEntryState`) | nil | fetch |
| Synced source loaded | date | refresh |
| First fetch succeeds (`apply`) | nil → date | fetch → refresh |
| First fetch fails or is cancelled | stays nil | stays fetch |
| A later refresh succeeds or fails | stays a date | stays refresh |

- `isRefreshing` is orthogonal: it says whether a sync is running, and `syncAction` says which kind.

## AlertState.syncFailed (changed signature)

- `syncFailed(_ failure: SyncFailure, sourceName: String, action: SourceEntry.SyncAction)`. `action` only affects the `.unknown` / `.cancelled` fallback message.
