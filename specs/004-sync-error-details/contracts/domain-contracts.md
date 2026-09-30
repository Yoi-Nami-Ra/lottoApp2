# Contracts: Specific Sync Errors

## 1. Domain types

```swift
nonisolated enum SyncFailure: Error, Equatable, Sendable {
    case offline
    case serverUnreachable
    case serverError(status: Int)
    case unreadableData
    case sourceUnavailable
    case storageFailure
    case unknown
    /// Not a failure: the sync was cancelled. Never shown to the user (FR-007).
    case cancelled
}

nonisolated enum SourceReadFailure: Error, Equatable, Sendable {
    case sourceUnavailable
    case unreadableStoredDraws
}
```

## 2. Repository contract (`SourcesRepo`, Domain/Repos)

```swift
var fetchAndSaveDataFrom: @Sendable (String) async -> Result<Source, SyncFailure>
var gameFor: @Sendable (String) async -> Result<SourceSnapshot, SourceReadFailure>
```

`SourcesRepoImpl.live.fetchAndSaveDataFrom` guarantees:

| Step that fails | Result |
| --- | --- |
| `remotes.sourceFor(id).fetchData()` throws | `.failure(SyncFailure(classifying: error))`, per research R3 |
| `store.save` throws `CancellationError` | `.failure(.cancelled)` |
| `store.save` throws anything else | `.failure(.storageFailure)` |
| saved, but `listSourceMetaFor` has no entry for the source | `.failure(.storageFailure)` |

In every failure row, nothing new is stored: the fetch step fails before `save`, and `save` writes
atomically (FR-006).

`gameFor` returns `.sourceUnavailable` for an unregistered id and `.unreadableStoredDraws` when a stored
draw breaks the game shape.

## 3. Business logic (`SourcesBLogic`, Domain/BLogic)

```swift
var fetchFrom: @Sendable (String) async -> Result<Source, SyncFailure>
var gameFor: @Sendable (String) async -> Result<SourceSnapshot, SourceReadFailure>
```

Both are pure pass-throughs of the repo result, with no `mapError` (FR-002).

## 4. UI contract: alert copy

`SourceEntry` alert, title **"Sync failed"** (unchanged). `{name}` is the source's display name.

| `SyncFailure` | Message |
| --- | --- |
| `offline` | Your device appears to be offline. Check your connection and try again. |
| `serverUnreachable` | Couldn't reach {name}. Try again later. |
| `serverError(s)`, s ≥ 500 | {name} reported a problem (error {s}). Try again later. |
| `serverError(s)`, s < 500 | {name} answered with error {s}. Its address may have changed, so retrying won't help until the app is updated. |
| `unreadableData` | {name} sent data in a format this app doesn't recognise. Retrying won't help until the app is updated. |
| `sourceUnavailable` | {name} is no longer available. |
| `storageFailure` | The downloaded draws couldn't be saved on this device. Free up some space and try again. |
| `unknown` | Couldn't refresh {name}. Try again. |
| `cancelled` | *(no alert — `StartPage` never builds one; the factory maps it to the `unknown` copy only as a defensive fallback)* |

`ChainEditor` alert, title **"Couldn't run the chain"** (unchanged).

| `SourceReadFailure` | Message |
| --- | --- |
| `sourceUnavailable` | {name} is no longer available. |
| `unreadableStoredDraws` | {name}'s stored draws couldn't be read. Refresh the source and try again. |

All copy is held in `fileprivate` `LocalizedStringResource` tokens under `// MARK: - Resources`
(Principle V).
