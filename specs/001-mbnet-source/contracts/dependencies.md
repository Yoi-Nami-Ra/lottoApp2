# Contract: Dependency Seams (internal interfaces)

The internal "API" of this feature is the set of swift-dependencies seams. Each is a struct of `@Sendable`
closures conforming to `DependencyKey`, exposed via `DependencyValues`, consumed with `@Dependency`
(Principle IV). Signatures below are the contract; live implementations live one layer inward of their
declaration.

## NEW — `NetworkClient` (Data)

```swift
nonisolated struct NetworkClient: Sendable {
    var data: @Sendable (URL) async throws -> Data
}
```
- **liveValue**: `URLSession` with `timeoutIntervalForRequest = 15`; throws on transport error and on non-2xx
  HTTP status (checked against `HTTPURLResponse.statusCode`).
- **test/preview**: overridden per test — canned `Data`, injected errors, or timeouts. No `testValue` that
  performs I/O.
- `DependencyValues.networkClient`.

## CHANGED — `RemoteSourcesManager` (Data) — implement `.live`

```swift
var listAllSources:      @Sendable () async -> [String]                 // → registered module names, incl. "mbnet"
var listDisplayNamesFor: @Sendable ([String]) async -> [String: String] // name → display name via SourceModule
var sourceFor:           @Sendable (String) async -> RemoteSource        // "mbnet" → RemoteSource with real fetchData
```
- `listAllSources` returns the static `SourceModule` registry names (FR-001) — MBNet present regardless of
  sync history.
- `sourceFor("mbnet")` returns a `RemoteSource` whose `fetchData` uses `@Dependency(\.networkClient)` +
  `MBNetParser` against the MBNet URL constant.

## CHANGED — `LocalStore` (Data) — implement `liveValue`

```swift
var save:              @Sendable ([DrawDTO], RemoteSource) async throws -> Date   // additive-union merge + meta; returns lastSync
var listSourceMetaFor: @Sendable ([String]) async -> [String: SourceMeta]         // read persisted meta
```
- `save` performs the additive-union write path (data-model.md → Persistence schema); uses
  `@Dependency(\.date)` (or `\.continuousClock`/date generator) for `lastSync` so tests are deterministic.
- Note: `save` becomes `async throws` (was `-> Date`). `SorcesRepoImp.fetchAndSaveDataFrom` already runs inside
  a `do/catch` and returns `.failure(.failedToFetchData)` on throw — the signature change slots in there.
- test/preview: in-memory or temp-directory-backed value; never the real Application Support dir.

## UNCHANGED contracts (reference)

```swift
// Domain — SourcesRepo (contract), liveValue = SorcesRepoImp.live
var listKnownSources:     @Sendable () async -> [Source]
var fetchAndSaveDataFrom: @Sendable (String) async -> Result<Source, SourcesRepo.Error>

// Domain — SourcesBLogic (consumed by reducers), liveValue resolves \.sourcesRepo
var knownSources: @Sendable () async -> [Source]
var fetchFrom:    @Sendable (String) async -> Result<Source, SourcesBLogic.Error>
```

## Call flow (one refresh)

```text
SourceEntry.refresh
  └─ .run → blSources.fetchFrom("mbnet")
       └─ sourcesRepo.fetchAndSaveDataFrom("mbnet")
            ├─ remoteSourcesManager.sourceFor("mbnet").fetchData()
            │     └─ networkClient.data(mbnetURL) → MBNetParser.parse → [DrawDTO]   (throws → failure)
            └─ localStore.save(draws, source)  → additive-union merge, write meta, return lastSync
       ⇒ Result<Source, …>  (Source built from merged SourceMeta)
  └─ .refreshResponse(result)
       ├─ .success → replace card analytics (isRefreshing=false)
       └─ .failure → isRefreshing=false, analytics unchanged, present alert
```

## Test override matrix (Principle III/IV — hermetic)

| Test | Overridden seam(s) | Asserts |
|------|--------------------|---------|
| `MBNetParserTests` | none (pure fn) | well-formed→draws, malformed→skipped, empty→[], number range |
| `LocalStoreTests` | temp-dir root + injected date | additive union (no dup, no loss), meta derivation |
| `SourceEntryTests` | `blSources` (.mock success / .failure) | success updates analytics; failure→alert + unchanged; re-tap guarded (FR-020) |
| `SourceBLogicTests` (exists) | `sourcesRepo` | error mapping, knownSources passthrough |
