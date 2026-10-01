---

description: "Task list for the Fetch button on never-synced sources (LTA-3)"
---

# Tasks: Fetch Button on Never-Synced Sources

**Input**: Design documents from `/specs/008-fetch-never-synced/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui-contracts.md, quickstart.md

**Tests**: Per the project constitution (Principle III, Test-First — NON-NEGOTIABLE), reducer and Domain business-logic tasks MUST include `TestStore`/unit test tasks authored before their implementation. The generic "tests optional" default does NOT apply to this project for those units.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)

Paths are relative to the repo root (`lottoApp2/`, `lottoApp2Tests/`).

---

## Phase 1: Setup

No setup is needed: there are no new dependencies, targets or files beyond the spec docs.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the `SyncAction` value that every story reads (contracts §1, data-model).

- [X] T001 Write failing tests in `lottoApp2Tests/Reducers/SourceEntryTests.swift`:
  - `sourceEntryState_neverSynced_offersFetch`: a `Source` with `lastSync: nil` maps to `syncAction == .fetch`.
  - `sourceEntryState_synced_offersRefresh`: a `Source` with a `lastSync` maps to `.refresh`.
  - `apply_firstSuccessfulSync_turnsFetchIntoRefresh`: a `lastSync == nil` state, after `apply` with a synced `Source`, reports `.refresh` (FR-002).
  - `apply_firstSyncWithNoDraws_stillTurnsIntoRefresh`: `apply` with a `Source` that has a `lastSync` and `recordsCount: 0` reports `.refresh`. The kind follows a successful sync, not the record count (spec Edge Cases).
- [X] T002 Make T001 pass in `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift`:
  - add `enum SyncAction: Equatable { case fetch, refresh }` nested in `SourceEntry`, documented as "`fetch` ⇔ `lastSync == nil`"
  - add the computed `var syncAction: SyncAction { lastSync == nil ? .fetch : .refresh }` on `State`. It is never stored (research R1).

**Checkpoint**: `syncAction` is derived and tested. Story work can begin.

---

## Phase 3: User Story 1 — A never-synced source offers to fetch its data (Priority: P1) 🎯 MVP

**Goal**: the full card shows Fetch / Fetching… for never-synced sources and flips to Refresh after the first successful sync. A failed first fetch keeps Fetch and uses the fetch wording.

**Independent Test**: quickstart checks 1–5, plus the full card's never-synced previews showing "Fetch".

### Tests for User Story 1 (write first, confirm they fail)

- [ ] T003 [P] [US1] In `lottoApp2Tests/Reducers/SourceEntryTests.swift`, add `syncFailedFallback_isWordedForTheAction`:
  - `.syncFailed(.unknown, sourceName: "MBNet Server", action: .fetch)` reads "Couldn't fetch MBNet Server. Try again."
  - with `action: .refresh` it reads "Couldn't refresh MBNet Server. Try again."
  - extend `everyShownFailure_hasItsOwnMessage_underTheSameTitle` so that every non-fallback failure's message is identical for `.fetch` and `.refresh` (FR-007).
- [ ] T004 [P] [US1] Add to `lottoApp2Tests/Reducers/StartPageTests.swift`:
  - `firstFetch_success_turnsFetchIntoRefresh`: a never-synced entry; `refreshRequested` then `.refreshResponse(.success(synced))`; assert `isRefreshing` true → false and `syncAction == .refresh` at the end (US1-AS3/AS4).
  - `firstFetch_failure_keepsFetch_andUsesFetchWording`: a never-synced entry; `.refreshResponse(.failure(.unknown))`; assert `lastSync == nil` (so `.fetch`) and `alert == .syncFailed(.unknown, sourceName: "MBNet Server", action: .fetch)` (FR-006, FR-007).
  - `firstFetch_cancelled_keepsFetch`: `.failure(.cancelled)` leaves `.fetch` and no alert.
  - `sourcesResponse_midFetch_rederivesTheKind_andKeepsInProgress`: a never-synced entry with `isRefreshing = true`; `.sourcesResponse([.mbnetMock])` (synced) ends with `syncAction == .refresh` and `isRefreshing` still true (spec Edge Cases; follows `sourcesResponse_preservesInFlightRefreshAndAlert`).

### Implementation for User Story 1

- [ ] T005 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift`:
  - change `AlertState.syncFailed` to `syncFailed(_:sourceName:action:)`. The `action` parameter is required, with no default (research R3).
  - `syncFailedMessage` takes the action. Only the `.unknown, .cancelled` fallback branches on it, through `LocalizedStringResource` tokens `syncFailedFallbackFetch(name)` and `syncFailedFallbackRefresh(name)`.
