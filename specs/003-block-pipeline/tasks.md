---

description: "Task list for the processing block pipeline (spec 003, LTA-8)"
---

# Tasks: Processing Block Pipeline

**Input**: Design documents from `/specs/003-block-pipeline/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R16), data-model.md, contracts/domain-contracts.md, quickstart.md

**Tests**: Per the project constitution (Principle III, Test-First — NON-NEGOTIABLE), reducer and Domain business-logic tasks MUST include `TestStore`/unit test tasks authored before their implementation. The generic "tests optional" default does NOT apply to this project for those units. Tests use **swift-testing** (`import Testing`, `@Test`, `#expect`), reducer tests are `@MainActor @Test` with every reached dependency overridden, and no test touches real disk (temp directories only) or network.

**Organization**: Tasks are grouped by user story (US1–US8 from spec.md) so each story can be implemented and tested independently. Each task names the ticket it delivers in `(LTA-n)` so the work maps onto the spec's Delivery Map.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1–US8)
- Every task names its exact file path

## Conventions for every task

- Non-UI types are `nonisolated` (the target defaults to `MainActor`), `Sendable`, `Equatable`/`Hashable`, and `Codable` where persisted (data-model.md).
- New Domain files must not import or reference anything in `lottoApp2/Data/` (Principle I).
- New collaborators are struct-of-`@Sendable`-closures + `DependencyKey` (`liveValue`, `previewValue`, `testValue` built from `unimplemented(...)`) + a `DependencyValues` accessor (Principle IV).
- Reducers obtain ids and time only from `@Dependency(\.uuid)` and `@Dependency(\.date)` — never `UUID()` / `Date()` — so `TestStore` assertions are exact.
- Alerts are `AlertState` static builders in `extension AlertState where Action == <Feature>.Action.Alert`, with text from `TextState(.token)` tokens — the `SourceEntry.syncFailed` pattern in `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift:77` (research R16). No inline copy in reducers.
- Freshness is always judged against **the stamp's own source** through a `[String: SourceDataState?]` lookup, never against the chosen source alone (research R13).
- Summaries are data (`ValueSummary` from `ResultSummary.summary(of:)`); views only map a `ValueSummary` case to a token (research R14).
- Views are thin and take every colour/font/spacing/radius/opacity/image/copy value from `fileprivate static` tokens under `// MARK: - Resources` at the bottom of the file, and ship light **and** dark `#Preview`s for each listed state (Principle V; pattern in `lottoApp2/Presentation/BlocksPage/BlocksPageView.swift`).
- The Xcode project uses file-system synchronized groups: new files and folders join their target with no `project.pbxproj` edit.
- Test command: `xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests` (single suite: `-only-testing:lottoApp2Tests/<SuiteStruct>`).
- Spelling: `suffix`, never "sufix"; do not create new files with the `Sorces…` misspelling — only edit the existing `SorcesRepoImp.swift` / `SorcesRepoImpTests.swift`.

## Path Conventions

Single iOS app target: sources under `lottoApp2/` (`App/`, `Presentation/`, `Domain/`, `Data/`), tests under `lottoApp2Tests/`. New test folders `lottoApp2Tests/Domain/` and `lottoApp2Tests/Data/` per plan.md.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: A known-green baseline and a working branch.

- [ ] T001 Create and check out branch `003-block-pipeline` from `main` (it does not exist locally or on the remote yet); all following work lands there
- [ ] T002 Run the full unit-test command above on the untouched tree and confirm it is green; if anything is red, stop and fix it before starting Phase 2 so later failures are attributable to this feature

**Checkpoint**: Baseline green on the feature branch.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The engine every story runs on — draw entities (LTA-6), pipeline value types, the chain model and its pure rules plus the runner (LTA-19), source data state (LTA-30), the source → `Game` read path, and chain persistence (LTA-31, chains only). Count Unique Elements is the only `Block` case at this point; every later story adds its own cases.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Draw entities (LTA-6)

- [ ] T003 [P] Write failing tests in `lottoApp2Tests/Domain/CombinationTests.swift` (`struct CombinationTests`): `CombinationType(pick:pool:)` throws `.invalidType` unless "1 ≤ x ≤ y"; `Combination(type:elements:)` throws `.wrongCount(expected:got:)` when not "exactly x elements", `.duplicate(e)` on a repeated element, `.outOfPool(e)` for `0` and for `y + 1` ("each in 1…y"); elements are stored strictly ascending whatever the input order; `{1, 5, 9} == {9, 1, 5}` with equal `hashValue` (FR-001); `Comparable` compares element by element (`[1,2,9] < [1,3,4]`); `Game(type:entries:)` throws `.mixedShapes` when any entry's combination type differs from `type.combinationType` (FR-002); a `Combination` and a `Game` survive a JSON encode/decode round trip, and decoding a combination with a duplicate element fails instead of producing an invalid value
- [ ] T004 Implement `lottoApp2/Domain/Ents/Draws.swift` to pass T003: `typealias Element = UInt`; `CombinationType { pick: Int, pool: Int }`; `Combination { type, elements: [Element] }` with a `throws(DomainError)` init and a custom `init(from:)` that routes through it; `Comparable` over `elements`; `GameEntry { index: Int, date: Date, combination: Combination }`; `GameType { id: String, name: String, combinationType: CombinationType }`; `Game { type: GameType, entries: [GameEntry] }` with a `throws(DomainError)` init; `DomainError` with `.invalidType`, `.wrongCount(expected: Int, got: Int)`, `.duplicate(Element)`, `.outOfPool(Element)`, `.mixedShapes` (`.invalidSubCombinationSize` is added in US7). All `nonisolated`, `Sendable`, `Hashable`, `Codable`
- [ ] T005 [P] Create the hand-computed reference set in `lottoApp2Tests/Domain/ReferenceDraws.swift` (`nonisolated enum ReferenceDraws`), each fixture with its expected answers as literals beside it: `threeOfFive` = draws {1,2,3}, {2,3,4}, {3,4,5} (indices 1–3); `lotto` = 12 6-of-49 draws with increasing indices and dates where two draws share a date, element 17 never drawn, the combination {1,5,9,20,33,41} drawn twice (once written as {41,33,20,9,5,1}), and one pair drawn in exactly 3 draws; `empty` = a 6-of-49 `Game` with no entries. Also `static func sequential(count:)` building N 6-of-49 draws with index = date order, for the "last 100 of 500" cases (depends on T004)

### Pipeline value types

- [ ] T006 [P] Write failing tests in `lottoApp2Tests/Domain/PipelineValuesTests.swift`: `BlockValue.kind` maps `.draws`/`.counts`/`.number` to `ValueKind`; `CountResult(unordered:)` stores its counts item-ascending regardless of input order (FR-025) so two equal results compare equal; `CountItem.element` orders ascending; a `UniqueCount` with `count < 1` is rejected ("count ≥ 1", FR-004); `BlockValue` round-trips through JSON
- [ ] T007 Implement `lottoApp2/Domain/Ents/PipelineValues.swift` to pass T006: `ValueKind { draws, counts, number }`; `SortDirection { ascending, descending }`; `CountItem` with only `.element(Element)` for now (`.combination` / `.subCombination` arrive in US7), `Comparable` within a case; `UniqueCount { item: CountItem, count: Int }`; `CountResult { counts: [UniqueCount], ordering: Ordering }` with `Ordering { unordered, byCount(SortDirection) }` and an `init(unordered:)` that sorts item-ascending; `BlockValue { draws(Game), counts(CountResult), number(Int) }` with `var kind: ValueKind`. All `Codable`

### Blocks, chains and their rules (LTA-19)

