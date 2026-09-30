# Research: Specific Sync Errors

All Technical Context items were known from the code; nothing was marked NEEDS CLARIFICATION. The
decisions below settle the design questions the spec left to planning.

## R1 — Where the failure types live

- **Decision**: Two Domain entities in `Domain/Ents/SourceFailures.swift`: `SyncFailure` (the sync path)
  and `SourceReadFailure` (the run path). They replace `SourcesRepo.Error` and `SourcesBLogic.Error`,
  which are deleted.
- **Rationale**: FR-002 forbids any layer from widening the failure. When the repo contract, the
  business logic and the reducers share one Domain type, there is nothing left to widen. The two paths
  fail in disjoint ways (7 sync kinds against 2 read kinds), so a single enum would let a reducer handle
  kinds its path can never produce.
- **Alternatives considered**:
  - Keep `SourcesRepo.Error` and map it in `SourcesBLogic`. That adds a second enum and a mapping that
    can drift, and gains nothing.
  - One `SourceFailure` enum for both paths. Rejected: it gives non-exhaustive meaning to the reducers'
    switches.

## R2 — Where classification happens

- **Decision**: A Data-layer function `SyncFailure(classifying: any Error)` in
  `Data/Repos/SyncFailureClassification.swift`. It is called only at the fetch step of
  `SourcesRepoImpl.fetchAndSaveDataFrom`. The save step and the read-back step map their own failures
  to `.storageFailure` at the call site.
- **Rationale**: Classification needs `URLError`, `NetworkClient.Failure` and `RemoteSourceError`,
  which are Data-layer knowledge (Principle I). A store error can't be recognised by its type, because
  `FileManager`/`JSONEncoder` throw `CocoaError`/`EncodingError`, which also appear elsewhere. The step
  that failed decides instead, and the repo knows which step that was.
- **Alternatives considered**:
  - Make `LocalStore.save` throw a typed error. That's a wider change for no user-visible gain.
  - Classify in the Domain. Rejected: it would import Data types into the Domain.

## R3 — The classification table (spec Q2, Q3)

| Thrown at fetch | `SyncFailure` |
| --- | --- |
| `CancellationError`, `URLError(.cancelled)` | `.cancelled` |
| `URLError` `.notConnectedToInternet`, `.dataNotAllowed`, `.internationalRoamingOff` | `.offline` |
| any other `URLError` (timeout, dropped connection, unknown host, refused, TLS…) | `.serverUnreachable` |
| `NetworkClient.Failure.badStatus(n)` | `.serverError(status: n)` |
| `NetworkClient.Failure.notHTTP` | `.unknown` |
| `RemoteSourceError.unsupportedSource` | `.sourceUnavailable` |
| `RemoteSourceError.undecodableBody`, `.unparseableBody` | `.unreadableData` |
| anything else | `.unknown` |

- `notHTTP` → `.unknown`. An `http://` request that yields a non-HTTP response is not something the
  user can act on. The spec's fallback message ("couldn't refresh, try again") is the honest one.
- A `CancellationError` thrown by `store.save` also maps to `.cancelled`, not `.storageFailure`.

## R4 — Cancellation (FR-007)

- **Decision**: `SyncFailure` carries a `.cancelled` case. `StartPage` handles
  `.refreshResponse(.failure(.cancelled))` by clearing `isRefreshing` without raising an alert.
- **Rationale**: TCA already drops a `send` after its effect is cancelled, so today a cancelled refresh
  shows nothing by accident. A cancellation can still reach the reducer, for example a URL task
  cancelled outside the effect. An explicit case makes "no alert" a tested rule rather than a side
  effect of timing. `.cancelled` is not one of FR-001's failure kinds; the contract documents it as "not
  a failure; never shown".
- **Alternatives considered**: Rely on TCA's cancelled-send behaviour alone. Rejected: it can't be tested
  and is fragile.

## R5 — Message selection and copy (FR-003–FR-005, FR-008)

- **Decision**: `AlertState.syncFailed(_ failure: SyncFailure, sourceName: String)` in `SourceEntry.swift`
  and `AlertState.readFailed(_ failure: SourceReadFailure, sourceName: String)` in `ChainEditor.swift`.
  Each builds its message from `fileprivate` `LocalizedStringResource` tokens (functions where they
  interpolate the name or status). The 5xx/4xx split is a `status >= 500` test inside `syncFailed`.
- **Rationale**: This keeps the existing pattern (`removeTitle(_:)` tokens in `ChainEditor`, the
  `AlertState` factories in reducer files). Views stay thin: they still just present `store.alert`.
  The status split is presentation wording, not a business rule, so it doesn't belong in the Domain.
- **Alternatives considered**: A Domain `isRetryable` property. Rejected: only the message uses it today.

## R6 — Test strategy (FR-010, SC-005)

- **Classification**: a parameterised `@Test` over every row of R3 (`lottoApp2Tests/Data`).
- **Repo**: integration tests through `RemoteSourcesManagerImp.live` with a stubbed `networkClient` and a
  temp or in-memory `localStore`. They cover one case per kind (offline, unreachable, 5xx, unreadable
  body, schema drift, unknown source, save throws, read-back missing, cancelled), each asserting the
  exact `SyncFailure` and that nothing was persisted. They also cover the two `gameFor` read kinds.
- **BLogic**: a parameterised pass-through test for every `SyncFailure` and `SourceReadFailure`.
- **Reducers**:
  - A `StartPage` `TestStore` parameterised over every shown kind, asserting `alert = .syncFailed(kind,
    sourceName:)`.
  - One test that `.cancelled` clears `isRefreshing` with no alert.
  - `ChainEditor` tests for both read kinds.
  - A `SourceEntry` test that the 8 sync messages and the 2 read messages are pairwise distinct
    (SC-001, SC-004).
- **Why**: the tests stay hermetic (Principle III/IV). The memory rule applies: repo fetch tests must set
  `remoteSourcesManager = .live`.

## R7 — Logging (FR-009)

- **Decision**: Keep the `Logger.sources` error lines. The failure line logs both the raw error and the
  classified kind (`sync failed (\(kind)) — \(error)`). User copy never includes `error` text.