- [ ] T006 [US1] In `lottoApp2/Presentation/StartPage/StartPage.swift` `.refreshResponse(.failure)`, pass the entry's `syncAction` (contracts §3). Update the existing `.syncFailed(...)` call sites in `lottoApp2Tests/Reducers/StartPageTests.swift` (lines ~89, ~110, ~140) to pass `action: .refresh`, since those entries are synced. Run T003/T004 and confirm they pass.
- [ ] T007 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceCardParts.swift`, replace `RefreshIcon(isRefreshing:)` with `SyncIcon(action:isSyncing:)`:
  - while idle it shows `Image(.syncIdle[action])`: `.fetch` → new token `fetch = .system("arrow.down.circle")`, `.refresh` → the existing refresh glyph
  - while syncing it shows the existing refresh glyph with the existing spin (Clarification Q2, research R2)
  - keep `RefreshButtonStyle` unchanged, and update the parts preview to show both idle kinds and the syncing state.
- [ ] T008 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift` `refreshButton`:
  - use `SyncIcon(action: store.syncAction, isSyncing: store.isRefreshing)`
  - pick the label from `LocalizedStringKey` dictionaries keyed by `SourceEntry.SyncAction`: idle `[.fetch: "Fetch", .refresh: "Refresh"]`, syncing `[.fetch: "Fetching…", .refresh: "Refreshing…"]`. They replace the `refresh` / `refreshing` tokens.
  - keep `.lineLimit(.refreshLabelLines)` and `.minimumScaleFactor(.refreshLabelScale)` (FR-009).
- [ ] T009 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift`, add the previews "Light Mode - never synced - fetching" and "Dark Mode - never synced - fetching", using a `mock1e` copy with `isRefreshing = true`. The existing `mock1e` "empty" previews already cover idle Fetch (FR-010).

**Checkpoint**: US1 is complete on the full card and in the reducers.

---

## Phase 4: User Story 2 — The compact card makes the same distinction (Priority: P2)

**Goal**: the compact row's icon-only button shows the fetch glyph and is spoken as Fetch / Fetching for never-synced sources.

**Independent Test**: the compact never-synced previews show the download glyph, and the VoiceOver label follows contracts §4.

- [ ] T010 [US2] In `lottoApp2/Presentation/StartPage/Widgets/CompactSourceEntryView.swift` `refreshButton`:
  - use `SyncIcon(action: store.syncAction, isSyncing: store.isRefreshing)`
  - set `.accessibilityLabel` from `LocalizedStringKey` dictionaries keyed by `SyncAction`: idle `[.fetch: "Fetch", .refresh: "Refresh"]`, syncing `[.fetch: "Fetching", .refresh: "Refreshing"]`. They replace the `refreshLabel` / `refreshingLabel` tokens (FR-004).
- [ ] T011 [US2] In `lottoApp2/Presentation/StartPage/Widgets/CompactSourceEntryView.swift`, add the compact previews "never synced - fetching" in light and dark, using a `mock1e` copy with `isRefreshing = true`. Check that the existing never-synced compact previews show the fetch glyph.

**Checkpoint**: both card variants make the distinction.

---

## Phase 5: User Story 3 — Fetch reads well in every appearance (Priority: P3)

**Goal**: legible in light and dark at every text size, with no regression of spec 007's reflow.

- [ ] T012 [US3] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift`, add the preview "never synced - accessibility XXXL" (`.environment(\.dynamicTypeSize, .accessibility5)`) for `mock1e`, idle and fetching. Check that "Fetch" / "Fetching…" stay on one line, untruncated (US3-AS2).

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T013 Run the full unit suite (`xcodebuild test … -destination 'platform=macOS,arch=arm64' -only-testing:lottoApp2Tests -skipMacroValidation`) and make sure it is green (SC-004).
- [ ] T014 [P] Visual check per quickstart "Visual checks": render the never-synced full and compact cards in light and dark, idle and fetching, with a throwaway `ImageRenderer` test, and delete it afterwards.
- [ ] T015 [P] In `lottoApp2/Documentation.docc/Documentation.md`, mark TODO item 003's "Fetch" button sub-item as done, matching how other finished items are marked.
- [ ] T016 Once T001–T015 are complete, move LTA-3 from `in-progress` to `in-review` in `.tickets/3.yaml` (implementation done, not yet merged).

---

## Dependencies & Execution Order

- T001 → T002 (foundational) block every story.
- US1: T003 and T004 [P] (tests first) → T005 → T006 → T007 → T008 → T009.
- US2 needs T007 (`SyncIcon`) from US1; T010 → T011.
- US3 needs T008 (the full-card label); T012.
- Polish comes after all the stories.

## Parallel Opportunities

- T003 ∥ T004: different test files.
- T014 ∥ T015: preview check and docs.
- Most tasks touch a shared card file, so the rest run in order.

## Implementation Strategy

- **MVP** = Phases 2–3 (US1): the full card plus correct reducer state and alerts, which is shippable on its own.
- Then US2 (compact, the most common layout), then US3's large-text preview. Commit at the end of every phase.
