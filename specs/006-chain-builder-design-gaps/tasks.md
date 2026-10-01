---

description: "Task list for 006 chain-builder design gaps (LTA-33)"
---

# Tasks: Chain-Builder Design Gaps

**Input**: Design documents from `/specs/006-chain-builder-design-gaps/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui-contracts.md, quickstart.md

**Tests**: Per the project constitution (Principle III, Test-First — NON-NEGOTIABLE), reducer and Domain business-logic tasks MUST include `TestStore`/unit test tasks authored before their implementation. The generic "tests optional" default does NOT apply to this project for those units.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

Paths are repo-relative. Tests are swift-testing `@MainActor @Test` functions using `TestStore`; never block a thread in a test (CLAUDE.md).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: None needed — the target, packages and test target already exist; no new files or dependencies.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The parameter context type and its plumbing, which US1 and US2 both read.

- [X] T001 Write failing tests in lottoApp2Tests/Reducers/AddBlockTests.swift: `BlockParameters.State(kind:mode:)` still compiles with `context` defaulting to `.unknown` (`parentSize == nil`, `drawSize == nil`); `AddBlock.State(parentID:parent:parentOutput:context:)` + `kindTapped(.prefix)` presents `parameters` whose `context` equals the sheet's context
- [X] T002 Add `BlockParameters.Context` (`parentSize: ParentSize?`, `drawSize: Int?`, `static let unknown`), `ParentSize { count: Int; unit: Unit }` with `Unit { draws, items }`, and `context` stored on `BlockParameters.State` with init `State(kind:mode:context: = .unknown)` in lottoApp2/Presentation/ChainEditor/BlockParameters.swift
- [X] T003 Add `context: BlockParameters.Context` (default `.unknown`) to `AddBlock.State` and pass it into `BlockParameters.State` on `kindTapped` in lottoApp2/Presentation/ChainEditor/AddBlock.swift
- [X] T004 Write failing tests in lottoApp2Tests/Reducers/ChainEditorTests.swift: `onAppear` sends `.loaded(…, drawSize: 3)` when `blSources.gameFor` succeeds with `ReferenceDraws.threeOfFive`, and `drawSize: nil` when it fails; `gameLoaded(.success)` sets `state.drawSize` and `gameLoaded(.failure)` leaves it unchanged; update every existing `onAppear`/`.loaded` test to the new payload
- [X] T005 Add `drawSize: Int?` to `ChainEditor.State`, read `blSources.gameFor(source.id)` in the `onAppear` effect (success → `snapshot.game.type.combinationType.pick`, failure → `nil`), extend `.loaded(savedResults:draft:dataStates:drawSize:)`, and set `drawSize` in `gameLoaded(.success)` in lottoApp2/Presentation/ChainEditor/ChainEditor.swift
- [X] T006 Write failing tests in lottoApp2Tests/Reducers/ChainEditorTests.swift for `parentSize(of:)` / `context(under:)` via `addTapped` and `editTapped`: under the input with `dataStates[source] = .mbnetMock` → `.draws` of `recordsCount`; under a node with `.value(.draws(game))` → `.draws` of `game.entries.count`; with `.value(.counts(result))` → `.items` of `result.counts.count`; not run / running / failed → `nil`; out-of-date value still counts; editing passes the node's *parent* size; `drawSize` is forwarded
- [X] T007 Implement `ChainEditor.State.parentSize(of:)` and `context(under:)` (research R2) and pass the context in `addTapped` (to `AddBlock.State`) and `startEditing` (to `BlockParameters.State`, using the node's `parentID`) in lottoApp2/Presentation/ChainEditor/ChainEditor.swift

**Checkpoint**: The parameter step receives parent size and draw size; all existing tests green.

---

## Phase 3: User Story 1 - Parameter step explains what a value means (Priority: P1) 🎯 MVP

**Goal**: Parent-size hint, edit hint and direction preview (FR-001–FR-004).

**Independent Test**: `TestStore`/state tests over `BlockParameters.State.hint` and `.directionPreview`; previews of each hint in light and dark.

### Tests for User Story 1

- [X] T008 [US1] Write failing tests in lottoApp2Tests/Reducers/AddBlockTests.swift: `hint == .parentSize(.init(count: 7012, unit: .draws))` for `.prefix` in add mode with that context; `.items` for a counts parent; `nil` with unknown parent size; `nil` for non-`.count` parameters in add mode; `.was(.suffix(100))` in edit mode that stays after `countTextChanged("50")`; `.was(.sortByCount(.descending))` for an edited sort; no hint for an edited block without parameters
- [X] T009 [US1] Write failing tests in lottoApp2Tests/Reducers/AddBlockTests.swift: `directionPreview` is `.mostFrequent` for `.sortByCount` default (descending) and `.leastFrequent` after `directionChanged(.ascending)`; `.oldest`/`.newest` for `.sortByDate`; `.lowestIndex`/`.highestIndex` for `.sortByIndex`; `nil` for non-sort kinds

### Implementation for User Story 1

- [X] T010 [US1] Add `Hint { parentSize(ParentSize), was(Block) }` and `DirectionPreview { mostFrequent, leastFrequent, oldest, newest, lowestIndex, highestIndex }` with computed `hint` and `directionPreview` per data-model.md ("`.was(original)` in edit mode when `parameter != .none`; else `.parentSize(p)` when `parameter == .count` and the parent size is known; else `nil`") in lottoApp2/Presentation/ChainEditor/BlockParameters.swift
- [X] T011 [US1] Add shared copy tokens in lottoApp2/Presentation/ChainEditor/BlockTokens.swift: `parentSizeHint(_ size: ParentSize)` ("Of <n> draws. A larger x keeps them all." / "Of 1 draw. …" / "items"/"item", grouped digits), `wasHint(_ block: Block)` ("Was <v>. Saving marks this block's results out of date." / "Was Ascending." / "Was Descending." + same tail), `directionPreview(_:)` (contracts C1 copy)
- [X] T012 [US1] Render the hint as the parameter section footer (below the invalid message rule: an invalid reason replaces the hint) and the direction preview line under the segmented control, in lottoApp2/Presentation/ChainEditor/BlockParametersView.swift; token colours `textSecondary` for hints
- [X] T013 [US1] Add previews in lottoApp2/Presentation/ChainEditor/BlockParametersView.swift: "filter - parent size" light/dark (`context: .init(parentSize: .init(count: 7012, unit: .draws), drawSize: 6)`), "edit - was hint" light/dark (`.edit` of `.suffix(100)` with text "50"), "sort - direction preview" light/dark

**Checkpoint**: US1 complete and testable independently.

---

## Phase 4: User Story 2 - Sub-combination size is bounded by the source's draw size (Priority: P1)

**Goal**: z bound 2 … x − 1, "+" capped, bounded and too-small messages (FR-005–FR-008).

**Independent Test**: `TestStore` over `BlockParameters` with `.countUniqueSubCombinations` and draw sizes 6, unknown and 2.

### Tests for User Story 2

- [X] T014 [US2] Write failing tests in lottoApp2Tests/Reducers/AddBlockTests.swift (drawSize 6): `countTextChanged("5")` → `isValid`, `invalidReason == nil`, `canIncrement == false`; `"6"` → `invalidReason == .range(2, 5)`, `isValid == false`; `"1"` and `""` → `.range(2, 5)`; from `"4"`, `incrementTapped` → `"5"`, again → stays `"5"`; `confirmTapped` at `"6"` sends nothing
- [X] T015 [US2] Write failing tests in lottoApp2Tests/Reducers/AddBlockTests.swift: unknown draw size → `"6"` valid, `"1"` gives `.atLeast(2)`, `canIncrement == true`; drawSize 2 → every value invalid with `.drawsTooSmall`, `canIncrement == false`; drawSize 6 in edit mode of `.countUniqueSubCombinations(z: 7)` opens invalid with `.range(2, 5)`; x filters unaffected by drawSize (`.atLeast(0)` for `"-3"`)

### Implementation for User Story 2

- [X] T016 [US2] Implement `maximum: UInt?` ("For `.size` with a known draw size, `drawSize − 1` (it may fall below `minimum`). `nil` otherwise."), bound `count` to `minimum ≤ value ≤ maximum`, `InvalidReason { atLeast(UInt), range(UInt, UInt), drawsTooSmall }` with `invalidReason`, `canIncrement`, and clamp `incrementTapped` at `maximum` in lottoApp2/Presentation/ChainEditor/BlockParameters.swift
- [X] T017 [US2] Add `invalidReason(_:)` copy tokens ("Enter a whole number, 0 or more." / "…, 2 or more." / "Enter a whole number from 2 to <m>." / "This source's draws are too small for sub-combinations.") in lottoApp2/Presentation/ChainEditor/BlockTokens.swift, replacing the `invalidX`/`invalidZ` tokens in lottoApp2/Presentation/ChainEditor/BlockParametersView.swift
- [X] T018 [US2] Show `invalidReason` in the footer and disable "+" with `!store.canIncrement` in lottoApp2/Presentation/ChainEditor/BlockParametersView.swift
- [X] T019 [US2] Add previews "z bound - too large" light/dark (`.countUniqueSubCombinations`, drawSize 6, text "6") in lottoApp2/Presentation/ChainEditor/BlockParametersView.swift

**Checkpoint**: US1 + US2 complete.

---

## Phase 5: User Story 3 - Chain list: empty state, rename and delete everywhere (Priority: P2)

**Goal**: FR-016–FR-020.

**Independent Test**: `BlocksPageTests` for rename flow and empty-state gate; previews of the empty list.

### Tests for User Story 3

- [X] T020 [US3] Write failing tests in lottoApp2Tests/Reducers/BlocksPageTests.swift: `renameTapped(id)` (as sent by the leading swipe) sets `renaming = id`, `renameDraft = "Hot numbers"`; `renameDraftChanged("Hot pairs")` + `renameConfirmed` renames, clears `renaming`/`renameDraft`, and saves via `chainsRepo`; blank and unchanged drafts clear state without saving; `renameCancelled` clears state; `renameTapped` for an unknown id changes nothing; `renameConfirmed` after the chain was deleted saves nothing. Replace existing `renameChain` tests with this flow
- [X] T021 [US3] Write failing tests in lottoApp2Tests/Reducers/BlocksPageTests.swift: `showsEmptyState == false` before `chainsLoaded`; `true` after `chainsLoaded([])`; `false` after `chainsLoaded([chain])`; `true` after the last chain is deleted via `alert(.presented(.confirmDelete))`; update the existing `receive(\.chainsLoaded)` assertion (BlocksPageTests.swift:46) to also set `hasLoaded = true`

### Implementation for User Story 3

- [X] T022 [US3] In lottoApp2/Presentation/BlocksPage/BlocksPage.swift add `hasLoaded` (set on `chainsLoaded`), `renaming: Chain.ID?`, `renameDraft: String`, computed `showsEmptyState` (`hasLoaded && chains.isEmpty`), actions `renameTapped(Chain.ID)`, `renameDraftChanged(String)`, `renameConfirmed`, `renameCancelled` (contracts C4); remove `renameChain(Chain.ID, String)`
- [X] T023 [US3] In lottoApp2/Presentation/BlocksPage/BlocksPageView.swift drop the `@State` rename vars; bind the rename alert to `store.renaming` and its `TextField` to `$store.renameDraft.sending(\.renameDraftChanged)` (Save → `renameConfirmed`, Cancel → `renameCancelled`); add a leading `.swipeActions(edge: .leading)` "Rename" (pencil, `.tint(Color.renameTint)` = primaryBlue); add Delete (destructive, trash) to the context menu after Rename
- [X] T024 [US3] In lottoApp2/Presentation/BlocksPage/BlocksPageView.swift add the empty state above the New chain row when `store.showsEmptyState`: ƒ icon (`function`, `textTertiary`), "No chains yet" (headline, `textSecondary`), "A chain is a set of blocks that counts and sorts a source's draws. Tap New chain to build your first one." (footnote, `textSecondary`), centred, tokens under `// MARK: - Resources`
- [X] T025 [US3] In lottoApp2/Presentation/BlocksPage/BlocksPageView.swift give each chain row `.accessibilityElement(children: .ignore)`, label "<name>, <N> blocks" ("1 block"), and `.accessibilityAction(named: "Rename")` → `renameTapped`, `.accessibilityAction(named: "Delete")` → `deleteChainTapped`
- [X] T026 [US3] Update previews in lottoApp2/Presentation/BlocksPage/BlocksPageView.swift: "empty chain list" light/dark (store loads `[]` so `hasLoaded` is true on appear) and keep the chains previews

