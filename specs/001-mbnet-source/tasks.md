---

description: "Task list for Real MBNet Server Source"
---

# Tasks: Real MBNet Server Source

**Input**: Design documents from `/specs/001-mbnet-source/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: REQUIRED. Per the constitution (Principle III, Test-First — NON-NEGOTIABLE), every reducer /
Domain / pure-logic implementation task is preceded by a failing test task authored first (Red → Green).
Live network + disk wiring is validated via `quickstart.md`, not unit tests.

**Testing framework**: swift-testing (`import Testing`, `@Test`, `#expect`) + TCA `TestStore` — matches the
existing suites (see plan.md → Constitution Check deviation).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1 / US2 / US3 (Setup, Foundational, Polish carry no story label)
- Paths are repo-relative.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Enable the plain-HTTP fetch and pin the endpoint.

- [x] T001 [P] Add an App Transport Security exception for host `www.mbnet.com.pl` (`NSAppTransportSecurity` → `NSExceptionDomains` with `NSExceptionAllowsInsecureHTTPLoads`) in the `lottoApp2` target's Info.plist / `INFOPLIST_KEY_*` build settings
- [x] T002 [P] Add the MBNet endpoint URL constant `http://www.mbnet.com.pl/dl.txt` as a `fileprivate`/`static` constant in lottoApp2/Data/Sources/RemoteSources.swift

**Checkpoint**: App may issue a plain-HTTP GET to the MBNet host.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared Data-layer engine (fetch + parse + persist) that BOTH US2 and US3 build on. Placing it
here keeps US2 and US3 independent of each other.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 Extend `DrawDTO` to `{ index: Int, date: Date, numbers: [Int] }`, conform it to `Codable`, `Equatable`, `Sendable`, and reimplement the `latest`/`oldest` array helpers to return max/min by `date` (they currently return `nil`) in lottoApp2/Data/Sources/RemoteSources.swift
- [x] T004 [P] Add the `NetworkClient` dependency — `struct NetworkClient: Sendable { var data: @Sendable (URL) async throws -> Data }`, `DependencyKey` `liveValue` backed by `URLSession` with `timeoutIntervalForRequest = 15` and throwing on non-2xx `HTTPURLResponse`, plus `DependencyValues.networkClient` — in lottoApp2/Data/Sources/NetworkClient.swift
- [x] T005 [P] Write FAILING unit tests for `MBNetParser` per contracts/mbnet-file-format.md (well-formed lines → `DrawDTO`s with index/date/6 numbers; a malformed line → `skipped` incremented, others kept; empty body → `draws == []`; a number outside 1…49 → row skipped) in lottoApp2Tests/MBNetParserTests.swift
- [x] T006 Implement the pure `MBNetParser.parse(_ text: String) -> ParseResult` (manual `DD.MM.YYYY` integer parse → `Date` via a cached UTC `Calendar`; no `DateFormatter`; never throws) in lottoApp2/Data/Sources/MBNetParser.swift — makes T005 pass (depends on T003, T005)
- [x] T007 [P] Write FAILING unit tests for `LocalStore` persistence: two `save`s with overlapping indices produce an additive union (no duplicates, no losses — FR-008); `SourceMeta` derives `recordsCount`/`firstRecrd`/`latestRecord` from the merged set; and an **empty save (0 draws) yields `recordsCount == 0` with `nil` record dates and no crash** (spec Edge Cases → Empty history); use a temp-directory root and an injected date so tests are hermetic — in lottoApp2Tests/LocalStoreTests.swift
- [x] T008 Implement `LocalStore.liveValue` — `Codable` JSON files under Application Support (`sources/<name>/draws.json`, `meta.json`); make `SourceMeta.firstRecrd`/`latestRecord` **optional (`Date?`)**; `save` = load → additive-union merge by `index` → write draws + `SourceMeta` (record dates = merged `min()`/`max()`, `nil` when empty — no force-unwrap), using `@Dependency(\.date)` for `lastSync`, signature becomes `async throws -> Date`; `listSourceMetaFor` reads existing `meta.json`s — in lottoApp2/Data/Sources/LocalStore.swift — makes T007 pass (depends on T003, T007)

