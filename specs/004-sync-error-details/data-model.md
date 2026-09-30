# Data Model: Specific Sync Errors

No persisted data changes. This feature adds two Domain value types and changes the failure type of four
existing closures.

## `SyncFailure` (Domain/Ents/SourceFailures.swift)

Why a sync of one source did not complete. `nonisolated enum SyncFailure: Error, Equatable, Sendable`.

| Case | Meaning (spec) | Shown |
| --- | --- | --- |
| `offline` | The device reports no connection, cellular data off, or roaming off (US1-AS1, Q3) | yes |
| `serverUnreachable` | Any other transport failure: timeout, dropped connection, unknown host (US1-AS2) | yes |
| `serverError(status: Int)` | The server answered with a non-2xx status (US1-AS3/AS4, FR-004) | yes, message by range |
| `unreadableData` | The body isn't text, or no row reads as a draw (US1-AS5) | yes |
| `sourceUnavailable` | No registered source has this id (US1-AS6) | yes |
| `storageFailure` | Draws couldn't be saved, or the saved details couldn't be read back (US1-AS7, edge case) | yes |
| `unknown` | Anything else (edge case: unrecognised failure) | yes, general message |
| `cancelled` | The sync was cancelled. Not a failure (FR-007) | **never** |

Rules:
- Exactly one case per failed attempt (FR-001). The case is produced once, in the Data layer, and passes
  unchanged through `SourcesRepo` → `SourcesBLogic` → `StartPage` → `SourceEntry` (FR-002).
- `serverError`'s message range: `status >= 500` means "try again later". Anything else, 4xx included,
  means "address may have changed; retrying won't help" (FR-004, Q2).

## `SourceReadFailure` (Domain/Ents/SourceFailures.swift)

Why a source's stored draws couldn't be read for a run.
`nonisolated enum SourceReadFailure: Error, Equatable, Sendable`.

| Case | Meaning (spec) | Replaces |
| --- | --- | --- |
| `sourceUnavailable` | No registered source has this id (US2-AS1) | `SourcesRepo.Error.unknownSource` |
| `unreadableStoredDraws` | A stored draw breaks the source's game shape (US2-AS2) | `SourcesRepo.Error.invalidStoredDraw` |

## Changed signatures

| Closure | Before | After |
| --- | --- | --- |
| `SourcesRepo.fetchAndSaveDataFrom` | `Result<Source, SourcesRepo.Error>` | `Result<Source, SyncFailure>` |
| `SourcesRepo.gameFor` | `Result<SourceSnapshot, SourcesRepo.Error>` | `Result<SourceSnapshot, SourceReadFailure>` |
| `SourcesBLogic.fetchFrom` | `Result<Source, SourcesBLogic.Error>` | `Result<Source, SyncFailure>` |
| `SourcesBLogic.gameFor` | `Result<SourceSnapshot, SourcesBLogic.Error>` | `Result<SourceSnapshot, SourceReadFailure>` |
| `StartPage.Action.refreshResponse` | `Result<Source, SourcesBLogic.Error>` | `Result<Source, SyncFailure>` |
| `ChainEditor.Action.gameLoaded` | `Result<SourceSnapshot, SourcesBLogic.Error>` | `Result<SourceSnapshot, SourceReadFailure>` |

Removed: `SourcesRepo.Error` (`failedToFetchData`, `unknownSource`, `invalidStoredDraw`) and
`SourcesBLogic.Error` (`somethingWentWrong`).

## State transitions (source card)

```
idle ──Refresh──▶ refreshing ──success──▶ idle (analytics updated, alert = nil)
                      │
                      ├──failure(kind ≠ cancelled)──▶ idle + alert(kind)   (analytics unchanged)
                      │                                   └──dismiss──▶ idle
                      └──failure(cancelled)──▶ idle, no alert
```
