---

description: "Task list for 002-blocks-page-navigation"
---

# Tasks: Source Selection, Bottom Action Bar & Processing Blocks Page

**Input**: Design documents from `/specs/002-blocks-page-navigation/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/feature-contracts.md](./contracts/feature-contracts.md), [quickstart.md](./quickstart.md)

**Tests**: MANDATORY. Constitution Principle III (Test-First, NON-NEGOTIABLE) applies to every reducer
change here, so each behaviour is a Red → Green pair: the `TestStore` test is written and observed failing
before the implementation task that satisfies it. The generic "tests optional" default does not apply.

**Organization**: Tasks are grouped by user story so each can be implemented, tested, and demoed on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on an incomplete task
- **[Story]**: US1–US4, mapping to the user stories in [spec.md](./spec.md)
- Every task names the exact file it touches

## Path Conventions

Mobile app, single iOS target. Presentation code under `lottoApp2/Presentation/`, Domain entities under
`lottoApp2/Domain/Ents/`, reducer tests under `lottoApp2Tests/Reducers/`. The Xcode project uses file-system
synchronized groups — new files join their target automatically, so **no task edits `project.pbxproj`**.

**Same-file tasks are never marked [P].** `StartPageTests.swift`, `StartPage.swift`, and
`StartPageView.swift` are each touched by several tasks and must be done in listed order.

---

## Phase 1: Setup

**Purpose**: Confirm a clean starting point and create the new directories.

- [X] T001 Run the existing suite and confirm it is green before changing anything: `xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests`
- [X] T002 [P] Create the directory `lottoApp2/Presentation/BlocksPage/` for the new reducer and view

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The selection ruleset and the navigation destination. Every user story below depends on these.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T003 [P] Write failing `TestStore` tests for the selection ruleset in `lottoApp2Tests/Reducers/StartPageTests.swift`, driven through `.sourcesResponse`: mirrors match the chosen id (I3), a chosen id absent from the new list is dropped (I2/FR-016), a sole source is auto-chosen (I4/FR-009), two or more sources leave nothing chosen (I5/FR-010), and a never-synced zero-record source is treated identically (I6/FR-019)
- [X] T004 [P] Add `var isSelected: Bool = false` to `SourceEntry.State` in `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift` — mirror only, never written inside the child (contract C1)
- [X] T005 Add `selectedSourceID`, `hasLoaded`, `@Presents var blocks`, and the derived `isNextEnabled` to `StartPage.State`, plus the private `applySelectionRules()` implementing I2–I5 in the order given in [data-model.md](./data-model.md) §3, called at the end of `.sourcesResponse`, in `lottoApp2/Presentation/StartPage/StartPage.swift` (makes T003 pass; depends on T004)
- [X] T006 [P] Create the `BlocksPage` reducer skeleton in `lottoApp2/Presentation/BlocksPage/BlocksPage.swift` — `@ObservableState` holding `sourceID` and `sourceName`, no effects, per contract C3
- [X] T007 [P] Create the `BlocksPageView` shell in `lottoApp2/Presentation/BlocksPage/BlocksPageView.swift` — page title token only, identifying the screen as the processing blocks step, with `#Preview`s for `.light` and `.dark` (FR-027; header and block list arrive in US3)
- [X] T008 Add `Action.blocks(PresentationAction<BlocksPage.Action>)` and compose `.ifLet(\.$blocks, action: \.blocks) { BlocksPage() }` into the `StartPage` body in `lottoApp2/Presentation/StartPage/StartPage.swift` (depends on T005, T006)
- [X] T009 Confirm the existing regressions still pass unchanged — `sourcesResponse_preservesInFlightRefreshAndAlert`, `refreshResponse_forRemovedEntry_isIgnored`, `sourcesResponse_derivesSyncSeverityFromInjectedClock` in `lottoApp2Tests/Reducers/StartPageTests.swift` — adjusting the new state fields rather than the assertions if they break

**Checkpoint**: Selection rules hold and a destination exists to push. User stories can begin.

---