**Checkpoint**: Parser and store are green in isolation; user stories can begin.

---

## Phase 3: User Story 1 - See MBNet listed as an available source (Priority: P1) 🎯 MVP

**Goal**: "MBNet Server" always appears in the sources list, even on a fresh install with no synced data.

**Independent Test**: Launch with no stored data → "MBNet Server" is present in a never-synced state (no
count, no dates); no other source's listing changes.

- [x] T009 [P] [US1] Write a FAILING test asserting known sources include a `Source(name: "mbnet", displayName: "MBNet Server")` with empty metadata when nothing is stored (repo-level, overriding `remoteSourcesManager` static list + empty `localStore`) in lottoApp2Tests/SorcesRepoImpTests.swift
- [x] T010 [US1] Fix `mbNetSource.displayName` from `"MBNet"` to `"MBNet Server"` in lottoApp2/Data/Repos/mbnetSourceModule.swift
- [x] T011 [US1] Implement `RemoteSourcesManagerImp.live.listAllSources` and `listDisplayNamesFor` from the static `SourceModule` registry (return registered names incl. `"mbnet"`; map names → display names) in lottoApp2/Data/Sources/RemoteSources.swift — makes T009 pass; confirm FR-010 (other registered sources still listed unchanged)

**Checkpoint**: MBNet is discoverable and listed independent of sync history (US1 shippable as MVP).

---

## Phase 4: User Story 2 - Sync real draw data from MBNet (Priority: P1)

**Goal**: The Refresh button forces a real fetch; the card's analytics update live on success; failures raise
an alert and preserve prior data; re-syncs merge additively.

**Independent Test**: With a reachable server, tap Refresh → button shows "Refreshing…" + rotating icon, then
count/first/latest populate; offline → alert appears and prior analytics are unchanged.

### Tests for User Story 2 (write first, ensure they FAIL)

- [x] T012 [P] [US2] Write a FAILING `SourceEntry` reducer test: sending `.refresh` while `isRefreshing == true` starts no second sync (no additional received `.refreshResponse`) — FR-020 — in lottoApp2Tests/Reducers/SourceEntryTests.swift
- [x] T013 [P] [US2] Write a FAILING `SourceEntry` reducer test: `.refreshResponse(.failure)` sets `isRefreshing = false`, presents `alert`, and leaves all analytics fields unchanged; and `.alert(.dismiss)` clears the alert while analytics stay intact (data-model state transitions) — FR-021/SC-004/SC-010 — in lottoApp2Tests/Reducers/SourceEntryTests.swift
- [x] T014 [P] [US2] Extend the blSources test mock with a `.failure` value to support T013 in lottoApp2Tests/Reducers/SourceBLogicMocks.swift
- [x] T015 [P] [US2] Write a FAILING repo integration test: (a) `SorcesRepoImp.fetchAndSaveDataFrom("mbnet")` with `networkClient` overridden to a canned MBNet body and a temp-dir `LocalStore` returns a `Source` whose count/first/latest match the parsed draws — SC-002; (b) when `networkClient` throws a **non-2xx / transport error**, the call returns `.failure(.failedToFetchData)` and nothing is persisted — FR-006 — in lottoApp2Tests/SorcesRepoImpTests.swift

### Implementation for User Story 2

