# Phase 0 Research: Real MBNet Server Source

All items the spec deferred to planning are resolved below. Each decision names the choice, why, and the
alternatives weighed. No `NEEDS CLARIFICATION` remain.

---

## 1. Persistence mechanism

**Decision**: Local **`Codable` JSON files** behind the existing `LocalStore` dependency — one draws file and
one source-metadata file per source, under the app's Application Support directory (created lazily).

**Rationale**:
- Data is tiny and bounded: ~7,400 records ≈ ~256 KB as served, ≈ well under ~1 MB as JSON. Whole-file
  read/merge/write comfortably meets SC-006 (≤1s) with margin.
- The server always re-serves the **full history**, so there is no incremental/delta complexity that would
  justify a relational store; the write path is "load existing → additive-union merge by index → write".
- Zero new SPM dependencies, no schema/migration machinery, no `ModelContainer`/actor friction.
- Trivially `Sendable` and hermetic: the `LocalStore` dependency is overridden in unit tests with an
  in-memory/temp-dir value, satisfying Principle III (no real disk) and IV.

**Alternatives considered**:
- **SwiftData**: idiomatic for larger/relational/observed data and iOS 17+, but heavy for an append-only
  ~7k-row set; `ModelContainer`/`@Model` actor-isolation fits awkwardly inside a struct-of-closures
  `LocalStore` seam. Rejected as over-engineering at this scale.
- **Core Data**: more boilerplate than SwiftData for the same non-benefit. Rejected.
- **SQLite / GRDB**: powerful querying we don't need yet (numbers aren't displayed or analyzed in this
  feature) and adds a dependency. Rejected; revisit if analytics land.
- **`swift-sharing` `@Shared(.fileStorage)`** (already in the graph): idiomatic Point-Free persistence, but it
  pulls persistence into reducer *state* rather than the Data layer's `LocalStore` seam, blurring the layering
  the constitution mandates (Principle I). Rejected to keep persistence a Data concern; the file format below
  is compatible if a future refactor wants it.

---

## 2. Normalized date representation (FR-012)

**Decision**: Parse each `DD.MM.YYYY` string **once at ingest** by manual integer split (not `DateFormatter`)
and store the draw date as a `Date` built from `DateComponents` via a single cached **UTC `Calendar`** at a
fixed time-of-day (noon UTC, to avoid DST/midnight boundary drift). Stored records hold the `Date`; source
metadata's earliest/latest are the min/max of those `Date`s.

**Rationale**:
- Satisfies FR-012 ("no re-parsing of date strings on every access") — parsing happens once; reads are direct.
- Manual split + `DateComponents` avoids `DateFormatter` allocation/locale overhead, the actual hot cost when
  parsing 7,400 lines; keeps parse+persist under the SC-006 budget.
- `Date` is consistent with the existing `Source` metadata fields (`lastSync`, `firstRecrd`, `latestRecord`
  are all `Date?`) and with `DrawDTO.date`, so no conversion layer is needed for the card analytics.

**Alternatives considered**:
- **Dedicated `struct DrawDate { year, month, day }` (Comparable, Codable)**: marginally more compact and
  self-documenting, but forces conversions to `Date` for the metadata fields and adds a type for no functional
  gain here. Viable future refactor; not needed now.
- **Integer key `yyyymmdd`**: fast to sort but loses direct `Date` interop with existing metadata. Rejected.
- **Keep `DateFormatter`**: simplest to write but the slow path we're explicitly told to avoid. Rejected.

---

## 3. Network transport & timeout (FR-002/FR-006, reliability)

**Decision**: A small injectable `NetworkClient` dependency — `struct NetworkClient { var data: @Sendable (URL)
async throws -> Data }` — with `liveValue` backed by a `URLSession` configured with
`timeoutIntervalForRequest = 15` seconds. Non-2xx responses and transport errors throw and map to a sync
failure. MBNet URL is a fixed constant in the Data layer.

**Rationale**:
- Putting the HTTP GET behind a dependency (Principle IV) makes the manager/repo testable without real network
  and lets tests inject canned bodies, timeouts, and error statuses.
