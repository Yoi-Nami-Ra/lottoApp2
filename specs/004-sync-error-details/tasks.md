---

description: "Task list for spec 004 — specific sync errors (LTA-1)"
---

# Tasks: Specific Sync Errors

**Input**: Design documents from `/specs/004-sync-error-details/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/domain-contracts.md, quickstart.md

**Tests**: Per the constitution (Principle III, Test-First — NON-NEGOTIABLE), every reducer, Domain and Data behaviour change below has its test task placed before its implementation task. Write the test, see it fail (a compile failure counts), then implement.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

Test command used by the checkpoints (from CLAUDE.md):

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests
```

---

## Phase 1: Setup

**Purpose**: Confirm a green baseline, so later failures are this change's own.

- [X] T001 Run the full unit-test suite on branch `004-sync-error-details` and record that it passes before any edit (command above)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Introduce the two Domain failure types and move every seam onto them without changing behaviour yet. Both stories build on the new signatures.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete; the build is red between T003 and T008.

- [X] T002 Create `lottoApp2/Domain/Ents/SourceFailures.swift` with `nonisolated enum SyncFailure: Error, Equatable, Sendable` — cases exactly `offline`, `serverUnreachable`, `serverError(status: Int)`, `unreadableData`, `sourceUnavailable`, `storageFailure`, `unknown`, `cancelled` (doc comment on `cancelled`: "Not a failure: the sync was cancelled. Never shown to the user (FR-007).") — and `nonisolated enum SourceReadFailure: Error, Equatable, Sendable` with cases `sourceUnavailable`, `unreadableStoredDraws` (data-model.md)
- [X] T003 Test first: in `lottoApp2Tests/TestBSources.swift` replace `fetchSourceDataMapsRepoFailure` with a parameterised `@Test(arguments:)` asserting `SourcesBLogic.liveValue.fetchFrom` returns the repo's `.failure(kind)` unchanged for every `SyncFailure` case (use `.serverError(status: 503)`), and replace `gameForMapsRepoFailure` with one asserting `gameFor` passes both `SourceReadFailure` cases through unchanged (FR-002)
- [X] T004 In `lottoApp2/Domain/Repos/SourcesRepo.swift` delete `enum Error` and change `fetchAndSaveDataFrom` to `Result<Source, SyncFailure>` and `gameFor` to `Result<SourceSnapshot, SourceReadFailure>` (contracts §2)
- [X] T005 In `lottoApp2/Domain/BLogic/SourcesBLogic.swift` delete `enum Error`, change `fetchFrom` to `Result<Source, SyncFailure>` and `gameFor` to `Result<SourceSnapshot, SourceReadFailure>`, and return the repo results without `mapError` (drop the `//TODO: re-implement`) — makes T003 pass
- [X] T006 In `lottoApp2/Data/Repos/SorcesRepoImp.swift` keep behaviour but retype: `fetchAndSaveDataFrom` returns `.failure(.unknown)` where it returned `.failedToFetchData` (classification lands in T015); `gameFor` returns `.sourceUnavailable` for an unregistered id and `.unreadableStoredDraws` for a draw that breaks the shape; update `gameFor_anUnknownSource_fails_andHasNoDataState` and `gameFor_aStoredDrawThatBreaksTheShape_fails` in `lottoApp2Tests/SorcesRepoImpTests.swift` to expect those cases
- [X] T007 Retype the reducer actions with behaviour unchanged: `StartPage.Action.refreshResponse` to `Result<Source, SyncFailure>` in `lottoApp2/Presentation/StartPage/StartPage.swift`, and `ChainEditor.Action.gameLoaded` to `Result<SourceSnapshot, SourceReadFailure>` in `lottoApp2/Presentation/ChainEditor/ChainEditor.swift`
- [X] T008 Update the fakes: in `lottoApp2Tests/Reducers/SourceBLogicMocks.swift` make `failureMock` fail with `.unknown` / `.unreadableStoredDraws` and add `static func failing(sync: SyncFailure = .unknown, read: SourceReadFailure = .unreadableStoredDraws) -> SourcesBLogic` (keep `static let failureMock = failing()` so existing call sites compile unchanged); in `lottoApp2/Presentation/Previews/PreviewFixtures.swift` return `.sourceUnavailable` from both `previewMock` failure paths; in `lottoApp2Tests/Reducers/StartPageTests.swift` change `.failure(.somethingWentWrong)` to `.failure(.unknown)`
- [X] T009 Checkpoint: build and run the full suite — green, with the same alerts as before