- [x] T016 [US2] Implement `RemoteSourcesManagerImp.live.sourceFor("mbnet")` to return a `RemoteSource` whose `fetchData` GETs the URL constant via `@Dependency(\.networkClient)`, UTF-8 decodes, and runs `MBNetParser` (throws on transport/status/decode failure) in lottoApp2/Data/Sources/RemoteSources.swift (depends on T004, T006)
- [x] T017 [US2] Update `SorcesRepoImp.fetchAndSaveDataFrom` for the `async throws` `LocalStore.save` and real `latest`/`oldest`-derived `Source` metadata; keep the `do/catch` → `.failure(.failedToFetchData)` path (FR-006) in lottoApp2/Data/Repos/SorcesRepoImp.swift (depends on T003, T008, T016) — makes T015 pass
- [x] T018 [US2] Add alert + refresh-guard to the `SourceEntry` reducer: `@Presents var alert: AlertState<Action.Alert>?`, `case alert(PresentationAction<Action.Alert>)`, `.ifLet`, guard `.refresh` on `isRefreshing`, and set the alert in `.refreshResponse(.failure)` in lottoApp2/Scenes/StartPage/Widgets/SourceEntry.swift — makes T012/T013 pass
- [x] T019 [US2] Rework `SourceEntryView`'s refresh button per Principle V: `LocalizedStringKey` copy `.refresh` / `.refreshing`, label switches to "Refreshing…" while `isRefreshing`, disable the button while refreshing, add the `.alert($store.scope(state: \.alert, action: \.alert))` modifier, and move inline colors/paddings/radii into `fileprivate static` token extensions grouped under `// MARK: - Resources`/`Styles` in lottoApp2/Scenes/StartPage/Widgets/SourceEntryView.swift (FR-017/018/019/021) (depends on T018)
- [x] T020 [P] [US2] Add/refresh `#Preview`s covering light + dark × {idle, refreshing, never-synced, error-alert} in lottoApp2/Scenes/StartPage/Widgets/SourceEntryView.swift (depends on T019)

**Checkpoint**: Full MBNet sync works end-to-end with live card updates, failure alert, and additive re-sync.

---

## Phase 5: User Story 3 - Retain each draw's numbers, not just counts (Priority: P2)

**Goal**: Every stored draw keeps its date and all six numbers; malformed rows are skipped and surfaced.

**Independent Test**: After a sync, stored draws each carry a date + six numbers matching the server; a
malformed row is skipped without failing the sync.

> Note: the fetch/parse/persist engine (Phase 2) already captures and stores the numbers; this phase adds the
> story-specific acceptance tests and the read accessor needed to verify them.

### Tests for User Story 3 (write first, ensure they FAIL)

- [x] T021 [P] [US3] Write a FAILING test: `MBNetParser` preserves all six numbers (each 1…49) per parsed draw and, given a mixed body, skips only the malformed row while returning the correct `skipped` count — FR-003/FR-007 — in lottoApp2Tests/MBNetParserTests.swift
- [x] T022 [P] [US3] Write a FAILING test: `LocalStore` round-trips draw numbers — `save` then read back returns each draw's six numbers intact — FR-004/SC-003 — in lottoApp2Tests/LocalStoreTests.swift

### Implementation for User Story 3

- [x] T023 [US3] Add a `LocalStore` read closure `listDrawsFor: @Sendable (String) async -> [DrawDTO]` (reads `draws.json`) and expose it via the struct so T022 can verify persisted numbers; wire its `liveValue` in lottoApp2/Data/Sources/LocalStore.swift — makes T022 pass

**Checkpoint**: Numbers + dates provably persisted; malformed handling verified.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T024 [P] Performance spot-check: a timed test (or signpost) proving parse + persist of the full-history fixture completes in ≤1s on a typical device — SC-006 — in lottoApp2Tests/MBNetParserTests.swift
- [x] T025 Run the `quickstart.md` validation: live fetch (§2 US1/US2), offline failure + data-intact (§3), and the light/dark × state previews (§5)
  - §5 DONE (2026-08-02): all 12 `SourceEntryView` previews rendered and verified (light/dark × none/medium/severe/empty/refreshing/error-alert). Fixed preview fixtures: `mock1m`/`mock1s` had the same `lastSync` as `mock1n` (never showed yellow/red), and first/latest record dates were inverted.
  - §2 DONE (2026-08-03, iPhone 17 Pro simulator, live server): fresh install → "Not synced"/N/A state; Refresh → "Refreshing…" disabled with spinner; completion → 7380 records, first 27 Jan 1957, latest 18 Jul 2026, live update without relaunch; force-quit + relaunch → analytics restored from disk immediately; second Refresh → count unchanged (no duplication), lastSync timestamp updated.
  - §3 DONE (2026-08-03, via the quickstart's broken-URL variant — unreachable host build, since host-offline would cut the assistant's own link): Refresh → fast transport failure → alert "Sync failed / Couldn't refresh this source. Check your connection and try again. / OK"; button returned to idle; analytics unchanged behind and after the alert; OK dismissed it; failed sync did NOT update the lastSync timestamp. URL reverted afterwards and the real build reinstalled.