**Checkpoint**: US3 complete.

---

## Phase 6: User Story 4 - Chain editor reads correctly with VoiceOver and large text (Priority: P3)

**Goal**: FR-013–FR-015. View-only; no reducer changes.

**Independent Test**: VoiceOver and AX5 checks per quickstart §3; AX5 preview.

- [X] T027 [P] [US4] Add row-reading tokens in lottoApp2/Presentation/ChainEditor/BlockTokens.swift: `addBlockUnder(_ name: String)` ("Add block under <name>"), `levelReading(_ depth: Int)` ("level <n>"), `sourceRowReading(name:count:)` ("<name>, source[, <N> draws]"), `runningReading` ("Running"), `savedReading` ("Saved")
- [X] T028 [US4] In lottoApp2/Presentation/ChainEditor/ChainEditorView.swift label each "+" with `addBlockUnder` (block title or source name); make each node row one accessibility element reading "<title>[, <parameters>][, <N> hidden], level <depth>, <state>[, Saved]" (state: "Not run", "Running", failure text, summary, or summary + ", Out of date"); make the source row read `sourceRowReading`
- [X] T029 [US4] In lottoApp2/Presentation/ChainEditor/ChainEditorView.swift read `@Environment(\.dynamicTypeSize)`; when `isAccessibilitySize`, lay out the title block and status with `AnyLayout(VStackLayout(alignment: .leading))` instead of an HStack, and use `indentPerLevelAccessible: CGFloat = 12` instead of `indentPerLevel = 22` for padding and guide lines; add an AX5 preview (light and dark)