## Phase 3: User Story 1 — Move forward with the only source (Priority: P1) 🎯 MVP

**Goal**: The bottom bar with **Next**, the three-state start screen (loading / no sources / list), and the
push to the Processing Blocks page for the common single-source case.

**Independent Test**: Run with exactly one source — it shows as chosen and one tap on **Next** reaches the
blocks page. Run with none — a loading indication first, then the no-sources message, with **Next** disabled
throughout.

### Tests for User Story 1

- [X] T010 [US1] Write failing tests for the load states in `lottoApp2Tests/Reducers/StartPageTests.swift`: `hasLoaded` is `false` initially, becomes `true` on the first `.sourcesResponse`, stays `true` on a second one, and an empty response yields `hasLoaded == true` with no choice (FR-005, FR-006, FR-008, I7)
- [X] T011 [US1] Write failing tests for **Next** in `lottoApp2Tests/Reducers/StartPageTests.swift`: `.nextButtonTapped` with `selectedSourceID == nil` mutates nothing; with a choice it sets `blocks` carrying that source's id and `name`; two `.nextButtonTapped` in a row leave exactly one destination (FR-020, FR-021, FR-022, FR-023)

### Implementation for User Story 1

- [X] T012 [US1] Add `case nextButtonTapped` to `StartPage.Action` and handle it — guard on `selectedSourceID`, then build `BlocksPage.State` from the chosen entry — and set `hasLoaded = true` in `.sourcesResponse`, in `lottoApp2/Presentation/StartPage/StartPage.swift` (makes T010, T011 pass)
- [X] T013 [P] [US1] Create the pinned bar in `lottoApp2/Presentation/StartPage/Widgets/BottomActionBar.swift` — a single **Next** button, `.disabled` when no source is chosen (which carries the not-enabled trait to assistive technology), announced by its visible label, all colours/spacing/copy as tokens in a `// MARK: - Resources` block, with `#Preview`s for enabled × disabled × light/dark (FR-001 to FR-003, FR-020, FR-021, FR-032, FR-033, C6)
- [X] T014 [US1] Wrap `StartPageView`'s content in a single `NavigationStack`, attach the bar so the list scrolls under it and the last row can still be brought fully into view (FR-004), and push with `.navigationDestination(item: $store.scope(state: \.blocks, action: \.blocks))` so the platform's standard back gesture and control apply (FR-028), in `lottoApp2/Presentation/StartPage/StartPageView.swift` (depends on T013; research R1, contract C4)
- [X] T015 [US1] Render the three states in `lottoApp2/Presentation/StartPage/StartPageView.swift` — `!hasLoaded` → loading indication, `hasLoaded && sources.isEmpty` → the no-sources message, otherwise the list — with the message and loading copy as `LocalizedStringKey` tokens, both readable by assistive technology and the loading indication announced rather than silent (FR-005, FR-006, FR-032; depends on T014, same file)
- [X] T016 [P] [US1] Add preview fixtures for the empty and single-source cases in `lottoApp2/Presentation/Previews/PreviewFixtures.swift` (a single-source `SourcesBLogic` mock alongside the existing `Source.mocks`)
- [X] T017 [US1] Add `#Preview`s to `lottoApp2/Presentation/StartPage/StartPageView.swift` covering loading, no sources, and one source (auto-chosen) in both `.light` and `.dark` (depends on T015, T016)

**Checkpoint**: US1 is demoable end to end for the single-source and no-source cases.

---

## Phase 4: User Story 2 — Pick which source to work with (Priority: P2)

**Goal**: Tap a card to choose it, with the highlight (border **and** checkmark) and the Refresh button
carved out so it never moves the choice.

**Independent Test**: Run with several sources — **Next** starts disabled, tapping a card highlights it and
enables **Next**, tapping another moves the highlight, tapping Refresh on a third moves nothing.

### Tests for User Story 2

