# Data Model: Skipped Rows Note

Only the fields this feature adds or changes are listed. Everything else keeps its spec 001 / 003 / 004 shape.

## Data layer

### `FetchedDraws` (`Data/Sources/RemoteSources.swift`)

| Field | Type | Change | Meaning |
| --- | --- | --- | --- |
| `draws` | `[DrawDTO]` | unchanged | Draws that passed the parser. After `validated(against:)`, only draws that also pass the game rules. |
| `skipped` | `Int` | unchanged (doc clarified) | Rows the parser could not read. |
| `invalid` | `Int` | **new**, default `0` | Parsed draws dropped because they break the game rules (R1). |
| `skippedTotal` | `Int` (computed) | **new** | `skipped + invalid`. This is the one count the user sees (FR-003). |

`validated(against: GameType) throws(RemoteSourceError) -> FetchedDraws`:
- It keeps a draw when `Combination(type: gameType.combinationType, elements: numbers mapped to Element)` does
  not throw. A negative number can't be an `Element`, so it fails the count check, the same as `gameFor`.
- It adds the number of dropped draws to `invalid`, and leaves `skipped` as it was.
- It throws `.unparseableBody(skipped: skippedTotal)` when the result has no draws and `skippedTotal > 0` (R2).
- It is idempotent: validating twice gives the same result.

### `SourceMeta` (`Data/Sources/LocalStore.swift`)

| Field | Type | Change | Meaning |
| --- | --- | --- | --- |
| `lastSyncSkipped` | `Int` | **new**, default `0` | `skippedTotal` of the last successful sync. |

- Decoding: `decodeIfPresent(Int.self, forKey: .lastSyncSkipped) ?? 0` (FR-013).
- Written only by `LocalStore.save`, which is the success path. A failed or cancelled sync never writes meta
  (FR-006).

### `LocalStore.save`

`@Sendable ([DrawDTO], RemoteSource, _ asOf: Date, _ skipped: Int) async throws -> Void`. The new last argument
is stored as `SourceMeta.lastSyncSkipped`. The draws merge and the meta derivation are otherwise unchanged.

## Domain layer

### `Source` (`Domain/Ents/Source.swift`)

| Field | Type | Change | Meaning |
| --- | --- | --- | --- |
| `lastSyncSkipped` | `Int?` | **new**, init default `nil` | Records skipped by the last successful sync. `nil` until the first one. |

`SourceMeta.source(displayName:)` sets `lastSyncSkipped: lastSyncSkipped`.

## Presentation layer

### `SourceEntry.State`

| Field | Type | Change | Meaning |
| --- | --- | --- | --- |
| `skippedInLastSync` | `Int?` | **new**, default `nil` | The count shown in the note. `nil` means no note. It is never `0`. |

Mapping rule, used by both `Source.sourceEntryState(now:)` and `SourceEntry.State.apply(_:now:)`:

```text
skippedInLastSync = source.lastSyncSkipped > 0 ? source.lastSyncSkipped : nil     (nil when lastSyncSkipped is nil)
```

## State transitions of the stored count

```text
never synced ──(successful sync, n skipped)──▶ stored = n
stored = m   ──(successful sync, n skipped)──▶ stored = n        (n may be 0 → note hidden)
stored = m   ──(failed / cancelled sync)────▶ stored = m        (unchanged)
stored = m   ──(app relaunch)───────────────▶ stored = m
legacy meta (no field) ──(load)─────────────▶ stored = 0
```