**Checkpoint**: Every layer speaks `SyncFailure` / `SourceReadFailure`; user stories can begin.

---

## Phase 3: User Story 1 - Understand why a sync failed (Priority: P1) 🎯 MVP

**Goal**: A failed refresh shows a message for its own failure kind (8 messages), a cancelled one shows none, and stored data is untouched.

**Independent Test**: Force each kind (offline, unreachable, 5xx, 4xx, unreadable data, unknown source, save failure) and refresh; each alert names its cause, the card keeps its analytics, and a cancelled sync shows nothing.

### Tests for User Story 1 ⚠️ (write first, see them fail)

- [X] T010 [P] [US1] Create `lottoApp2Tests/Data/SyncFailureClassificationTests.swift`: a parameterised `@Test` over every row of research R3 asserting `SyncFailure(classifying:)` — `CancellationError()` and `URLError(.cancelled)` → `.cancelled`; `URLError(.notConnectedToInternet)`, `URLError(.dataNotAllowed)`, `URLError(.internationalRoamingOff)` → `.offline`; `URLError(.timedOut)`, `URLError(.networkConnectionLost)`, `URLError(.cannotFindHost)`, `URLError(.cannotConnectToHost)` → `.serverUnreachable`; `NetworkClient.Failure.badStatus(503)` → `.serverError(status: 503)` and `badStatus(404)` → `.serverError(status: 404)`; `NetworkClient.Failure.notHTTP` → `.unknown`; `RemoteSourceError.unsupportedSource("x")` → `.sourceUnavailable`; `.undecodableBody` and `.unparseableBody(skipped: 2)` → `.unreadableData`; an unrelated `CocoaError(.fileWriteOutOfSpace)` → `.unknown`
- [X] T011 [P] [US1] In `lottoApp2Tests/SorcesRepoImpTests.swift` (every fetch test sets `$0.remoteSourcesManager = RemoteSourcesManagerImp.live`): tighten `fetchFailsOnNonSuccessStatusAndPersistsNothing` to expect `.failure(.serverError(status: 500))`, `schemaDriftFailsTheSyncAndPersistsNothing` to `.failure(.unreadableData)`, `failedResyncLeavesPriorDataAndMetadataUntouched` to `.failure(.serverError(status: 503))`; add tests, each also asserting draws and meta stayed empty/unchanged: offline (`networkClient` throws `URLError(.notConnectedToInternet)`) → `.offline`; timeout (`URLError(.timedOut)`) → `.serverUnreachable`; non-UTF-8 body (`Data([0xFF, 0xFE])`) → `.unreadableData`; unregistered id `"nope"` → `.sourceUnavailable`; a `LocalStore` whose `save` throws `CocoaError(.fileWriteOutOfSpace)` → `.storageFailure`; a `LocalStore` whose `save` succeeds but `listSourceMetaFor` returns `[:]` → `.storageFailure`; `URLError(.cancelled)` → `.cancelled`
- [X] T012 [P] [US1] In `lottoApp2Tests/Reducers/SourceEntryTests.swift`: update the two `.syncFailed` uses to `.syncFailed(.serverUnreachable, sourceName: "MBNet Server")`; add a test building `AlertState.syncFailed(_, sourceName: "MBNet Server")` for `.offline`, `.serverUnreachable`, `.serverError(status: 503)`, `.serverError(status: 404)`, `.unreadableData`, `.sourceUnavailable`, `.storageFailure`, `.unknown` and asserting all 8 `message`s are pairwise distinct and every `title` is the "Sync failed" title (SC-001, FR-003); add a test building each of the 8 with `sourceName: "A"` and with `sourceName: "B"` and asserting the message changes for `.serverUnreachable`, both `.serverError`s, `.unreadableData`, `.sourceUnavailable` and `.unknown`, and stays the same for `.offline` and `.storageFailure` (FR-005)
- [X] T013 [US1] In `lottoApp2Tests/Reducers/StartPageTests.swift`: update the existing `.syncFailed` expectations to `.syncFailed(_, sourceName: "MBNet Server")` (the `seededEntry()` / `Source.mbnetMock` display name) — `refresh_failure_presentsAlertAndKeepsAnalytics` and the selection-survives-failure test with `.unknown`, and `sourcesResponse_preservesInFlightRefreshAndAlert` with `.serverError(status: 503)` so it proves a *specific* message survives a reload (spec Edge Cases → Alert already showing); add a parameterised `refresh_failure_showsTheMessageForItsKind` over the 8 shown kinds using `.failing(sync: kind)` that asserts `isRefreshing = false`, `alert = .syncFailed(kind, sourceName: "MBNet Server")` and unchanged `recordsCount`; add `refresh_cancelled_clearsRefreshingWithoutAnAlert` using `.failing(sync: .cancelled)` asserting only `isRefreshing = false` (FR-007)