- [X] T018 [P] [US2] Write failing tests in `lottoApp2Tests/Reducers/SourceEntryTests.swift`: `.cardTapped` emits `.delegate(.selectionRequested)` and mutates nothing, and still emits it while `isRefreshing` is `true` (contract C1, FR-011, FR-017, FR-019)
- [X] T019 [US2] Write failing tests in `lottoApp2Tests/Reducers/StartPageTests.swift`: a `selectionRequested` delegate for id X selects X; for Y moves the choice and clears X's mirror; for X again keeps it; and `.refreshResponse` success **and** failure both leave `selectedSourceID` untouched (FR-013, FR-014, FR-017, I8)

### Implementation for User Story 2

- [X] T020 [P] [US2] Add `case cardTapped` and `Delegate.selectionRequested` to `SourceEntry`, returning `.send(.delegate(.selectionRequested))` with no `isRefreshing` guard, in `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift` — leaving `.refreshButtonTapped` emitting only `refreshRequested` (makes T018 pass; FR-011, FR-012)
- [X] T021 [US2] Handle `.sources(.element(id:action:.delegate(.selectionRequested)))` in `lottoApp2/Presentation/StartPage/StartPage.swift` — set `selectedSourceID` then re-apply the rules from T005 (makes T019 pass; depends on T020)
- [X] T022 [US2] Make the whole card choosable in `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift` with `.contentShape(Rectangle())` + `.onTapGesture`, leaving the existing Refresh `Button` untouched and un-nested (FR-011, FR-012; research R4)
- [X] T023 [US2] Draw the chosen state in `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift` — extend `SourceCardStyle` with a selected border/tint **and** add a checkmark, both as tokens, so the cue never depends on colour alone (FR-015; depends on T022, same file)
- [X] T024 [US2] Add accessibility to the card in `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift` — one element with `.isButton`, `.isSelected` when chosen, Refresh remaining its own element — and add selected-variant `#Preview`s in both colour schemes (FR-032, FR-033; research R7; depends on T023, same file)

**Checkpoint**: US1 and US2 both work; the multi-source flow is complete.

---

## Phase 5: User Story 3 — See which source the blocks apply to (Priority: P3)

**Goal**: The Processing Blocks page names the chosen source in a header and lists "Count Unique Elements".

**Independent Test**: Choose a source, move forward, and confirm the header names exactly that source and
the list holds exactly one entry.

### Tests for User Story 3

- [X] T025 [P] [US3] Write failing tests in `lottoApp2Tests/Reducers/BlocksPageTests.swift` (new file): initial state lists exactly `[.countUniqueElements]` and carries the `sourceID`/`sourceName` it was constructed with (FR-024, FR-025, FR-026, contract C3)

### Implementation for User Story 3

- [X] T026 [P] [US3] Create `lottoApp2/Domain/Ents/ProcessingBlockKind.swift` — `nonisolated enum ProcessingBlockKind: String, CaseIterable, Equatable, Sendable` with the single case `countUniqueElements`, no display copy and no SwiftUI import (contract C5; research R5)
- [X] T027 [US3] Add `var blocks: [ProcessingBlockKind] = ProcessingBlockKind.allCases` to `BlocksPage.State` in `lottoApp2/Presentation/BlocksPage/BlocksPage.swift` (makes T025 pass; FR-025, FR-026; depends on T026)
- [X] T028 [US3] Render the source header in `lottoApp2/Presentation/BlocksPage/BlocksPageView.swift` — the name only, no record count, sync status, or dates — handling a long name without clipping, and reachable by assistive technology announced by its visible text (FR-024, FR-032)
- [X] T029 [US3] Render the block list in `lottoApp2/Presentation/BlocksPage/BlocksPageView.swift`, mapping each `ProcessingBlockKind` to its label with an **exhaustive `switch`** over `LocalizedStringKey` tokens so a future case fails to compile, with each row reachable and announced by its visible label (FR-025, FR-026, FR-032; depends on T028, same file)
- [X] T030 [US3] Add `#Preview`s to `lottoApp2/Presentation/BlocksPage/BlocksPageView.swift` for a short and a long source name in both `.light` and `.dark` (depends on T029, same file)

**Checkpoint**: The destination is complete; the forward flow is fully demoable.

---

## Phase 6: User Story 4 — Return without losing the choice (Priority: P4)