- 15s balances patience on slow mobile networks (256 KB) against not hanging the "Refreshing…" state
  indefinitely; a timeout surfaces as the standard failure path → alert (FR-021).

**Alternatives considered**:
- **10s**: risks false failures on slow/edge connections for a 256 KB payload. **30s**: leaves the button
  spinning too long before the user learns it failed. 15s chosen as the middle ground.
- **Directly using `URLSession.shared` in the repo**: violates Principle IV (not overridable, real network in
  tests). Rejected.

---

## 4. Where the Draw model lives (layering)

**Decision**: Extend the **Data-layer `DrawDTO`** to carry `{ index: Int, date: Date, numbers: [Int] }`
(`Codable`, `Sendable`, `Equatable`) and keep draws entirely within the Data layer. Do **not** introduce a
Domain `Draw` entity in this feature.

**Rationale**:
- Draws are fetched, parsed, and persisted in Data and are **not** consumed by Domain or Scenes in this change
  (numbers are not displayed). Adding a Domain entity with no inner-layer consumer would be speculative
  structure the constitution's simplicity/governance rules discourage.
- Layering is preserved: Data owning its own DTOs is legal; Domain does not reference `DrawDTO`.

**Alternatives considered**:
- **Promote `Draw` to `Domain/Ents`**: the right move *when* a Domain/UI consumer appears (analytics, a draw
  list). Deferred to that feature; the spec's "Draw record" key entity maps to `DrawDTO` for now (documented in
  data-model.md).

---

## 5. Static registration of MBNet (FR-001)

**Decision**: Use the existing `SourceModule` registry (`Data/Repos/mbnetSourceModule.swift`) as the static
source list. `RemoteSourcesManagerImp.live.listAllSources` returns the registered module names (incl.
`"mbnet"`); `listDisplayNamesFor` maps names→display names via the modules. Fix `mbNetSource.displayName`
from `"MBNet"` to **"MBNet Server"** to match the spec and mocks.

**Rationale**: A source appears in the list independent of whether it has ever synced (FR-001) because listing
is driven by the static registry, not by stored data. Reuses a structure already in the repo.

**Alternatives considered**: Hard-coding the list inside the manager closure (less discoverable) — rejected in
favor of the existing `SourceModule` seam.

---

## 6. Failure surfacing — alert (FR-021, clarified 2026-07-30)

**Decision**: `SourceEntry` gains `@Presents var alert: AlertState<Action.Alert>?` and
`case alert(PresentationAction<Action.Alert>)`. On `.refreshResponse(.failure)`: set `isRefreshing = false`,
leave all analytics fields untouched, and present the alert. Dismissal clears the alert; card stays idle with
prior data.

**Rationale**: The clarified UX (alert dialog). TCA-native (`AlertState`/`PresentationAction`), fully
assertable in a `TestStore`, per-source, and replaces the current `// TODO: implement unhappy path`.

**Alternatives considered**: inline card error / toast — rejected during `/speckit-clarify` (see spec
Clarifications 2026-07-30).

---

## 7. Refresh-in-progress guard (FR-020)

**Decision**: In the `.refresh` handler, `guard state.isRefreshing == false else { return .none }` before
starting the effect; additionally the view disables the button while `isRefreshing`. This prevents a second
concurrent sync of the same source.

**Rationale**: Cheap pure-state guard; deterministically testable (send `.refresh` twice, assert only one
effect/received action). Belt-and-suspenders with the disabled button for UX.

---

## 8. Testing strategy alignment

**Decision**: Follow the codebase's **swift-testing** (`import Testing`) + TCA `TestStore` convention. Unit
tests cover: the pure `MBNetParser`, the `LocalStore` additive-union merge (temp-dir FileManager, no shared
disk state), and `SourceEntry` reducer behaviors. Live network+parse wiring is exercised by
[quickstart.md](./quickstart.md), not unit tests.

**Rationale**: Consistency with existing suites and CLAUDE.md's "follow the code" directive; keeps unit tests
hermetic per Principle III/IV.