- [x] T026 [P] Audit the touched view for any remaining inline literals; confirm all tokens are grouped under `// MARK: - Resources`/`Styles` and no copy/color/spacing literal leaks remain (Principle V) in lottoApp2/Scenes/StartPage/Widgets/SourceEntryView.swift

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (P1)**: no dependencies.
- **Foundational (P2)**: after Setup; BLOCKS all user stories.
- **US1 (P3)**: after Foundational. Independent of US2/US3. *(Actually needs only T003's type presence for compilation; behaviorally independent.)*
- **US2 (P4)**: after Foundational. Independent of US1/US3 (shares only the Foundational engine).
- **US3 (P5)**: after Foundational. Independent of US1/US2.
- **Polish (P6)**: after the user stories being shipped are complete.

### Key task dependencies

- T006 ← T003, T005 · T008 ← T003, T007
- T011 ← T010 (+ T003 for compile) · T009 is Red before T010/T011
- T016 ← T004, T006 · T017 ← T003, T008, T016 · T018 ← (Red T012/T013, T014) · T019 ← T018 · T020 ← T019
- T023 ← T008 (+ Red T022) · T021 extends the T005/T006 parser

### Within each story

- Failing test task(s) precede their implementation (Test-First).
- Data types (T003) precede parser/store; store/manager precede repo; repo precedes reducer wiring; reducer precedes view.

---

## Parallel Opportunities

- **Setup**: T001, T002 together.
- **Foundational**: T004 ∥ T005 ∥ T007 (different files); then T006 (after T005) ∥ T008 (after T007).
- **US2 tests**: T012 ∥ T013 ∥ T014 ∥ T015 before implementation.
- **US3 tests**: T021 ∥ T022.
- Different stories can proceed in parallel once Foundational is done (US1 and US3 are small; US2 is the bulk).

### Parallel example — Foundational test authoring

```bash
Task: "Write failing MBNetParser tests in lottoApp2Tests/MBNetParserTests.swift"      # T005
Task: "Write failing LocalStore tests in lottoApp2Tests/LocalStoreTests.swift"         # T007
Task: "Add NetworkClient dependency in lottoApp2/Data/Sources/NetworkClient.swift"     # T004
```

---

## Implementation Strategy

### MVP first (US1 only)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & validate**: MBNet is listed in a
   never-synced state. Shippable increment (discoverability) even before any real sync.

### Incremental delivery

1. Setup + Foundational → engine ready (parser/store green).
2. + US1 → MBNet listed (MVP).
3. + US2 → real sync, live card updates, failure alert, additive re-sync (the core feature).
4. + US3 → numbers/dates provably retained; malformed handling verified.
5. Polish → perf check + quickstart + token audit.

---

## Notes

- [P] = different files, no incomplete dependency.
- Every reducer/parser/store impl is Green only after its Red test exists (Principle III).
- Keep unit tests hermetic: override `networkClient`, `localStore`, and `date` — never touch real network/disk
  (Principle III/IV).
- US3's persistence of numbers is delivered by the Foundational engine; US3's phase proves it and adds the read
  accessor — this is intentional, not duplication.
- Commit after each task or logical group; stop at any checkpoint to validate a story independently.