**Goal**: Going back keeps the chosen source and the loaded list, and the reload that follows never swaps
the list for a loading indication.

**Independent Test**: Choose a source, move forward, go back — the same card is still highlighted, **Next**
is still enabled, and no spinner appears while the list reloads.

### Tests for User Story 4

- [X] T031 [US4] Write failing tests in `lottoApp2Tests/Reducers/StartPageTests.swift`: dismissing `blocks` (`.blocks(.dismiss)`) leaves `selectedSourceID`, `hasLoaded` and `sources` intact, and a subsequent `.nextButtonTapped` pushes again with the same source (FR-029, FR-031, contract C4)
- [X] T032 [US4] Write a failing test in `lottoApp2Tests/Reducers/StartPageTests.swift` that loops push → dismiss **five times** and asserts the end state equals the state after a single push — same `selectedSourceID`, same `sources`, `hasLoaded` still `true`, exactly one `blocks` destination (SC-007)
- [X] T033 [US4] Write a failing test in `lottoApp2Tests/Reducers/StartPageTests.swift` for the post-return reload: with `hasLoaded == true`, a fresh `.task` → `.sourcesResponse` cycle keeps `hasLoaded` true throughout (so the view never returns to the loading state) and keeps a still-present choice (FR-030, I7)

### Implementation for User Story 4

- [X] T034 [US4] Confirm or adjust `lottoApp2/Presentation/StartPage/StartPage.swift` so dismissal and reload satisfy T031–T033 — `hasLoaded` is only ever set to `true`, and no path resets `selectedSourceID` other than `applySelectionRules()` (expected to need no change; if a change is required, it belongs here rather than in an earlier task)
- [X] T035 [US4] Establish empirically, on the simulator, whether popping back to `StartPageView` re-fires its `.task` — push, pop, and confirm a second `blSources.knownSources()` call happens. **The plan assumes it does (contract C4); FR-030 requires it either way.** If `.task` does not re-fire on pop, add an explicit trigger in `lottoApp2/Presentation/StartPage/StartPageView.swift` (an `.onAppear`-driven load action, or `.onChange` of the presentation binding) rather than leaving FR-030 unmet — and record which path was taken in a comment
- [X] T036 [US4] Verify in `lottoApp2/Presentation/StartPage/StartPageView.swift` that the populated list stays rendered while the post-return reload runs — the loading branch keys on `hasLoaded`, not on an in-flight effect (FR-030)

**Checkpoint**: All four stories independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T037 [P] Audit the four views touched — `lottoApp2/Presentation/StartPage/StartPageView.swift`, `Widgets/BottomActionBar.swift`, `Widgets/SourceEntryView.swift`, `lottoApp2/Presentation/BlocksPage/BlocksPageView.swift` — for inline literals (colours, fonts, spacing, radii, opacity, image names, copy) and move any stragglers into their `// MARK: - Resources` token extensions (Principle V)
- [X] T038 [P] Run the Dynamic Type check from [quickstart.md](./quickstart.md) step 12 at the largest accessibility text size; confirm the bar grows and no label clips (SC-003)
- [ ] T039 [P] **NOT DONE — needs a human at the simulator.** VoiceOver cannot be driven headlessly with the tooling available here, so the runtime announcements are unverified. The code-level implementation is in place (card as a `.contain` element with `.isButton`/`.isSelected` and a named "Choose this source" action, Refresh left as its own element, `Next` using `.disabled`, message and header as readable text) — what remains is confirming it *sounds* right. Run the VoiceOver check from [quickstart.md](./quickstart.md) step 13 across **all** the elements FR-032 names — card (button + "selected"), Refresh as its own element, **Next** announced as unavailable when disabled, the no-sources message, the loading indication, the blocks header, and each block row (FR-032, FR-033, SC-008)
- [ ] T040 Work through the manual end-to-end table in [quickstart.md](./quickstart.md) steps 1–11 on the simulator — **partially done**. Verified on iPhone 17 Pro: step 1 (loading → list, no premature no-sources message), 7 (push, header names MBNet Server, one block row), 8 (two `Next` taps then one back returns to the list — one destination), 9 (back keeps the highlight, no spinner during the reload), 11 (card scrolls clear of the bar, also at the largest text size). **Steps 2–6 (multi-source: disabled `Next`, pick, move, re-tap, Refresh carve-out) are unreachable in the live app** — the registry yields the single MBNet source — so they are covered by reducer tests and previews only. Step 10 (five cycles) is covered by test T032, not manually.
- [X] T041 Confirm the feature added nothing it should not: `Package.resolved` unchanged, nothing under `lottoApp2/Data/`, no new `DependencyKey`, no `project.pbxproj` edit (`git status` + `git diff --stat`)
- [X] T042 Run the full suite green: `xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests`
- [X] T043 Tick off the Definition of Done in [quickstart.md](./quickstart.md)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup — **blocks every user story**
- **US1 (Phase 3)**: depends on Foundational
- **US2 (Phase 4)**: depends on Foundational; independent of US1
- **US3 (Phase 5)**: depends on Foundational (needs the `BlocksPage` skeleton from T006/T007)
- **US4 (Phase 6)**: depends on Foundational and on US1 (there is no destination to return from until **Next** pushes one)
- **Polish (Phase 7)**: depends on all stories being complete

