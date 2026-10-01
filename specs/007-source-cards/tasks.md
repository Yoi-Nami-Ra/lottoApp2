---

description: "Task list for 007 — compact and wide source cards (LTA-28 + LTA-29)"
---

# Tasks: Compact and Wide Source Cards

**Input**: Design documents from `/specs/007-source-cards/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ui-contracts.md, quickstart.md

**Tests**: Per the project constitution (Principle III, Test-First — NON-NEGOTIABLE), reducer and Domain business-logic tasks MUST include `TestStore`/unit test tasks authored before their implementation. The generic "tests optional" default does NOT apply to this project for those units. Layout-only view work is verified through `#Preview`s (quickstart §2).

**Organization**: Tasks are grouped by user story. Commit at the end of every phase.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5 from spec.md)

## Path Conventions

- App: `lottoApp2/Presentation/StartPage/…`; tests: `lottoApp2Tests/Reducers/…`; design: `design/…`; tickets: `.tickets/…`
- Test command: `xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests` (Mac fallback: `-destination 'platform=macOS,arch=arm64'`)

---

## Phase 1: Setup — approve the design (delivers US5, research R10)

**Purpose**: Make the LTA-28 proposal the approved design that the rest of the work is built and checked against.

- [ ] T001 Copy `design/proposal/28-source-cards.html` to `design/final/source-cards.html`, then edit the copy:
  - retitle it "LTA-28 · Compact and wide source cards" and drop the "proposal" / "Lo-fi" wording from the heading and lede;
  - in the "Expanded and selected" frame, add the skipped-records note row ("⚠ 3 records skipped in last sync", warningYellow tint) as a full-width row between the Records / Last sync row and the First / Latest record row;
  - make the badges read "Last synced: 27 Sep 2026 at 09:12" (the app's real format) instead of "1 day ago";
  - add to the "Expanded and selected" caption that tapping inside the details also selects the card;
  - in the implementer notes, replace "Open questions" wording with the decisions from spec.md §Clarifications and research R4–R9 (the VoiceOver label is name + "Last synced: …"/"Not synced").
- [ ] T002 Render `design/final/source-cards.png` from `design/final/source-cards.html` with the headless Chrome command in `design/README.md` (`--window-size=1640,1900`, adjusted so every frame fits); then delete `design/proposal/28-source-cards.html` and `design/proposal/28-source-cards.png`.
- [ ] T003 [P] Update `.tickets/28.yaml` (`designs: [design/final/source-cards.html]`, `status: done`) and `.tickets/29.yaml` (`designs: [design/final/source-cards.html]`, `blocked_by: []`, `status: in-progress`).

**Checkpoint**: `design/final/source-cards.{html,png}` exist, the proposal is gone, and the tickets point at the approved file.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: Shared card parts and the expand flag, which every story's view needs.

**⚠️ CRITICAL**: No user-story view work can begin until this phase is complete.

### Tests (write first, see them fail)

- [ ] T004 [P] Add a failing test `action_disclosureButtonTapped_togglesExpanded` in `lottoApp2Tests/Reducers/SourceEntryTests.swift`. Send `.disclosureButtonTapped` twice from a collapsed state and assert `isExpanded` goes `true` then `false`, with no received actions (contracts §1: "`disclosureButtonTapped` changes only `isExpanded`. It never emits a delegate.").
- [ ] T005 [P] Add failing tests in `lottoApp2Tests/Reducers/SourceEntryTests.swift`:
  - `sourceEntryState_startsCollapsed`: `Source.mbnetMock.sourceEntryState(now:)` has `isExpanded == false`;
  - `apply_keepsExpanded`: an expanded state stays expanded after `apply(.refreshedMbnetMock, now:)` ("`apply(_:now:)` never writes `isExpanded`").

### Implementation

- [ ] T006 Add `var isExpanded: Bool = false` to `SourceEntry.State` and the `disclosureButtonTapped` case to `SourceEntry.Action` in `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift`. The reducer handles it with `state.isExpanded.toggle(); return .none`. Add a doc comment: compact card only, never persisted. T004 and T005 now pass.
- [ ] T007 Create `lottoApp2/Presentation/StartPage/Widgets/SourceCardParts.swift` (research R4, contracts §5). Move `SourceCardStyle` out of `SourceEntryView.swift` unchanged. Extract three parts from `SourceEntryView`'s current code with the same look and accessibility:
  - `SyncStatusBadge(lastSync: Date?, severity: SourceEntry.SyncSeverity)`;
  - `SkippedRecordsNote(count: Int)`;
  - `RefreshButtonStyle(isRefreshing: Bool)`, a `ViewModifier` for the foreground, background, border and corners; plus a `RefreshIcon(isRefreshing:)` view for the spinning image.

  Move the tokens both cards need (the severity colour switch, refresh colours, light/dark tint opacities, card colours and metrics, the refresh spin animation, and the copy "Not synced", "N/A", "First Record:", "Latest Record:", `lastSynced(_:)`, `skippedInLastSync(_:)`) to `internal` statics under `// MARK: - Resources`. Give the parts their own light/dark `#Preview`s.
- [ ] T008 Refactor `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift` to use `SyncStatusBadge`, `SkippedRecordsNote`, `RefreshButtonStyle`/`RefreshIcon` and the shared tokens. Remove its now-duplicated `fileprivate` tokens. Its layout, accessibility, previews and mocks stay unchanged.
- [ ] T009 Build and run the full unit suite (test command above). Everything is green, and the `SourceEntryView` previews look the same as before.

**Checkpoint**: The flag exists and is tested, and the parts are shared. Commit: `feat(007): add the expand flag and share the source card parts`.

---

## Phase 3: User Story 1 — Scan and choose sources on a narrow screen (P1) 🎯 MVP

**Goal**: At compact width each source is one row (dot · name · refresh · chevron) that selects and refreshes as today.

**Independent Test**: At compact width with several sources, each card is one row of at least 52 pt. Tapping a row selects it and enables Next. Tapping refresh syncs that source without selecting it. A never-synced source shows "Not synced".

### Tests (regression guard — passes once T006 lands; it pins that expanding never touches selection)

- [ ] T010 [P] [US1] Add a test `selection_fromExpandedEntry_unchanged` in `lottoApp2Tests/Reducers/StartPageTests.swift`. With two seeded entries, expand one (`.sources(.element(id:, action: .disclosureButtonTapped))`), assert `selectedSourceID` stays `nil`, then send `.cardTapped` on it. The existing selection outcome holds (`selectedSourceID` is set, `isSelected` is mirrored), and `isExpanded` stays `true`.

### Implementation

- [ ] T011 [US1] Create `lottoApp2/Presentation/StartPage/Widgets/CompactSourceEntryView.swift` (research R5, contracts §4) with `store: StoreOf<SourceEntry>`. The row is an `HStack`:
  - a 12 pt severity dot in the severity colour;
  - `Text(store.name)` with a `.compactName` font token (`.headline`), wrapping;
  - a checkmark when `isSelected`;
  - inline "Not synced" (`.caption`, `textSecondary`) when `lastSync == nil`;
  - an icon-only refresh `Button` sending `.refreshButtonTapped`, styled with `RefreshButtonStyle` and `RefreshIcon`, sized by tokens (36×32), `.fixedSize()`, and `.disabled(store.isRefreshing)`;
  - a chevron `Button` (`chevron.down` / `chevron.up`) sending `.disclosureButtonTapped`, `.fixedSize()`.

  The row has `minHeight: .compactRowMinHeight` (52). The card uses `SourceCardStyle(isSelected:)`, `.contentShape(Rectangle())` and `.onTapGesture { store.send(.cardTapped) }`, plus `.alert($store.scope(state: \.alert, action: \.alert))`. All values are `fileprivate static` tokens under `// MARK: - Resources`.
- [ ] T012 [US1] In `lottoApp2/Presentation/StartPage/StartPageView.swift`, read `@Environment(\.horizontalSizeClass)`. When `.compact`, render the existing `List` with `CompactSourceEntryView` rows (same row background, separator and insets as today). Otherwise keep the existing `SourceEntryView` list for now (it becomes the grid in US3).
- [ ] T013 [P] [US1] Add light and dark `#Preview`s to `CompactSourceEntryView.swift`: collapsed, selected, refreshing, and never synced. Use preview mocks (reuse the `SourceEntry.State.mock1*` fixtures).
- [ ] T014 [US1] Add compact-width `#Preview`s to `StartPageView.swift`. They show four sources (add a fourth preview-only `Source` fixture in `lottoApp2/Presentation/Previews/PreviewFixtures.swift` if needed) in light and dark with `.environment(\.horizontalSizeClass, .compact)`, and check SC-001 on the canvas.
- [ ] T015 [US1] Build and run the full unit suite. It is green.

**Checkpoint**: The compact list works on iPhone. Commit: `feat(007): compact source card row on narrow screens`.

---

## Phase 4: User Story 2 — Expand a compact card to see its details (P1)

**Goal**: The chevron reveals the record count, last-sync badge, skipped note and first/latest dates inline. Several cards can be open, every card starts closed, and the state survives reloads and syncs.

**Independent Test**: Expand one card, then a second; both are open. Collapse the first. Reload the list and both flags survive. Relaunch and every card is collapsed.

### Tests (write first; T016 fails until T018, T017 guards `apply` and the failure path)

- [ ] T016 [P] [US2] Add a failing test `sourcesResponse_keepsExpandedForSurvivors` in `lottoApp2Tests/Reducers/StartPageTests.swift`. Start with an expanded `mbnet` entry, then send `.sourcesResponse([.mbnetMock, .lottoMock])`. Assert `mbnet` keeps `isExpanded == true` and `lotto` starts `false`. Assert a source removed by a reload drops out with its flag (contracts §2).
- [ ] T017 [P] [US2] Add tests in `lottoApp2Tests/Reducers/StartPageTests.swift`:
  - `expand_twoEntries_bothStayExpanded`;
  - `refresh_success_keepsExpanded`;
  - `refresh_failure_keepsExpanded`, which covers the failure alert path and keeps `isExpanded == true`.

### Implementation

- [ ] T018 [US2] In `lottoApp2/Presentation/StartPage/StartPage.swift`, `.sourcesResponse` also carries `entry.isExpanded = existing.isExpanded`. Update the comment that lists the carried-over transient UI state. T016 and T017 now pass.
- [ ] T019 [US2] In `CompactSourceEntryView.swift`, render the details when `store.isExpanded`:
  - a divider;
  - a two-column `Grid` with Records (`recordsCount` or "N/A") | `SyncStatusBadge`;
  - when `skippedInLastSync` is non-nil, `SkippedRecordsNote` spanning both columns (`gridCellColumns(2)`);
  - First record | Latest record (the full card's date format and "N/A" fallback).

  Use tokens for the paddings and spacings. The card's tap gesture covers the details too (clarification 1). The chevron sends `store.send(.disclosureButtonTapped, animation: reduceMotion ? nil : .disclosure)` using `@Environment(\.accessibilityReduceMotion)` (research R9).
- [ ] T020 [P] [US2] Add light and dark `#Preview`s to `CompactSourceEntryView.swift` for: expanded, expanded and selected, expanded with the skipped note, and expanded never-synced ("N/A").
- [ ] T021 [US2] Build and run the full unit suite. It is green.

**Checkpoint**: The compact card fully replaces the full card's information at narrow widths. Commit: `feat(007): expand compact source cards inline`.

---

## Phase 5: User Story 3 — See several full cards side by side on a wide screen (P2)

**Goal**: At regular width, today's full cards sit in an adaptive grid with equal row heights, and Next has a fixed width at the trailing edge.

**Independent Test**: In the regular-width preview at iPad landscape width there are three columns, cards in a row share its height, and Next sits at the trailing edge at 320 pt. Selection and refresh behave as today (existing suites).

### Implementation

- [ ] T022 [US3] In `lottoApp2/Presentation/StartPage/Widgets/SourceCardParts.swift`, add `.frame(maxHeight: .infinity, alignment: .top)` to `SourceCardStyle`, after the content's padding and before its background, so a grid cell fills its row (research R6). Comment why it is a no-op in the `List`.
- [ ] T023 [US3] In `lottoApp2/Presentation/StartPage/StartPageView.swift`, replace the non-compact branch with `ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: .gridMinColumn), spacing: .gridSpacing)], spacing: .gridSpacing) { ForEach(…) { SourceEntryView(store:) } }.padding(.gridPadding) }`, with tokens `gridMinColumn = 320`, `gridSpacing = 16` and `gridPadding = 16`.
- [ ] T024 [P] [US3] In `lottoApp2/Presentation/StartPage/Widgets/BottomActionBar.swift`, read `@Environment(\.horizontalSizeClass)`. At `.regular`, the button label gets `.frame(width: .nextRegularWidth)` (320) instead of `maxWidth: .infinity`, and the bar's content aligns `.trailing`. Compact is unchanged. Add regular-width light and dark previews.
- [ ] T025 [US3] Add regular-width `#Preview`s to `StartPageView.swift` (`.environment(\.horizontalSizeClass, .regular)`, iPad landscape frame 1180×820) in light and dark. Check SC-005 (three columns) and equal row heights on the canvas.
- [ ] T026 [US3] Build and run the full unit suite. It is green.

**Checkpoint**: The wide layout is done. Commit: `feat(007): full source cards in an adaptive grid on wide screens`.

---

## Phase 6: User Story 4 — Use the compact card with assistive technologies and large text (P3)

**Goal**: VoiceOver reads the name and status as text plus the two button labels, and at AX sizes the name wraps while the details stack.

**Independent Test**: The AX5 previews (collapsed and expanded, light and dark) show the name wrapping, the buttons keeping their size, and one-column details. VoiceOver reads "MBNet Server, Last synced: …", "Refresh" and "Show details".

### Implementation

- [ ] T027 [US4] In `CompactSourceEntryView.swift`, set the accessibility:
  - the dot is `.accessibilityHidden(true)`;
  - the card is `.accessibilityElement(children: .contain)`, labelled with `Text(name)` plus the status ("Last synced: …" / "Not synced"), with traits `.isButton` (+ `.isSelected`) and the "Choose this source" action;
  - refresh is labelled "Refresh" / "Refreshing";
  - the chevron is labelled "Show details" / "Hide details".

  All copy uses `LocalizedStringKey` tokens (research R8, contracts §4).
- [ ] T028 [US4] In `CompactSourceEntryView.swift`, make the details use an `AnyLayout` that is a `VStackLayout` when `dynamicTypeSize.isAccessibilitySize`, and the two-column grid otherwise. In the row, the name gets `fixedSize(horizontal: false, vertical: true)` and the buttons `.fixedSize()`, so the name wraps before the buttons shrink (FR-013).
- [ ] T029 [P] [US4] Add AX5 `#Preview`s to `CompactSourceEntryView.swift`: collapsed light, collapsed dark with a long name, expanded light, and expanded dark with the skipped note. Add an AX5 compact-width preview to `StartPageView.swift`.

**Checkpoint**: Accessibility meets US4. Commit: `feat(007): accessibility for the compact source card`.

---

## Phase 7: Polish & cross-cutting

- [ ] T030 Run the full unit suite, the quickstart §2 canvas checks (every new and refactored preview in light and dark), and the quickstart §3 run. That includes an iPad entering and leaving a narrow split view, which must keep the selection, any sync in flight, and every expanded compact card (US3-AS5, Edge Cases). Fix any regression.
- [ ] T031 [P] Update `CLAUDE.md` §Architecture layout: `StartPage/Widgets` now holds the compact card and the shared `SourceCardParts`. Note that the start page switches by horizontal size class.
- [ ] T032 [P] Move `.tickets/29.yaml` to `status: in-review`.
- [ ] T033 Mark every task in `specs/007-source-cards/tasks.md` done and commit: `chore(007): polish and move LTA-29 to in-review`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies. It runs first so the build is checked against the approved design.
- **Foundational (Phase 2)**: Depends on Setup and blocks all story phases. T004 and T005 come before T006, and T007 before T008.
- **US1 (Phase 3)**: Depends on Phase 2.
- **US2 (Phase 4)**: Depends on US1 (it extends `CompactSourceEntryView`).
- **US3 (Phase 5)**: Depends on Phase 2 only (T022 touches `SourceCardParts`). It can run in parallel with US1 and US2, except that T023 and T012 both edit `StartPageView.swift`.
- **US4 (Phase 6)**: Depends on US2 (the details exist).
- **Polish (Phase 7)**: Depends on all phases.

### Parallel Opportunities

- T003 runs alongside T001 and T002 (different files).
- T004 and T005 are in the same file but are independent test functions; write them together.
- T010 and T013 run in parallel. T016, T017 and T020 run in parallel. T024 runs alongside T022 and T023. T031 and T032 run in parallel.

## Parallel Example: User Story 2

```text
Task: "T016 sourcesResponse_keepsExpandedForSurvivors in lottoApp2Tests/Reducers/StartPageTests.swift"
Task: "T020 expanded previews in CompactSourceEntryView.swift"
```

## Implementation Strategy

- **MVP**: Phases 1–4 (the approved design + compact row + expand). That replaces the phone layout without losing information.
- **Then**: US3 (wide grid), then US4 (accessibility polish). Each phase ends green and is committed on its own.