---

## Phase 7: User Story 5 - Add-block sheet accessibility (Priority: P3)

**Goal**: FR-010–FR-012. View-only.

**Independent Test**: VoiceOver and AX5 checks per quickstart §2.

- [X] T030 [P] [US5] In lottoApp2/Presentation/ChainEditor/AddBlockView.swift give disabled rows the label "<block title>, unavailable, <reason>" (token `unavailableReading(kind:needs:)` in lottoApp2/Presentation/ChainEditor/BlockTokens.swift)
- [X] T031 [US5] In lottoApp2/Presentation/ChainEditor/BlockParametersView.swift group the field and stepper as one adjustable element (`.accessibilityElement(children: .combine)`, `.accessibilityValue(countText)`, `.accessibilityAdjustableAction` → `incrementTapped`/`decrementTapped`), and at `isAccessibilitySize` stack the label/field and the stepper vertically with `AnyLayout`; add an AX5 preview (light and dark)

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T032 Update the header comments that say "LTA-33 closes where this still differs" in lottoApp2/Presentation/BlocksPage/BlocksPageView.swift:7 and lottoApp2/Presentation/ChainEditor/ChainEditorView.swift:5 to state they match design/final/
- [X] T033 Run the full unit suite (`xcodebuild test … -only-testing:lottoApp2Tests`, fallback My Mac destination) and fix failures
- [X] T034 Walk quickstart.md manual checks that can be verified without a device (previews build; `xcodebuild build`; the AX5 previews from T029/T031 show no truncated title, summary or number field — SC-004), and note in CLAUDE.md nothing new is needed unless a convention changed

---

## Dependencies & Execution Order

- **Phase 2** (T001–T007) blocks US1 and US2 (they read `Context`). US3–US5 do not depend on it.
- **US1** (T008–T013) and **US2** (T014–T019) both edit BlockParameters.swift/BlockParametersView.swift/BlockTokens.swift → sequential (US1 then US2).
- **US3** (T020–T026) touches only BlocksPage files → can run in parallel with US1/US2 after nothing.
- **US4** (T027–T029) touches ChainEditorView/BlockTokens → after US2 (shared BlockTokens) or coordinate edits.
- **US5** (T030–T031) touches AddBlockView/BlockParametersView → after US2.
- Within a story: tests first (must fail), then implementation, then previews.

## Parallel Example

```text
# After Phase 2:
US1/US2 chain (BlockParameters*) ‖ US3 chain (BlocksPage*)
# Within US3:
T020 then T021 (same file) → T022 → T023, T024, T025 (same view file, sequential) → T026
```

## Implementation Strategy

1. Phase 2 → US1 (MVP: hints visible, tested) → validate.
2. US2 (z bound) → US3 (chain list) → US4/US5 (accessibility) → Polish.
3. Each checkpoint leaves the suite green.