### User Story Dependencies

- **US1 (P1)** — self-contained once Foundational is done. Delivers the single-source and no-source paths.
- **US2 (P2)** — self-contained once Foundational is done; generalises US1 to several sources. It can be built before US1 if preferred, but is less valuable alone (choosing a source with nowhere to go).
- **US3 (P3)** — self-contained once Foundational is done; can be built in parallel with US1/US2 because it only touches `BlocksPage*` and the new Domain enum.
- **US4 (P4)** — the only story with a real cross-story dependency: it validates the round trip US1 creates.

### Within Each Story

- The story's failing tests come first, always.
- Reducer changes before the views that render them.
- Same-file tasks run in listed order (they are never marked [P]).

### Parallel Opportunities

- T003 and T004 (different files) can run together at the start of Foundational; T006 and T007 likewise.
- **US3 is the big one**: T025–T030 touch only `BlocksPage.swift`, `BlocksPageView.swift`,
  `BlocksPageTests.swift` and the new Domain enum, so a second person can build the whole destination while
  the first builds US1's bar and navigation.
- T018 and T020 (`SourceEntry*`) are independent of the `StartPage*` work in the same phase.
- The three Polish audits T037–T039 are independent of each other.

---

## Parallel Example: Foundational + US3

```bash
# Foundational, two files at once:
Task: "T003 Failing selection-ruleset tests in lottoApp2Tests/Reducers/StartPageTests.swift"
Task: "T004 Add isSelected to SourceEntry.State in lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift"

# After the Foundational checkpoint, two developers:
Developer A: T010–T017  (US1 — bar, navigation, load states)
Developer B: T025–T030  (US3 — Domain enum, blocks page header and list)
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 Setup → Phase 2 Foundational → Phase 3 US1.
2. **STOP and VALIDATE**: with one source known, the card is chosen and one tap reaches the blocks page;
   with none, a loading indication then the no-sources message, **Next** disabled throughout.
3. This is a shippable increment: the flow works for today's live registry, which yields a single source.

### Incremental Delivery

1. Setup + Foundational → rules and destination in place.
2. + US1 → **MVP**: the forward path works.
3. + US2 → several sources become selectable.
4. + US3 → the destination names the source and lists the block.
5. + US4 → the round trip preserves the choice.
6. Polish.

### Notes

- Verify each test fails before writing the implementation that satisfies it — a test that passes on arrival
  is testing something already true, not the new behaviour.
- Commit after each task or logical group.
- Do not rewrite the three existing regression tests named in T009 to accommodate new state; extend the
  state so they keep passing as written.
- Nothing in this feature touches `lottoApp2/Data/`, adds a dependency, or persists anything — if a task
  seems to require any of those, stop and re-read [research.md](./research.md) rather than improvising.