- [ ] T008 Create `lottoApp2/Domain/Ents/Block.swift`: `enum Block: Hashable, Codable, Sendable` with the single case `countUniqueElements` for now, plus `var accepts: Set<ValueKind>` and `func output(given: ValueKind) -> ValueKind` as exhaustive switches (row: accepts `[.draws]`, outputs `.counts`). Update `lottoApp2/Domain/Ents/ProcessingBlockKind.swift`: add `var defaultBlock: Block` (`.countUniqueElements → .countUniqueElements`) and rewrite its doc comment — it is still the catalogue identity, but a block's I/O now lives in `Block`
- [ ] T009 Create `lottoApp2/Domain/Ents/Chain.swift`: `ChainNode { id: UUID, parentID: UUID?, block: Block }` (`parentID == nil` → directly under the chain's input); `Chain { id: UUID, name: String, revision: Int, nodes: IdentifiedArrayOf<ChainNode> }` with `static func empty(id:name:)` at revision 0; `ChainError { inputMismatch(needs: Set<ValueKind>, got: ValueKind), unknownNode, invalidParameter(String) }`. All `Codable` (`IdentifiedArray` encodes as an array)
- [ ] T010 [P] Write failing tests in `lottoApp2Tests/Domain/ChainRulesTests.swift` (`struct ChainRulesTests`): `outputKind(of: nil) == .draws`; `attaching(.countUniqueElements, under: nil, id:)` returns the chain with the node and that id, revision +1; attaching `.countUniqueElements` under a count node throws `.inputMismatch(needs: [.draws], got: .counts)` and the original chain value is unchanged (FR-015); attaching under an unknown parent throws `.unknownNode`; `updating(_:to:)` bumps revision, throws `.inputMismatch` when the new block does not accept the parent's output, and also throws when the new block's output would no longer be accepted by an existing child; `removingSubtree(_:)` removes the node and every descendant, returns `removed` = that count, bumps revision, throws `.unknownNode` for a missing id (FR-016); `renamed(_:)` changes the name and does **not** bump revision (R4, contracts §1); `children(of:)` keeps insertion order; `path(to:)` returns root → node blocks; `leaves` returns nodes without children
- [ ] T011 Implement `lottoApp2/Domain/BLogic/ChainRules.swift` to pass T010 as `extension Chain` pure functions per contracts §1: `outputKind(of:)`, `attaching(_:under:id:)` (the id comes from the caller's `uuid()`, R16; returns `(Chain, ChainNode.ID)`), `updating(_:to:)`, `removingSubtree(_:)`, `renamed(_:)`, `children(of:)`, `path(to:)`, `leaves`
- [ ] T012 Create `lottoApp2/Domain/Ents/RunResults.swift`: `SourceDataState { recordsCount: Int, latestRecord: Date?, contentDigest: String }`; `SourceSnapshot { game: Game, dataState: SourceDataState }` (what `gameFor` returns, R16); `RunStamp { sourceName: String, sourceDisplayName: String, dataState: SourceDataState, chainRevision: Int }` where `sourceName` is the source's `name` id (e.g. `"mbnet"`, the key `dataStateFor` takes) and `sourceDisplayName` is what screens show, kept so a removed source is still named (R15); `ResultFreshness { current, outOfDate, sourceUnavailable }`; `ValueSummary { draws(count: Int), elements(count: Int), combinations(unique: Int, repeating: Int), subCombinations(unique: Int, size: Int), number(Int), empty(ValueKind) }`; `BlockFailure: Error { overBudget(limit: Int), invalidParameter(name: String), upstreamFailed, cancelled }`; `NodeResult { notRun, running, value(BlockValue, RunStamp), failed(BlockFailure, RunStamp) }`; `RunEvent { nodeFinished(UUID, Result<BlockValue, BlockFailure>), finished }`. All `Equatable`, `Sendable`; `Codable` except `RunEvent`, `SourceSnapshot`, `ResultFreshness` and `ValueSummary` (in-memory only)

### Evaluator and runner (LTA-19, LTA-9)

- [ ] T013 [P] Write failing tests in `lottoApp2Tests/Domain/BlockEvaluatorTests.swift` (`struct BlockEvaluatorTests`) for `.countUniqueElements`: on `ReferenceDraws.threeOfFive` the result is exactly 1→1, 2→2, 3→3, 4→2, 5→1 (US1 AS1); on `ReferenceDraws.lotto` element 17 is absent (US1 AS2) and every count matches the fixture's literal table; on `ReferenceDraws.empty` the result is an empty `.counts` (US1 AS3); the output ordering is `.unordered`, stored item-ascending
- [ ] T014 Implement `lottoApp2/Domain/BLogic/BlockEvaluator.swift` to pass T013: `enum BlockEvaluator` with `static let subCombinationBudget = 5_000_000` (FR-022, one tunable constant) and `static func evaluate(_ block: Block, on input: BlockValue) throws(BlockFailure) -> BlockValue` switching exhaustively on `block`; `countUniqueElements` is one pass over a `[CountItem: Int]` dictionary; counting loops check `Task.isCancelled` and throw `.cancelled` (R6)
- [ ] T015 [P] Write failing tests in `lottoApp2Tests/Domain/ChainRunnerTests.swift` (`struct ChainRunnerTests`) against `ChainRunner.live(evaluate:)` with a spy evaluator (`LockIsolated` call log): exactly one `.nodeFinished` per node, every parent before its children, then `.finished` (FR-018); a node with two children is evaluated once and both receive its output (SC-004, FR-019); when a node's evaluation throws, each descendant finishes `.failure(.upstreamFailed)` and a sibling subtree still finishes `.success` (FR-023); cancelling the consuming `Task` ends the stream with no further events (FR-020); an empty chain emits only `.finished`
- [ ] T016 Implement `lottoApp2/Domain/BLogic/ChainRunner.swift` to pass T015 per contracts §2: `nonisolated struct ChainRunner: Sendable { var run: @Sendable (Chain, Game) -> AsyncStream<RunEvent> }`; `static func live(evaluate: @escaping @Sendable (Block, BlockValue) throws(BlockFailure) -> BlockValue) -> ChainRunner` walks nodes parents-first off the main actor (a detached task feeding the stream, cancelled via `onTermination`), holds each output only for the run, and turns a thrown failure into that node's result; `liveValue = .live(evaluate: BlockEvaluator.evaluate)`, `previewValue = liveValue`, `testValue` unimplemented; `DependencyValues.chainRunner`

### Source data state and the source → Game read path (LTA-30, LTA-6)

- [ ] T017 [P] Write failing tests in `lottoApp2Tests/Data/LocalStoreDigestTests.swift` using `LocalStore.fileBacked(root:)` on a temp directory: the persisted `SourceMeta.contentDigest` is identical when the same draws are saved in a different incoming order or with a draw's numbers in a different order; it changes when one draw's numbers change at the same index while `recordsCount` and `latestRecord` stay the same (R8); it changes when a draw is added; a `meta.json` written without `contentDigest` still decodes (digest `""`)
- [ ] T018 Implement in `lottoApp2/Data/Sources/LocalStore.swift` to pass T017: add `contentDigest: String` to `SourceMeta` with a custom `init(from:)` using `decodeIfPresent ?? ""`; add `nonisolated static func digest(of draws: [DrawDTO]) -> String` — SHA-256 (CryptoKit) hex over one canonical line per index-sorted draw, `"<index>|<date.timeIntervalSince1970>|<numbers sorted ascending, comma-joined>"`; set it in `meta(name:draws:asOf:)` so both `FileStore` and `MemoryStore` stamp it. Update the two `SourceMeta(...)` calls in `lottoApp2Tests/SorcesRepoImpTests.swift`
- [ ] T019 [P] Write failing tests in `lottoApp2Tests/SorcesRepoImpTests.swift` (with `localStore` overridden by `.inMemory()` seeded with draws): `gameFor("mbnet")` returns a `SourceSnapshot` whose `game.type` is the MBNet `GameType` (Lotto, 6 of 49), whose entries map each `DrawDTO` (index, date, numbers) into a `GameEntry`, ordered index-ascending (FR-013), and whose `dataState` is built from the stored `SourceMeta`; a registered but never-synced source returns an empty `Game` and `SourceDataState(recordsCount: 0, latestRecord: nil, contentDigest: LocalStore.digest(of: []))`; an unknown source id returns `.failure(.unknownSource)` from `gameFor` and `nil` from `dataStateFor`; a stored draw that breaks a `Combination` invariant returns `.failure(.invalidStoredDraw)`
- [ ] T020 Add `nonisolated var gameType: GameType { get }` to the `SourceModule` protocol and declare MBNet's as `GameType(id: "lotto-6-49", name: "Lotto", combinationType: 6 of 49)` in `lottoApp2/Data/Repos/mbnetSourceModule.swift`
- [ ] T021 Add `gameFor: @Sendable (String) async -> Result<SourceSnapshot, Error>` and `dataStateFor: @Sendable (String) async -> SourceDataState?` plus `Error` cases `unknownSource` and `invalidStoredDraw` to `lottoApp2/Domain/Repos/SourcesRepo.swift`, and implement both in `lottoApp2/Data/Repos/SorcesRepoImp.swift` (`SourceRegistry.module(for:)` → `localStore.listDrawsFor` + `listSourceMetaFor`) to pass T019 (depends on T018, T020)
- [ ] T022 Add `gameFor` (returning `Result<SourceSnapshot, SourcesBLogic.Error>`) and `dataStateFor` to `lottoApp2/Domain/BLogic/SourcesBLogic.swift` (contracts §3), delegating to `sourcesRepo` and mapping errors to `.somethingWentWrong`; update every construction site with the new closures: `SourcesBLogic.previewMock` in `lottoApp2/Presentation/Previews/PreviewFixtures.swift` (returns a sample `Game`) and `.mock` / `.failureMock` in `lottoApp2Tests/Reducers/SourceBLogicMocks.swift` (`.mock` returns a `SourceSnapshot` of a small 6-of-49 `Game` and a fixed `SourceDataState`; `.failureMock` fails / returns `nil`)

### Chain persistence — chains only (LTA-31)

- [ ] T023 [P] Write failing tests in `lottoApp2Tests/Data/ChainsRepoImplTests.swift` against `ChainsRepoImpl.fileBacked(root:)` on a temp directory: `saveChain` then `listChains` round-trips a chain with nodes; saving the same id replaces it; `listChains` is ordered by name (case-insensitive), id as tie-break; `deleteChain` removes `chains/<id>/` entirely; an unreadable `chain.json` is skipped rather than failing the whole list
- [ ] T024 Create the contract `lottoApp2/Domain/Repos/ChainsRepo.swift` with `listChains`, `saveChain`, `deleteChain` (contracts §4; results and draft closures are added in US8), `liveValue = ChainsRepoImpl.live`, an in-memory `previewValue`, an `unimplemented` `testValue`, and `DependencyValues.chainsRepo`
- [ ] T025 Implement `lottoApp2/Data/Repos/ChainsRepoImpl.swift` to pass T023: `static func fileBacked(root: URL) -> ChainsRepo` over a private `actor ChainStore` writing `chains/<chainID>/chain.json` atomically; `static let live` rooted at `Application Support/lottoApp2/chains/` (same root resolution as `LocalStore.liveValue`)
- [ ] T026 [P] Create `lottoApp2Tests/Reducers/PipelineMocks.swift`: `ChainsRepo.inMemory(seed:)` backed by `LockIsolated` so tests can assert what was saved; `ChainRunner.scripted(_ events: [RunEvent])` and `ChainRunner.controlled()` returning the runner plus an `AsyncStream.Continuation` the test drives (for in-flight/cancel cases); `Chain` fixtures (`.emptyMock`, `.countOnlyMock`) with fixed UUIDs

**Checkpoint**: `CombinationTests`, `PipelineValuesTests`, `ChainRulesTests`, `BlockEvaluatorTests`, `ChainRunnerTests`, `LocalStoreDigestTests`, `SorcesRepoImpTests`, `ChainsRepoImplTests` green; the app still builds and behaves as before.

---

## Phase 3: User Story 1 — Count how often each number was drawn (Priority: P1) 🎯 MVP

**Goal**: From the chosen source, a person opens the Blocks page, starts a new chain, adds Count Unique Elements, runs it, and sees every drawn number with its count (LTA-9 through the chain list and editor — there is no standalone run).

**Independent Test**: With a source seeded from `ReferenceDraws.threeOfFive`, New chain → + Count Unique Elements → Run → open the leaf: the list is exactly 1→1, 2→2, 3→3, 4→2, 5→1; with an empty source the leaf says there is nothing to count.

### Tests for User Story 1 ⚠️ write first, confirm they fail

- [ ] T027 [P] [US1] Rewrite `lottoApp2Tests/Reducers/BlocksPageTests.swift` for the chain list (FR-017), replacing the catalogue tests: `onAppear` → `chainsRepo.listChains` → `chainsLoaded` sets `chains`; `newChainTapped` creates `Chain.empty(id: uuid(), name: <default name>)`, saves it, appends it and presents `editor` for it; `chainTapped(id)` presents `editor` with that chain and the page's source; `renameChain(id, name)` saves the renamed chain with its revision unchanged; `deleteChainTapped(id)` presents the `AlertState` confirmation and confirming calls `deleteChain` and removes the row (the saved-result count and draft join the message in US8); `editor(.presented(.delegate(.chainChanged(chain))))` replaces that row
- [ ] T028 [P] [US1] Create `lottoApp2Tests/Reducers/ChainEditorTests.swift` (`struct ChainEditor_Tests`) with the US1 flow: `onAppear` loads `blSources.dataStateFor(source.id)` into `dataStates[source.id]` (the per-source lookup, R13; saved-result sources join it in US8); `addTapped(parent: nil)` presents `addBlock` with `parentOutput == .draws`; `addBlock(.presented(.delegate(.added(.countUniqueElements))))` attaches with the `uuid` dependency, saves the chain via `chainsRepo.saveChain`, leaves the new node's result absent (reads as not run) and sends `.delegate(.chainChanged)`; `runTapped` sets every node `.running` and `isRunning`, calls `gameFor` and writes the returned `snapshot.dataState` into `dataStates[source.id]` so the lookup and the run's stamp agree, consumes a scripted runner, and each `runEvent(.nodeFinished)` stores `.value(v, RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: <snapshot.dataState>, chainRevision: chain.revision))`; `runEvent(.finished)` clears `isRunning`; `summary(nodeID)` equals `ResultSummary.summary(of:)` of that node's value for **every** node that ran; `nodeTapped` on any node that ran — the leaf **and** an intermediate node (FR-024) — presents `result` with its value, stamp and `freshness == .current`; `nodeTapped` on a not-run node does nothing; `runTapped` on a chain with no nodes does nothing; a `gameFor` failure returns every node to its previous result and presents the `AlertState.readFailed` alert
- [ ] T029 [P] [US1] Create `lottoApp2Tests/Reducers/AddBlockTests.swift` (`struct AddBlock_Tests`): the catalogue step lists `ProcessingBlockKind.allCases`; choosing a kind with no parameters sends `.delegate(.added(kind.defaultBlock))` and dismisses
- [ ] T030 [P] [US1] Create `lottoApp2Tests/Reducers/ResultPageTests.swift` (`struct ResultPage_Tests`): an unordered element count result yields rows item-ascending; an empty count result yields `isEmpty == true` (FR-026); `freshness` and `chainChanged` pass through from state unchanged
- [ ] T031 [P] [US1] Create `lottoApp2Tests/Domain/ResultSummaryTests.swift` (`struct ResultSummaryTests`): `ResultSummary.summary(of:)` of the `threeOfFive` element counts is `.elements(count: 5)`; of an empty count result is `.empty(.counts)` (FR-024, FR-026)

### Implementation for User Story 1

- [ ] T032 [US1] Implement `lottoApp2/Domain/BLogic/ResultSummary.swift` to pass T031: `enum ResultSummary { static func summary(of value: BlockValue) -> ValueSummary }` covering `.counts` of elements and every empty case; later stories add their kinds (R14)
- [ ] T033 [US1] Implement `lottoApp2/Presentation/Results/ResultPage.swift` to pass T030: `@Reducer ResultPage` with `State { value: BlockValue, stamp: RunStamp, freshness: ResultFreshness, chainChanged: Bool = false }` and derived rows/`isEmpty`; actions only for navigation (no effects)
- [ ] T034 [US1] Implement `lottoApp2/Presentation/ChainEditor/AddBlock.swift` to pass T029: `State { parentID: UUID?, parentOutput: ValueKind }`, catalogue step only (the parameter step arrives in US2), `Delegate.added(Block)`, dismiss via `@Dependency(\.dismiss)`
- [ ] T035 [US1] Implement `lottoApp2/Presentation/ChainEditor/ChainEditor.swift` to pass T028: `State { chain, source: ChainSource { id, name }, results: [UUID: NodeResult], dataStates: [String: SourceDataState?], isRunning, runStamp: RunStamp?, @Presents addBlock, @Presents result, @Presents alert: AlertState<Action.Alert>? }` with derived `summary(_ nodeID:) -> ValueSummary?` via `ResultSummary`; actions `onAppear`, `dataStateLoaded`, `addTapped(parent:)`, `addBlock`, `nodeTapped`, `runTapped`, `gameLoaded` (also sets `dataStates[source.id] = snapshot.dataState`), `runEvent`, `result`, `alert`, `delegate(.chainChanged(Chain))`; the run is one `.run` effect `.cancellable(id: CancelID.run, cancelInFlight: true)` that sends `runEvent` per stream element; `.ifLet` for `addBlock`, `result`, `alert`; alert builders in an `AlertState` extension at the bottom of the file
- [ ] T036 [US1] Rewrite `lottoApp2/Presentation/BlocksPage/BlocksPage.swift` to pass T027: `State { sourceID, sourceName, chains: IdentifiedArrayOf<Chain>, @Presents editor: ChainEditor.State?, @Presents alert }`, the actions in contracts §5, the default chain name as a named `String` constant, the delete confirmation as an `AlertState` builder; remove the `blocks` catalogue property and the uninhabited `Action` (depends on T035)
- [ ] T037 [US1] Add sample games, chains (`count-only`), node results and a `ChainsRepo`/`ChainRunner` preview setup to `lottoApp2/Presentation/Previews/PreviewFixtures.swift` for the previews of the views below (fixtures stay out of Domain)
- [ ] T038 [P] [US1] Create `lottoApp2/Presentation/Results/ResultPageView.swift`: element list with each count, a header naming the source (`stamp.sourceDisplayName`) and its data state from the stamp, an empty message "Nothing to count" for an empty result (FR-026), no rank column for an unordered result (FR-025); tokens; previews light/dark × {elements, empty}
- [ ] T039 [P] [US1] Create `lottoApp2/Presentation/ChainEditor/AddBlockView.swift` per `design/proposal/22-add-block-sheet.html` (catalogue step): one row per kind with its label, icon and one-line description tokens (move the `countUniqueElements` label out of `BlocksPageView.swift`); tokens; previews light/dark
- [ ] T040 [US1] Create `lottoApp2/Presentation/ChainEditor/ChainEditorView.swift` per `design/proposal/21-chain-builder.html`: header with chain name and source, the input row with its "+", one row per node with its label and, for every node that ran, its summary from `store.summary(id)` mapped to a token (FR-024: `.elements(count:)` → "N elements"; not run; running spinner) and a tap that opens its result, the Run button (disabled with no nodes, a progress state while `isRunning`), `.sheet` for `addBlock`, `.navigationDestination(item:)` for `result`; the view computes no summary itself (Principle II); tokens; previews light/dark × {empty chain, not run, running, has result}. LTA-21 is still in `refine`: build to the current proposal and list any deviation in the PR
- [ ] T041 [US1] Rewrite `lottoApp2/Presentation/BlocksPage/BlocksPageView.swift` as the chain list: source header (kept), one row per chain (name; swipe to delete; rename), a "New chain" row, empty state, `.navigationDestination(item: $store.scope(state: \.editor, action: \.editor))` → `ChainEditorView`, `.onAppear` → `onAppear`. LTA-32 (chain list design) is still in `refine` with no proposal file: keep the existing BlocksPage tokens/visual language and note it in the PR; previews light/dark × {no chains, several chains, long source name}
- [ ] T042 [US1] Run the unit tests and quickstart §2 step "Top 10" reduced to its US1 part in the simulator (MBNet → Next → New chain → + Count Unique Elements → Run → open the leaf): numbers listed item-ascending with counts; confirm `StartPageTests` still pass unchanged (`BlocksPage.State(sourceID:sourceName:)` is still what `StartPage` builds)

**Checkpoint**: MVP — a saved chain with Count Unique Elements runs against the chosen source and shows its full result.

---

## Phase 4: User Story 2 — Narrow the draws before counting (Priority: P2)

**Goal**: Filters (drop first/last, keep first/last) and draw sorts (by date, by index) that feed a count; blocks with parameters (LTA-24, LTA-25 draw sorts).

**Independent Test**: source (500 sequential draws) → keep last 100 → Count Unique Elements equals a hand count over the last 100 draws; clamping and x = 0 behave per FR-006.

### Tests for User Story 2 ⚠️ write first, confirm they fail

- [ ] T043 [P] [US2] Add filter and draw-sort cases to `lottoApp2Tests/Domain/BlockEvaluatorTests.swift`: on `ReferenceDraws.sequential(count: 500)` `.suffix(100)` keeps exactly the last 100 entries (US2 AS1); on 50 draws `.suffix(100)` keeps all 50, `.dropFirst(100)` keeps none (AS2, AS3), `.prefix(0)` keeps none (AS4), `.dropFirst(0)` keeps all; `.dropLast`/`.prefix` mirror those; each filter applied to a `.counts` value returns `.counts` with the same `ordering`, working on its current order (FR-005); `.sortByDate(.descending)` then `.prefix(10)` gives the ten newest (AS5); equal dates fall back to index ascending in both directions (FR-007); `.sortByIndex(.ascending/.descending)`; sorting an empty `Game` returns an empty `Game`
- [ ] T044 [P] [US2] Add to `lottoApp2Tests/Domain/ChainRunnerTests.swift` an integration case with the live `BlockEvaluator`: chain `suffix(100) → countUniqueElements` on 500 sequential draws equals `countUniqueElements` on the last 100 entries computed directly
- [ ] T045 [P] [US2] Add to `lottoApp2Tests/Domain/ResultSummaryTests.swift`: a `.draws` value of 12 entries summarises as `.draws(count: 12)`; an empty one as `.empty(.draws)`
- [ ] T046 [P] [US2] Add to `lottoApp2Tests/Reducers/AddBlockTests.swift`: choosing a filter pushes the parameter step; `x` accepts only whole numbers ≥ 0 ("a whole number ≥ 0", FR-006) — negative and non-whole input keep Add disabled with a validation message; choosing a sort shows the direction picker defaulting to `defaultBlock`'s direction; confirming sends `.delegate(.added(.suffix(100)))` / `.added(.sortByDate(.descending))`

### Implementation for User Story 2

- [ ] T047 [US2] Add `dropFirst(UInt)`, `dropLast(UInt)`, `prefix(UInt)`, `suffix(UInt)` (accept `[.draws, .counts]`, output = input) and `sortByDate(SortDirection)`, `sortByIndex(SortDirection)` (accept `[.draws]`, output `.draws`) to `lottoApp2/Domain/Ents/Block.swift`; matching cases with `defaultBlock` (`prefix(10)`, `suffix(10)`, `dropFirst(10)`, `dropLast(10)`, `sortByDate(.descending)`, `sortByIndex(.ascending)`) in `lottoApp2/Domain/Ents/ProcessingBlockKind.swift`
- [ ] T048 [US2] Add the `.draws` case to `lottoApp2/Domain/BLogic/ResultSummary.swift` to pass T045
- [ ] T049 [US2] Implement the filters (Swift's clamping `prefix`/`suffix`/`dropFirst`/`dropLast` on `Game.entries` and on `CountResult.counts`) and the stable date/index sorts with their tie-breaks in `lottoApp2/Domain/BLogic/BlockEvaluator.swift` to pass T043–T044
- [ ] T050 [US2] Add the parameter step to `lottoApp2/Presentation/ChainEditor/AddBlock.swift` to pass T046: `path: StackState<Step>`, `draft: Block?`, `validation` state, text entry for `x`, direction for sorts
- [ ] T051 [US2] Add the parameter step (number field for `x`, ascending/descending segmented control) and the new kinds' labels/icons/descriptions to `lottoApp2/Presentation/ChainEditor/AddBlockView.swift`; show each node's parameters in its row label in `lottoApp2/Presentation/ChainEditor/ChainEditorView.swift` (e.g. "Keep last 100", "Sort by date ↓"); map `.draws(count:)` to the "N draws" token; previews light/dark for the parameter step (valid, invalid)
- [ ] T052 [US2] Add a draws result view (index, date, numbers per entry) to `lottoApp2/Presentation/Results/ResultPageView.swift` for leaves that end on a filter or sort; previews light/dark × {draws, empty draws}

**Checkpoint**: "keep last 100 → count" builds, runs and matches the hand count; US1 still green.

---

## Phase 5: User Story 3 — Rank and trim the counts (Priority: P3)

**Goal**: Sort by count with a direction and fixed tie-break, so "count → sort desc → keep first 10" is a top 10 (LTA-25 sort by count).

**Independent Test**: source → Count Unique Elements → sort by count descending → keep first 10 matches a hand-ranked list, ties by item ascending.

### Tests for User Story 3 ⚠️ write first, confirm they fail

- [ ] T053 [P] [US3] Add `.sortByCount` cases to `lottoApp2Tests/Domain/BlockEvaluatorTests.swift`: counts 3→5, 7→5, 12→4 sorted `.descending` give 3, 7, 12 and `.ascending` give 12, 3, 7 (US3 AS1, AS2 — ties item-ascending whatever the direction, FR-008); `ordering` becomes `.byCount(direction)`; an empty count result stays empty
- [ ] T054 [P] [US3] Add to `lottoApp2Tests/Domain/ChainRunnerTests.swift` the SC-006 chain on `ReferenceDraws.sequential(count: 500)`: `suffix(100) → countUniqueElements → sortByCount(.descending) → prefix(10)` equals the ten items obtained by counting the last 100 entries directly and ranking them count-descending, item-ascending on ties — so the `suffix` actually trims (the literal-order tie cases stay in T053)
- [ ] T055 [P] [US3] Add to `lottoApp2Tests/Reducers/ResultPageTests.swift`: a `.byCount` result keeps its order and `isRanked == true` (rank shown); an `.unordered` result is shown item-ascending with `isRanked == false` (US3 AS3, FR-025)

### Implementation for User Story 3

- [ ] T056 [US3] Add `sortByCount(SortDirection)` (accepts `[.counts]`, output `.counts`) to `lottoApp2/Domain/Ents/Block.swift` and its kind with `defaultBlock = .sortByCount(.descending)` to `lottoApp2/Domain/Ents/ProcessingBlockKind.swift`
- [ ] T057 [US3] Implement the stable count sort (count by direction, then `CountItem` ascending) in `lottoApp2/Domain/BLogic/BlockEvaluator.swift` to pass T053–T054
- [ ] T058 [US3] Add `isRanked` and rank numbering to `lottoApp2/Presentation/Results/ResultPage.swift` to pass T055, a rank column in `lottoApp2/Presentation/Results/ResultPageView.swift` shown only when ranked, and the sort-by-count label/icon/description to `lottoApp2/Presentation/ChainEditor/AddBlockView.swift`; previews light/dark × {ranked, unranked}

**Checkpoint**: quickstart §2 step 1 (Top 10) passes end to end.

---

## Phase 6: User Story 4 — Compare branches side by side (Priority: P4)

**Goal**: Add blocks under any node, so one output feeds several children and a single run fills every leaf.

**Independent Test**: input → keep last 50 → count, and input → keep last 100 → count; one run fills both leaves with the same results as each straight chain.

### Tests for User Story 4 ⚠️ write first, confirm they fail

- [ ] T059 [P] [US4] Add to `lottoApp2Tests/Reducers/ChainEditorTests.swift`: `addTapped(parent: <intermediate node id>)` presents `addBlock` with that node's output kind; after adding a second child under the input, one `runTapped` with a scripted runner fills both leaves (US4 AS1); a chain with three leaves ends a run with exactly three leaf results (AS3); `toggleCollapsed(id)` adds/removes the id in `collapsed`
- [ ] T060 [P] [US4] Add to `lottoApp2Tests/Domain/ChainRunnerTests.swift` with the live evaluator: the two-branch chain's leaf values equal those of the two straight chains run separately; the shared parent in `input → suffix(100) → {count, sortByDate → prefix(5)}` is evaluated once (US4 AS2)

### Implementation for User Story 4

- [ ] T061 [US4] Add `collapsed: Set<UUID>` and `toggleCollapsed(UUID)` to `lottoApp2/Presentation/ChainEditor/ChainEditor.swift` and make `addTapped(parent:)` use `chain.outputKind(of:)` for any node, to pass T059
- [ ] T062 [US4] Render the tree in `lottoApp2/Presentation/ChainEditor/ChainEditorView.swift` per `design/proposal/21-chain-builder.html`: depth indentation and branch connectors, a "+" on every node, collapse/expand for nodes with children; previews light/dark × {two branches, collapsed branch}

**Checkpoint**: quickstart §2 step 2 (Branches) passes.

---

## Phase 7: User Story 5 — Only sensible chains can be built (Priority: P5)

**Goal**: The FR-010 compatibility table enforced everywhere: the sheet shows which blocks fit and why others don't; a single number ends a branch (Count All Elements, LTA-26).

**Independent Test**: every (parent kind × block kind) attach is accepted exactly per FR-010 and refused otherwise with the needed kind named; the chain is unchanged on refusal.

### Tests for User Story 5 ⚠️ write first, confirm they fail

- [ ] T063 [P] [US5] Add `.countAllElements` to `lottoApp2Tests/Domain/BlockEvaluatorTests.swift`: on `ReferenceDraws.lotto` it returns `.number(entries × 6)` computed by counting elements, and `.number(0)` on `ReferenceDraws.empty`
- [ ] T064 [P] [US5] Add the exhaustive attach matrix to `lottoApp2Tests/Domain/ChainRulesTests.swift` (SC-002): for parents {input, one node of every `ProcessingBlockKind.allCases.defaultBlock`, each built on the shortest valid chain that reaches it — e.g. `sortByCount` sits under `countUniqueElements`} × blocks {every `defaultBlock`}, `attaching` succeeds iff a **literal expected table written in the test** (not derived from `accepts`) says so — filters under draws or counts; sorts by date/index under draws; sort by count under counts; the three unique counts and count all under draws; nothing under count all (FR-012) — and every refusal is `.inputMismatch(needs:got:)` with the block's accepted kinds and the chain value unchanged (US5 AS1–AS4). Keep the table in step with the kinds US7 adds
- [ ] T065 [P] [US5] Add to `lottoApp2Tests/Reducers/AddBlockTests.swift`: with `parentOutput == .draws` "Sort by count" is unavailable with reason `.needs([.counts])`; with `.counts` "Sort by date" is unavailable with `.needs([.draws])`; selecting an unavailable kind does nothing
- [ ] T066 [P] [US5] Add to `lottoApp2Tests/Reducers/ChainEditorTests.swift`: `addTapped(parent: <count all node>)` presents nothing; an `.added` delegate whose block the rule refuses leaves `chain` unchanged, saves nothing and presents an alert carrying the `ChainError`

### Implementation for User Story 5

- [ ] T067 [P] [US5] Add to `lottoApp2Tests/Domain/ResultSummaryTests.swift`: `.number(42072)` summarises as `.number(42072)`, `.number(0)` as `.number(0)` (a total of 0 is a result, not empty)
- [ ] T068 [US5] Add `countAllElements` (accepts `[.draws]`, output `.number`) to `lottoApp2/Domain/Ents/Block.swift`, its kind to `lottoApp2/Domain/Ents/ProcessingBlockKind.swift`, and its evaluation to `lottoApp2/Domain/BLogic/BlockEvaluator.swift` to pass T063–T064, and the `.number` case to `lottoApp2/Domain/BLogic/ResultSummary.swift` to pass T067
- [ ] T069 [US5] Add per-kind availability (`kind.defaultBlock.accepts.contains(parentOutput)`) with an unavailability reason to `lottoApp2/Presentation/ChainEditor/AddBlock.swift`, and the refusal/terminal handling to `lottoApp2/Presentation/ChainEditor/ChainEditor.swift`, to pass T065–T066
- [ ] T070 [US5] Show unavailable kinds disabled with their reason ("Needs counts", "Needs draws") in `lottoApp2/Presentation/ChainEditor/AddBlockView.swift` per the LTA-22 proposal; hide "+" under a number node in `lottoApp2/Presentation/ChainEditor/ChainEditorView.swift`; add a number result ("Total: 42,072") to `lottoApp2/Presentation/Results/ResultPageView.swift` and map `.number` to its summary token in `ChainEditorView.swift`; previews light/dark × {sheet under input, sheet under counts, number result}

**Checkpoint**: quickstart §2 step 3 (Attach rule) passes; `ChainRulesTests` matrix green.

---

## Phase 8: User Story 6 — Edit, re-run, and stop a long run (Priority: P6)

**Goal**: Editing marks results out of date without re-running; new leaves read not run; a new run replaces one in flight; leaving stops a run (FR-016, FR-020, FR-021).

**Independent Test**: run, change a parameter → every shown result out of date; run again → marks clear with the new parameter's values.

### Tests for User Story 6 ⚠️ write first, confirm they fail

- [ ] T071 [P] [US6] Create `lottoApp2Tests/Domain/FreshnessTests.swift` (`struct FreshnessTests`) for shown results through `freshness(chainRevision:dataStates:)`: a `.value`/`.failed` result is `.outOfDate` iff `stamp.chainRevision != chain.revision` or `stamp.dataState != dataStates[stamp.sourceName]` (data-model "Result freshness"); `.sourceUnavailable` when the lookup has no state for the stamp's source; `.notRun`/`.running` are `.current`; a result stamped with source A stays `.current` when the lookup also holds a *different* state for source B (R13)
- [ ] T072 [P] [US6] Add to `lottoApp2Tests/Reducers/ChainEditorTests.swift`: after a run, `editTapped(id)` presents `addBlock` in edit mode prefilled with the node's block; `.delegate(.edited(id, .suffix(50)))` calls `updating`, saves the chain, and every shown result reads out of date with no run effect started (US6 AS1, SC-005); adding a leaf after a run leaves it not run and marks the others out of date (AS2); `removeTapped` on a node with children presents a confirmation naming how many blocks go, confirming calls `removingSubtree`, saves, and drops the removed nodes' results; on a childless node it removes without asking; a second `runTapped` while the first run is still streaming (controlled runner) cancels the first — no further events from it are received — and only the second run's results land (AS3, FR-020); after the re-run no result is out of date (AS4)
- [ ] T073 [P] [US6] Add to `lottoApp2Tests/Reducers/BlocksPageTests.swift`: with the editor presented and a controlled runner mid-stream, dismissing the editor (`.editor(.dismiss)`) cancels its run — no further `.editor(.presented(.runEvent))` is received — and the chain row is unchanged (spec Edge Cases, research R11: `ifLet` cancels the child's effects, so no explicit cancel code is written)
- [ ] T074 [P] [US6] Add edit mode to `lottoApp2Tests/Reducers/AddBlockTests.swift`: `State(editing: id, block:)` opens on the parameter step prefilled and confirms with `.delegate(.edited(id, block))`; a kind change is not offered in edit mode

### Implementation for User Story 6

- [ ] T075 [US6] Implement `lottoApp2/Domain/BLogic/Freshness.swift` to pass T071: `extension NodeResult { func freshness(chainRevision: Int, dataStates: [String: SourceDataState?]) -> ResultFreshness }` (contracts §1)
- [ ] T076 [US6] Add edit mode to `lottoApp2/Presentation/ChainEditor/AddBlock.swift` to pass T074
- [ ] T077 [US6] Add `editTapped`, `addBlock .edited` handling, `removeTapped` + confirmation alert, derived `freshness(nodeID)` (passed into `ResultPage.State` on `nodeTapped`) to `lottoApp2/Presentation/ChainEditor/ChainEditor.swift` to pass T072 and T073; `editTapped(ChainNode.ID)` is its own action because `nodeTapped` opens any node's result (contracts §5, R16)
- [ ] T078 [US6] Show "out of date" and "not run" states, an edit affordance and the removal confirmation copy per `design/proposal/21-chain-builder.html` in `lottoApp2/Presentation/ChainEditor/ChainEditorView.swift`; show a banner per `freshness` (out of date / source unavailable) in `lottoApp2/Presentation/Results/ResultPageView.swift`; previews light/dark × {out of date, failed, mixed not run / fresh}

**Checkpoint**: quickstart §2 step 4 (Stale) passes.

---

## Phase 9: User Story 7 — Count repeated combinations and sub-combinations (Priority: P7)

**Goal**: Count Unique Combinations (LTA-18) and Count Unique Sub-combinations of size z (LTA-7, LTA-27) with the FR-022 budget.

**Independent Test**: on draws with one repeated combination (different order) and a known shared pair, each block matches a hand count; an over-budget leaf fails alone.

### Tests for User Story 7 ⚠️ write first, confirm they fail

- [ ] T079 [P] [US7] Add to `lottoApp2Tests/Domain/CombinationTests.swift`: `SubCombination(parentType:elements:)` requires "2 ≤ z < x" (else `.invalidSubCombinationSize(z)`), strictly ascending, each in 1…y; equal sub-combinations from different draws are equal; `Combination.subCombinations(size: 2)` of a 6-element combination yields 15 distinct pairs; `CountItem` ordering for `.combination` and `.subCombination` is element by element ascending (add to `lottoApp2Tests/Domain/PipelineValuesTests.swift`)
- [ ] T080 [P] [US7] Add to `lottoApp2Tests/Domain/BlockEvaluatorTests.swift`: `.countUniqueCombinations` on `ReferenceDraws.lotto` counts {1,5,9,20,33,41} as 2 (US7 AS1) and a once-drawn combination as 1 (AS2); `.countUniqueSubCombinations(z: 2)` generates 15 pairs per draw and the fixture's shared pair has count 3 (AS3); `z >= x` of the input throws `.invalidParameter(name: "z")` (FR-011); a 20-of-80 `Game` with 28 entries and `z: 10` (28 × C(20,10) = 5,173,168 > 5,000,000) throws `.overBudget(limit: 5_000_000)` without generating (FR-022)
- [ ] T081 [P] [US7] Add to `lottoApp2Tests/Domain/ChainRunnerTests.swift`: in a chain with an over-budget sub-combination leaf and a Count Unique Elements sibling, the first fails `.overBudget` and the second succeeds (US7 AS5, FR-023)
- [ ] T082 [P] [US7] Add to `lottoApp2Tests/Domain/ChainRulesTests.swift` and `lottoApp2Tests/Reducers/AddBlockTests.swift`: `attaching`/`updating` with `countUniqueSubCombinations(z: 1)` throw `.invalidParameter("z")`; the parameter step refuses z < 2 (US7 AS4 — z < x is checked at run time because a chain is not tied to a source); extend the T064 matrix with the two new kinds
- [ ] T083 [P] [US7] Add to `lottoApp2Tests/Domain/ResultSummaryTests.swift`: a combination count result with 3 items of which 1 has count ≥ 2 summarises as `.combinations(unique: 3, repeating: 1)`; a pair count result with 15 items as `.subCombinations(unique: 15, size: 2)`
- [ ] T084 [P] [US7] Add to `lottoApp2Tests/Reducers/ResultPageTests.swift` (LTA-18): a combination count result is split into one group per occurring count, groups ordered by count descending, combinations within a group ascending by elements, each group showing at most 20 and a "N more" count, with an action that opens the group's full list

### Implementation for User Story 7

- [ ] T085 [US7] Add `SubCombination { parentType: CombinationType, elements: [Element] }` (`throws(DomainError)` init, `Comparable`, `Codable` via the throwing init), `DomainError.invalidSubCombinationSize(Int)` and `Combination.subCombinations(size:)` (index-combination walk) to `lottoApp2/Domain/Ents/Draws.swift`; add `CountItem.combination(Combination)` and `.subCombination(SubCombination)` to `lottoApp2/Domain/Ents/PipelineValues.swift`, to pass T079. Record in `.tickets/7.yaml` that the origin question is settled by data-model.md: a sub-combination keeps only its parent `CombinationType`, not the `GameEntry`
- [ ] T086 [US7] Add `countUniqueCombinations` and `countUniqueSubCombinations(z: Int)` (both accept `[.draws]`, output `.counts`) to `lottoApp2/Domain/Ents/Block.swift`, their kinds (`defaultBlock` z = 2) to `lottoApp2/Domain/Ents/ProcessingBlockKind.swift`, and the z ≥ 2 check to `lottoApp2/Domain/BLogic/ChainRules.swift`
- [ ] T087 [US7] Implement both counts in `lottoApp2/Domain/BLogic/BlockEvaluator.swift` — the z < x check and the `entries × C(x, z) > subCombinationBudget` check run before any generation — to pass T080–T082, and the `.combinations` / `.subCombinations` cases to `lottoApp2/Domain/BLogic/ResultSummary.swift` to pass T083
- [ ] T088 [US7] Add the z parameter to `lottoApp2/Presentation/ChainEditor/AddBlock.swift` and `AddBlockView.swift`; add grouping state to `lottoApp2/Presentation/Results/ResultPage.swift` to pass T084 and the grouped view to `ResultPageView.swift`; map `.combinations` to "N unique, M repeat" and `.subCombinations` to "N unique" tokens, and an over-budget failure message naming the 5,000,000 limit in `ChainEditorView.swift`; previews light/dark × {grouped combinations, sub-combination pairs, over-budget failure}

**Checkpoint**: all of FR-005–FR-012 implemented; SC-001 reference set fully covered.

---

## Phase 10: User Story 8 — Reuse a chain and keep its results (Priority: P8)

**Goal**: Run one chain against any chosen source, save any block's output, keep saved results across launches with correct freshness, warn before unsaved results are lost, and keep a draft on backgrounding (LTA-31 results/drafts, FR-027–FR-032).

**Independent Test**: run a chain on two sources, save an intermediate and a leaf result from each, relaunch, sync one source — only that source's saved results read out of date.

### Tests for User Story 8 ⚠️ write first, confirm they fail

- [ ] T089 [P] [US8] Add saved-result rules to `lottoApp2Tests/Domain/FreshnessTests.swift`: `SavedResult.freshness(dataStates:)` is `.outOfDate` iff `stamp.dataState != dataStates[stamp.sourceName]`, `.sourceUnavailable` iff the lookup has no state for that source; `chainChanged(since:)` iff `stamp.chainRevision != chain.revision`, and a changed chain never makes it `.outOfDate` (FR-030); with results from sources A and B, a changed state for A marks only A's results (SC-007)
- [ ] T090 [P] [US8] Add to `lottoApp2Tests/Data/ChainsRepoImplTests.swift`: `saveResult`/`listResults(chainID)` round-trip a `SavedResult` holding each `BlockValue` kind; `deleteResult` removes only that file; `putDraft` replaces an existing draft; `draft` is `nil` after `deleteDraft`; `deleteChain` also removes its results and draft (FR-017 cascade)
- [ ] T091 [P] [US8] Add to `lottoApp2Tests/Reducers/ChainEditorTests.swift`: `onAppear` also loads `listResults(chain.id)` into `savedResults` and the draft, then calls `dataStateFor` once per distinct source among the chosen source, the saved results and the draft, filling `dataStates` (R13); `savedResultTapped(id)` presents `result` with the saved value, stamp, `freshness` and `chainChanged` (FR-029, FR-030) — a result saved from source A reads `.current` while B is chosen when A's data is unchanged, and `.sourceUnavailable` when A's lookup is `nil`; `saveResultTapped(id)` on a leaf **and** on an intermediate node (US8 AS2) saves `SavedResult(id: uuid(), chainID, nodeID, path: chain.path(to:), value, stamp, savedAt: now)`, appends it and marks the node saved; `deleteSavedResultTapped` deletes it (AS5); with the editor's source set to a second source the stamp's `sourceName` and `sourceDisplayName` are that source's (AS1); `backTapped` with unsaved `.value` results presents Save / Discard / Cancel (AS6, FR-032) — Save saves every unsaved value result then dismisses, Discard deletes the draft and dismisses, Cancel keeps the editor; `backTapped` with nothing unsaved dismisses at once; `scenePhaseChanged(.background)` with unsaved results calls `putDraft(ChainDraft(chainID, results: only .value/.failed, createdAt: now))`, without them calls nothing (FR-031); `onAppear` with a stored draft presents "Restore unsaved results?" — Restore puts the results back and deletes the draft, and a restored result stamped with another source is judged against that source's state, Decline deletes it and leaves leaves not run (AS7); saving or discarding deletes the draft
- [ ] T092 [P] [US8] Add to `lottoApp2Tests/Reducers/BlocksPageTests.swift`: `deleteChainTapped` loads `listResults(id).count` and `draft(id)`; the confirmation names the number of saved results and, only when a draft exists, that unsaved results go too, with no save option (FR-017, FR-032); cancelling keeps the chain, its results and its draft

### Implementation for User Story 8

- [ ] T093 [US8] Add `SavedResult { id: UUID, chainID: UUID, nodeID: UUID, path: [Block], value: BlockValue, stamp: RunStamp, savedAt: Date }` and `ChainDraft { chainID: UUID, results: [UUID: NodeResult], createdAt: Date }` ("only `.value`/`.failed`", "at most one per chain") to `lottoApp2/Domain/Ents/RunResults.swift`
- [ ] T094 [US8] Add `extension SavedResult { func freshness(dataStates:) -> ResultFreshness; func chainChanged(since: Chain) -> Bool }` to `lottoApp2/Domain/BLogic/Freshness.swift` to pass T089 (contracts §1)
- [ ] T095 [US8] Add `listResults`, `saveResult`, `deleteResult`, `draft`, `putDraft`, `deleteDraft` to `lottoApp2/Domain/Repos/ChainsRepo.swift` (incl. `previewValue`), implement them in `lottoApp2/Data/Repos/ChainsRepoImpl.swift` (`chains/<id>/results/<resultID>.json`, `chains/<id>/draft.json`, atomic writes) to pass T090, and extend `ChainsRepo.inMemory` in `lottoApp2Tests/Reducers/PipelineMocks.swift`
- [ ] T096 [US8] Add `savedResults`, `savedNodeIDs`, derived `hasUnsavedResults` (any `.value` node not saved since the last run — failures can't be saved, so they don't trigger the warning but do go into the draft), per-source `dataStates` loading on `onAppear`, `saveResultTapped`, `savedResultTapped`, `deleteSavedResultTapped`, `backTapped` + leave alert, `scenePhaseChanged`, draft restore alert and `delegate(.dismiss)` handling to `lottoApp2/Presentation/ChainEditor/ChainEditor.swift` to pass T091
- [ ] T097 [US8] Load `listResults(id).count` and `draft(id)` in `deleteChainTapped` and build the confirmation from both (`AlertState.deleteChain(savedCount:hasDraft:)`) in `lottoApp2/Presentation/BlocksPage/BlocksPage.swift` to pass T092
- [ ] T098 [US8] In `lottoApp2/Presentation/ChainEditor/ChainEditorView.swift`: hide the system back button and add one that sends `backTapped` (R11 — this also disables swipe-back); observe `@Environment(\.scenePhase)` and send `scenePhaseChanged` (R12); a save action per node with a value; a "Saved results" section listing each with its path, `stamp.sourceDisplayName`, saved date and status (out of date / source unavailable / chain changed since), tapping a row sends `savedResultTapped`; the leave and restore alerts. `ResultPageView` shows the saved result's freshness banner and a "chain changed since" note. Previews light/dark × {saved results in each status, restore prompt}
- [ ] T099 [US8] Add the delete-confirmation copy tokens (saved-result count; the extra unsaved-results line when a draft exists) as `fileprivate static` `LocalizedStringKey` tokens in `lottoApp2/Presentation/BlocksPage/BlocksPage.swift`, next to the `AlertState.deleteChain(savedCount:hasDraft:)` builder from T097 — the `SourceEntry.swift` pattern, where the alert's tokens live in the reducer file — then confirm the `BlocksPageView.swift` previews still render

**Checkpoint**: quickstart §2 steps 5–9 pass.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Consistency, documentation and end-to-end validation.

- [ ] T100 [P] Token audit: grep every new/changed view under `lottoApp2/Presentation/ChainEditor/`, `lottoApp2/Presentation/Results/` and `lottoApp2/Presentation/BlocksPage/` for inline colour/font/number/string literals outside `// MARK: - Resources`, and move any found into tokens
- [ ] T101 [P] Preview audit: confirm each new view has light and dark `#Preview`s for the states plan.md lists (not run, running, fresh, out of date, failed, empty, restore prompt) using `lottoApp2/Presentation/Previews/PreviewFixtures.swift`
- [ ] T102 [P] Layer audit: `grep -rn` in `lottoApp2/Domain/` for any Data type (`DrawDTO`, `LocalStore`, `SourceMeta`, `ChainsRepoImpl`, `SourcesRepoImpl`, `SourceRegistry`, `ChainStore`) other than the `liveValue` bindings, and in `lottoApp2/Presentation/` for any direct Data or `Domain/Repos` use (Presentation reaches data only through `blSources`, `chainRunner`, `chainsRepo`)
- [ ] T103 [P] Update `CLAUDE.md`: the "Domain model & block pipeline" section now describes what is implemented (resolve the TBDs spec 003 settled — the I/O kinds, the chain as a parent-pointer tree, the SubCombination origin), and the "Architecture layout" tree gains `Presentation/ChainEditor/`, `Presentation/Results/`, the new Domain files and `lottoApp2Tests/Domain/` + `lottoApp2Tests/Data/`
- [ ] T104 Run the full unit-test command and confirm every suite in quickstart §1 is green
- [ ] T105 Run quickstart §2 manual checks 1–10 in the simulator against a synced MBNet, timing check 1 from an empty chain to the shown top 10 (SC-006: under 1 minute); while a sub-combination (z = 3) run is in progress on the full history, confirm scrolling, opening another result and starting a new run all respond (SC-003), and record any deviation from the LTA-21/LTA-22 proposals for the PR description
- [ ] T106 [P] Update ticket status in `.tickets/` for LTA-6, LTA-7, LTA-9, LTA-18, LTA-19, LTA-23–LTA-27, LTA-30, LTA-31 to match what landed (via the tickets skill)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: after Setup — BLOCKS every story.
- **US1 (Phase 3)**: after Foundational. It creates `ChainEditor`, `AddBlock`, `ResultPage` and the chain list, which every later story extends.
- **US2–US8 (Phases 4–10)**: after US1. Domain work in each (Block cases, evaluator, rules tests) only needs Foundational; the Presentation work extends the US1 reducers and views.
- **Polish (Phase 11)**: after the stories being shipped.

### User Story Dependencies

| Story | Depends on | Why |
|---|---|---|
| US1 (P1) | Foundational | MVP path: chain list → editor → run → result |
| US2 (P2) | US1 | adds the parameter step to `AddBlock` |
| US3 (P3) | US2 (for the top-10 chain's `prefix`), US1 | sort by count feeds a filter |
| US4 (P4) | US1 | branching is editor/outline work; can use any block |
| US5 (P5) | US1; matrix test grows with each added kind | availability in `AddBlock` |
| US6 (P6) | US2 (edit mode reuses the parameter step) | edit/remove/cancel |
| US7 (P7) | US2 (z parameter step), US5 (matrix) | new count kinds |
| US8 (P8) | US6 (freshness), US1 | saved results and drafts |

### Within Each Story

- Tests first and confirmed failing, then Domain (`Block` → `ProcessingBlockKind` → `BlockEvaluator`/rules), then reducers, then views.
- `Block.swift`, `ProcessingBlockKind.swift`, `BlockEvaluator.swift`, `ChainEditor.swift`, `AddBlock.swift` and their views are shared across stories: tasks touching the same file run in sequence, and stories touching the same file should not run concurrently.

### Parallel Opportunities

- Foundational: T003, T005 (after T004), T006, T010, T013, T015, T017, T019, T023, T026 are test/fixture files and can be written in parallel once the types they reference exist; the LocalStore digest (T017–T018), the source read path (T019–T022) and chain persistence (T023–T025) are three independent tracks.
- Each story's test tasks are marked [P] (different test files or independent additions).
- Domain parts of US2, US3, US5 and US7 (evaluator + rules) can be developed in parallel by different people if merged in one order, since they all append cases to `Block.swift` / `BlockEvaluator.swift`.

---

## Parallel Example: Foundational

```bash
# Three independent tracks once T004/T007/T012 exist:
Task: "T017 LocalStoreDigestTests in lottoApp2Tests/Data/LocalStoreDigestTests.swift → T018 digest in LocalStore.swift"
Task: "T019 gameFor tests in lottoApp2Tests/SorcesRepoImpTests.swift → T020–T022 read path"
Task: "T023 ChainsRepoImplTests in lottoApp2Tests/Data/ChainsRepoImplTests.swift → T024–T025 ChainsRepo"
```

## Parallel Example: User Story 1

```bash
# All five US1 test files together:
Task: "T027 BlocksPageTests rewrite in lottoApp2Tests/Reducers/BlocksPageTests.swift"
Task: "T028 ChainEditorTests in lottoApp2Tests/Reducers/ChainEditorTests.swift"
Task: "T029 AddBlockTests in lottoApp2Tests/Reducers/AddBlockTests.swift"
Task: "T030 ResultPageTests in lottoApp2Tests/Reducers/ResultPageTests.swift"
Task: "T031 ResultSummaryTests in lottoApp2Tests/Domain/ResultSummaryTests.swift"

# Then the two independent views:
Task: "T038 ResultPageView in lottoApp2/Presentation/Results/ResultPageView.swift"
Task: "T039 AddBlockView in lottoApp2/Presentation/ChainEditor/AddBlockView.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup → Phase 2 Foundational (the whole engine with Count Unique Elements).
2. Phase 3 US1: chain list, editor, add-block catalogue, run, result screen.
3. **STOP and VALIDATE**: US1 independent test + T042.

### Incremental Delivery (by ticket, inner → outer)

1. Foundational → LTA-6, LTA-19 engine, LTA-30, LTA-31 (chains).
2. US1 → LTA-9 (+ the first slice of LTA-23 and the chain list).
3. US2 → LTA-24 and the draw sorts of LTA-25; US3 → sort by count (LTA-25).
4. US4, US6 → remaining LTA-23 editor behaviour; US5 → LTA-26 + attach UI (LTA-22).
5. US7 → LTA-18, LTA-7, LTA-27.
6. US8 → LTA-31 saved results and drafts.

Each increment keeps all earlier suites green.

---

## Notes

- [P] = different files, no dependency on an incomplete task; [USn] maps to the spec's user stories.
- Verify each test fails for the right reason before implementing.
- Commit per task or logical group (only when asked); stop at any checkpoint to validate.
- Signature choices come from research R16 and contracts §1/§5: `attaching(_:under:id:)`, `renamed(_:)`, `editTapped`, `savedResultTapped`, `SourceSnapshot`, `ChainSource`; the unsaved-results warning counts `.value` results only.
- Open design points not settled by the spec, implemented with the stated default and to be confirmed: a `gameFor` read failure shows an alert (T028/T035); chain list order by name (T023).