### Implementation for User Story 1

- [X] T014 [US1] Create `lottoApp2/Data/Repos/SyncFailureClassification.swift`: `nonisolated extension SyncFailure { init(classifying error: any Error) }` implementing research R3 exactly (every other `URLError` → `.serverUnreachable`; anything unmatched → `.unknown`) — makes T010 pass
- [X] T015 [US1] In `lottoApp2/Data/Repos/SorcesRepoImp.swift` rewrite `fetchAndSaveDataFrom` step-wise per contracts §2: fetch errors → `SyncFailure(classifying:)`; `store.save` throwing `CancellationError` → `.cancelled`, anything else → `.storageFailure`; saved but no meta read back → `.storageFailure`; log `sync failed (\(kind)) — \(error)` on `Logger.sources` (R7, FR-009) — makes T011 pass
- [X] T016 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift` replace `static var syncFailed` with `static func syncFailed(_ failure: SyncFailure, sourceName: String) -> AlertState` choosing the message from contracts §4 (`serverError` uses `status >= 500` for the "try again later" form; `cancelled` falls back to the `unknown` copy defensively), with every string a `fileprivate` `LocalizedStringResource` token (functions where they interpolate `sourceName`/`status`) under `// MARK: - Resources`; the title token stays "Sync failed" — makes T012 pass
- [X] T017 [US1] In `lottoApp2/Presentation/StartPage/StartPage.swift` handle `.refreshResponse`: `.failure(.cancelled)` clears `isRefreshing` and sets no alert; any other `.failure(kind)` sets `alert = .syncFailed(kind, sourceName: entry.name)` — makes T013 pass
- [X] T018 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift` set `mock1a`'s alert to `.syncFailed(.serverUnreachable, sourceName: "MBNet Server")` and add a light and a dark `#Preview` ("… - format changed alert") whose state carries `.syncFailed(.unreadableData, sourceName: "MBNet Server")` (Principle V)
- [X] T019 [US1] Checkpoint: run the full suite — green

**Checkpoint**: User Story 1 is complete and testable on its own (MVP).

---

## Phase 4: User Story 2 - Understand why a chain couldn't run (Priority: P2)

**Goal**: A run whose source draws can't be read says whether the source is unavailable or its stored draws are unreadable.

**Independent Test**: Run a chain against `.failing(read: .sourceUnavailable)` and `.failing(read: .unreadableStoredDraws)`; each ends the run with its own message and keeps the previous results.

### Tests for User Story 2 ⚠️ (write first, see them fail)

