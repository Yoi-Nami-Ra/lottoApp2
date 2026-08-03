# Phase 1 Data Model: Real MBNet Server Source

Maps the spec's Key Entities to concrete types and the on-disk persistence schema. Types are grouped by layer;
the dependency direction (Scenes → Domain → Data) is preserved.

---

## Domain layer (existing, unchanged)

### `Source` — `Domain/Ents/Source.swift`

The lottery source as seen by Domain/Scenes. Unchanged by this feature.

| Field | Type | Notes |
|-------|------|-------|
| `name` | `String` | Stable identifier (`"mbnet"`). Primary key across the app. |
| `displayName` | `String` | `"MBNet Server"`. |
| `lastSync` | `Date?` | Nil until first successful sync. |
| `recordsCount` | `Int?` | Total stored draws. |
| `latestRecord` | `Date?` | Newest draw date. |
| `firstRecrd` | `Date?` | Oldest draw date. (Pre-existing spelling; do not rename.) |

Empty-metadata `Source` (only `name`/`displayName`) = the "never synced" card state (FR-001, US1).

---

## Data layer

### `DrawDTO` (EXTENDED) — `Data/Sources/RemoteSources.swift`

The atomic fetched/parsed/stored draw. **Maps the spec's "Draw record" key entity** (kept in Data; see
research.md §4). `Codable`, `Sendable`, `Equatable`.

| Field | Type | Validation / Notes |
|-------|------|--------------------|
| `index` | `Int` | Ordinal position in MBNet history (≥ 1). **De-duplication key** (dates are not unique). |
| `date` | `Date` | Parsed once from `DD.MM.YYYY` (research.md §2). |
| `numbers` | `[Int]` | Exactly 6 values, each 1…49 (Polish Lotto 6/49). A row failing this is *malformed* → skipped (FR-007). |

Current stub fields to replace: `DrawDTO` today holds only `date`, and the array extension
`latest`/`oldest` return `nil` — reimplement to return max/min by `date` so `SorcesRepoImp` derives real
`firstRecord`/`latestRecord`.

**Identity & uniqueness**: `index` is unique (verified: 0 duplicate indices in 7,380 rows). `date` is NOT
unique (6,424 distinct dates / 7,380 rows). De-dup and merge key = `index`.

**Validation rules** (parser, FR-003/FR-007):
- Well-formed line matches `^\d+\.\s\d{2}\.\d{2}\.\d{4}\s\d+(,\d+){5}$`.
- 6 numbers, each within 1…49; index parses as `Int`; date parses to a valid calendar date.
- Any line failing these is skipped and counted; parsing continues (partial success).

### `RemoteSource` (SHAPE CHANGE) — `Data/Sources/RemoteSources.swift`

Describes one remote source and how to fetch it. Gains an injected fetch closure so the live MBNet fetch is
real while tests substitute canned data.

| Field | Type | Notes |
|-------|------|-------|
| `name` | `String` | `"mbnet"`. |
| `displayName` | `String` | `"MBNet Server"`. |
| `fetchData` | `@Sendable () async throws -> [DrawDTO]` | Live: GET the MBNet URL via `NetworkClient`, decode UTF-8, run `MBNetParser`. Throws on transport/status/undecodable body → sync failure. |

### `SourceMeta` (persisted) — `Data/Sources/LocalStore.swift`

Persisted source-level analytics (FR-011). Already defined; becomes `Codable`. A `SourceMeta` exists only
after a successful sync; its absence = never synced. The two **record-date** fields are **optional** so an
**empty history** (a successful sync returning 0 draws) is representable — count 0 with no dates (spec Edge
Cases → *Empty history*). This also matches `Source`'s optional `firstRecrd`/`latestRecord`.

| Field | Type | Derivation |
|-------|------|-----------|
| `name` | `String` | Source id. |
| `displayName` | `String` | From the source. |
| `lastSync` | `Date` | Timestamp of the successful sync (injected clock — see contracts). Always set on success. |
| `recordsCount` | `Int` | Count of stored draws after merge (may be 0). |
| `latestRecord` | `Date?` | Max stored draw date; `nil` when `recordsCount == 0`. |
| `firstRecrd` | `Date?` | Min stored draw date; `nil` when `recordsCount == 0`. |

`SourceMeta.toSource` (exists) maps → `Source` for the card.

---

## Persistence schema (on disk)

Behind `LocalStore`, under Application Support (`…/MBNet/`). Two `Codable` JSON documents per source, keyed by
source `name`:

```text
<AppSupport>/sources/<name>/draws.json   →  [DrawDTO]           // full stored set, sorted by index
<AppSupport>/sources/<name>/meta.json    →  SourceMeta          // latest analytics
```

**Write path (`LocalStore.save(draws, source)`), additive union (FR-008):**
1. Load existing `draws.json` (empty if absent).
2. Merge by `index`: incoming draws upsert (add new, replace same-index); **existing indices absent from the
   incoming set are retained** (never deleted).
3. Persist merged set (sorted by `index`) to `draws.json`.
4. Compute `SourceMeta` from the merged set: `recordsCount = merged.count`; `firstRecrd = merged.map(\.date).min()`
   and `latestRecord = merged.map(\.date).max()` (both **`nil` when the merged set is empty** — no force-unwrap of
   an empty min/max); `lastSync = now` (injected clock); write `meta.json`.
5. Return `lastSync`.

**Read path (`LocalStore.listSourceMetaFor(names)`):** load each `meta.json` that exists → `[name: SourceMeta]`
(missing files simply absent from the map = never-synced).

**Failure atomicity**: On a failed fetch nothing is written (the write path is only reached on decode success),
so prior `draws.json`/`meta.json` are untouched (SC-004, FR-006).

---

## Scenes layer

### `SourceEntry.State` (EXTENDED) — `Scenes/StartPage/Widgets/SourceEntry.swift`

Existing fields (`id`, `name`, `lastSync`, `firstRecordDate`, `lastRecordDate`, `recordsCount`,
`isRefreshing`) unchanged. Add:

| Field | Type | Notes |
|-------|------|-------|
| `alert` | `@Presents AlertState<Action.Alert>?` | Present on refresh failure (FR-021). `Equatable`. |

### `SourceEntry.Action` (EXTENDED)

Existing `refresh`, `refreshResponse(Result<Source, SourcesBLogic.Error>)`. Add:

| Case | Payload | Notes |
|------|---------|-------|
| `alert` | `PresentationAction<Alert>` | `enum Alert {}` (dismiss-only) or with a retry case if desired later. |

**State transitions** (SourceEntry):

```text
idle ──refresh (guard !isRefreshing)──▶ refreshing (isRefreshing=true)
refreshing ──refreshResponse(.success)──▶ idle (analytics replaced from Source, isRefreshing=false)
refreshing ──refreshResponse(.failure)──▶ idle+alert (analytics unchanged, isRefreshing=false, alert set)
refreshing ──refresh (guard)──▶ refreshing (ignored, no 2nd effect)   // FR-020
*+alert ──alert(.dismiss)──▶ idle (alert=nil)                         // FR-021
```