- [X] T020 [US2] In `lottoApp2Tests/Reducers/ChainEditorTests.swift` replace `aFailedRead_endsTheRun_keepsThePreviousResults_andAlerts` with a parameterised test over both `SourceReadFailure` cases using `.failing(read: kind)`, expecting `isRunning = false` and `alert = .readFailed(kind, sourceName: source.name)` with results unchanged; add a test that the two `readFailed` messages differ and both keep the "Couldn't run the chain" title (SC-004, FR-008)

### Implementation for User Story 2

- [X] T021 [US2] In `lottoApp2/Presentation/ChainEditor/ChainEditor.swift` replace `static var readFailed` with `static func readFailed(_ failure: SourceReadFailure, sourceName: String) -> AlertState` using the contracts §4 copy as `fileprivate` tokens (replacing `readFailedMessage`), and set it from `.gameLoaded(.failure(let failure))` with `state.source.name` — makes T020 pass
- [X] T022 [US2] In `lottoApp2/Presentation/ChainEditor/ChainEditorView.swift` add `#Preview("Chain - read failed alert - light")` with `.readFailed(.unreadableStoredDraws, sourceName: "MBNet Server")` and `#Preview("Chain - read failed alert - dark")` with `.readFailed(.sourceUnavailable, sourceName: "MBNet Server")`, using the file's existing `.preview(_:alert:)` helper (Principle V)
- [X] T023 [US2] Checkpoint: run the full suite — green

**Checkpoint**: Both user stories work on their own.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T024 [P] Verify no leftovers: `grep -rn -E "somethingWentWrong|failedToFetchData|invalidStoredDraw|unknownSource|TODO: re-implement" lottoApp2 lottoApp2Tests` returns nothing, and no view file shows raw `error` text (FR-009)
- [X] T025 [P] Build the app target (`xcodebuild build -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`) so previews and app code compile, not just tests
- [X] T026 Run the full suite once more and the quickstart.md manual checks that the simulator allows (offline, success still works) — suite green (276/276); manual simulator checks not run: CoreSimulator couldn't boot any device in this session

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: after Setup; T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 (one compile unit, sequential). Blocks both stories.
- **US1 (Phase 3)** and **US2 (Phase 4)**: both need Phase 2 only; they touch disjoint files except `SourceBLogicMocks.swift` (already done in T008), so they may run in either order or in parallel.
- **Polish (Phase 5)**: after the stories you ship.

### Within User Story 1

- T010, T011, T012 in parallel (different files); T013 after T012 (it uses the new `syncFailed(_:sourceName:)` signature).
- T014 → T015 (repo uses the classifier); T016 → T017 → T018 (reducer and previews use the factory).

### Parallel Opportunities

- T010 ∥ T011 ∥ T012.
- Phase 4 ∥ Phase 3 after T009.
- T024 ∥ T025.
- T022 (previews) after T021.

---

## Parallel Example: User Story 1

```bash
Task: "Classification tests in lottoApp2Tests/Data/SyncFailureClassificationTests.swift"      # T010
Task: "Per-kind repo tests in lottoApp2Tests/SorcesRepoImpTests.swift"                         # T011
Task: "Distinct-messages test in lottoApp2Tests/Reducers/SourceEntryTests.swift"               # T012
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 → Phase 2 (all seams typed, behaviour unchanged, suite green).
2. Phase 3 → validate the 8 messages and the silent cancel → shippable.

### Incremental Delivery

1. Foundation → US1 (sync messages, the ticket's core) → US2 (run messages) → Polish.

---

## Notes

- The misspelled filenames `SorcesRepoImp.swift` / `SorcesRepoImpTests.swift` are kept (CLAUDE.md); do not create new misspelled names.
- Never block a thread in a test (CLAUDE.md); these tests are all plain `async` awaits.
- Commit after each phase checkpoint.
- Checkpoints ran on the `My Mac` (Designed for iPad) destination — the iOS simulators wouldn't boot this session. Running them surfaced a host-app bootstrap crash, fixed in `lottoApp2/App/lottoApp2App.swift` (`if !isTesting`).
