---

description: "Task list for 009 — missing records estimate (LTA-4)"
---

# Tasks: Missing Records Estimate

**Input**: Design documents from `/specs/009-missing-records-estimate/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/domain-contracts.md, quickstart.md

**Tests**: Per the project constitution (Principle III, Test-First — NON-NEGOTIABLE), reducer and Domain business-logic tasks MUST include `TestStore`/unit test tasks authored before their implementation. The generic "tests optional" default does NOT apply to this project for those units. Layout-only view work is verified through `#Preview`s.

**Organization**: Tasks are grouped by user story. Commit at the end of every phase.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US3 from spec.md)

## Path Conventions

- App: `lottoApp2/…`. Tests: `lottoApp2Tests/…`.
- Test command: `xcodebuild test -scheme lottoApp2 -destination 'platform=macOS,arch=arm64' -only-testing:lottoApp2Tests -skipMacroValidation`

---

## Phase 1: Setup

- [X] T001 Confirm the baseline: the full unit suite is green on `main`'s tip, using the test command above.

---

## Phase 2: Foundational — the Domain rule and its persistence (blocking)

**Purpose**: The cadence exists, is stored at sync, and reaches `Source`. Every story needs it.

### Tests (write first, see them fail)

- [X] T002 [P] Create `lottoApp2Tests/Domain/DrawCadenceTests.swift` with failing tests for `DrawCadence.measure(drawDates:calendar:)` using `.drawWeeks` and fixed UTC dates (contracts §1). Cover:
  - an empty input gives `nil`;
  - 6 draws in `[W0 − 14d, W0)` give `drawsInWindow == 6`;
  - a draw exactly at `W0 − 14d` is counted, and history is long enough;
  - history starting 1 day after `W0 − 14d` gives `nil`;
  - a window holding no draws gives `nil`;
  - a draw exactly at `W0` is excluded;
  - a latest draw on a Sunday and on a Monday each pick the right `W0`;
  - `drawsPerDay == 6.0 / 14`.
- [X] T003 [P] Add failing tests for `missing(since:now:)` in the same file:
  - 6 in window over 7 days gives 3 (exact, research R2);
  - 6 in window over 1 day gives 0;
  - a gap of 14/6 days (the first moment N = 1) gives 1, and one second less gives 0;
  - a large gap gives the full count;
  - `now` before `since` gives 0.
- [X] T004 [P] Add failing tests to `lottoApp2Tests/LocalStoreTests.swift`:
  - `save` writes `SourceMeta.drawsInWindow` from the merged set;
  - the value survives a new `LocalStore.fileBacked` on the same root;
  - a `meta.json` without `drawsInWindow` decodes with `nil`;
  - a history too short for the window stores `nil`.
- [X] T005 [P] Add a failing-guard test to `lottoApp2Tests/SorcesRepoImpTests.swift`. Override `localStore.listDrawsFor` to record calls, then call `listKnownSources`. Assert that the listed `Source.cadence` comes from the stored metadata and that `listDrawsFor` is never called (SC-004, clarification 1).

### Implementation

- [X] T006 Create `lottoApp2/Domain/BLogic/DrawCadence.swift`:
  - `nonisolated struct DrawCadence: Equatable, Sendable` with `let drawsInWindow: Int` (≥ 1);
  - computed `drawsPerDay`;
  - `static func measure(drawDates:calendar:) -> DrawCadence?` with window `[W0 − 14 days, W0)`, where `W0` is the start of the `.weekOfYear` interval holding the latest date, returning `nil` when the earliest date is after the window start or the window holds 0 draws;
  - `func missing(since:now:) -> Int`, equal to `Int((Double(drawsInWindow) * max(0, now.timeIntervalSince(since)) / fortnight).rounded(.down))`;
  - `extension Calendar { nonisolated static let drawWeeks }`, a Gregorian calendar in UTC with `firstWeekday = 2`.

  Named constants go under `// MARK: - Resources` (`windowDays = 14`, `fortnight` in seconds). T002 and T003 now pass.
- [X] T007 Add `let cadence: DrawCadence?` (default `nil` in `init`) to `Source` in `lottoApp2/Domain/Ents/Source.swift`, with a doc comment.
- [X] T008 In `lottoApp2/Data/Sources/LocalStore.swift`:
  - add `var drawsInWindow: Int? = nil` to `SourceMeta`, adding it to `CodingKeys` and reading it with `decodeIfPresent`;
  - make `LocalStore.meta(name:draws:asOf:skipped:)` set it to `DrawCadence.measure(drawDates: draws.map(\.date), calendar: .drawWeeks)?.drawsInWindow`.

  T004 now passes.
- [X] T009 In `lottoApp2/Data/Repos/SorcesRepoImp.swift`, make `SourceMeta.source(displayName:)` map `drawsInWindow` to `Source.cadence` (`DrawCadence(drawsInWindow:)` when the value is ≥ 1).
- [X] T010 Build and run the full suite. It is green, including T005.

**Checkpoint**: The cadence is stored and listed. Commit: `feat(009): measure a source's draw cadence at sync (LTA-4)`.

---

## Phase 3: User Stories 1 + 2 — the estimate and the severity it drives (P1) 🎯 MVP

**Goal**: Cards know the missing estimate and colour by it, falling back to the day-based rule. They show "~N missing" next to Latest Record.

**Independent Test**: For a source with a known cadence, the estimate and badge colour match the contracts §3 table at 0, 1 and many missing. A source without a cadence keeps the day-based colours. Both cards show the line only when N > 0.

### Tests (write first, see them fail)

- [ ] T011 [P] [US2] Add failing tests to `lottoApp2Tests/Reducers/SourceEntryTests.swift` for the contracts §3 table, via `Source.sourceEntryState(now:)`:
  - never synced gives `.notSynced` and `missingEstimate == nil`;
  - no cadence gives the day-based severity at the 0 s, 2 d and 4 d thresholds, with `missingEstimate == nil`;
  - a cadence without `latestRecord` gives the day-based severity;
  - a cadence with an estimate of 0, 1, 2 or 5 gives `.low`, `.medium`, `.high` or `.high`, with a matching `missingEstimate`, even when `lastSync` is recent or old;
  - `apply(_:now:)` recomputes both from the new source.
- [ ] T012 [P] [US1] Add a failing test `refresh_success_recomputesTheEstimate` to `lottoApp2Tests/Reducers/StartPageTests.swift`. A seeded entry is refreshed with a source carrying a cadence and an old latest record. After the response, `missingEstimate` and `lastSyncSeverity` match the injected `\.date`.

### Implementation

- [ ] T013 [US2] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift`:
  - add `var missingEstimate: Int?` to `SourceEntry.State`, with a doc comment;
  - add `SyncSeverity.init(source: Source, now: Date)` following contracts §3, keeping `init(lastSync:now:)` as the fallback;
  - route `sourceEntryState(now:)` and `apply(_:now:)` through one fileprivate helper that sets `missingEstimate` and `lastSyncSeverity`;
  - add tokens for the estimate thresholds (`yellowFrom = 1`, `redFrom = 2`).

  T011 and T012 now pass.
- [ ] T014 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceCardParts.swift`, give `RecordDateDetail` an optional `missing: Int? = nil`. When it is greater than 0, render `HStack { Image(.missingRecords) (accessibilityHidden); Text(.missingRecords(n)) }` in `.caption` and `textSecondary` under the date, with no `lineLimit`. Add an accessibility label `.missingRecordsSpoken(n)` ("about N missing"). Copy, icon, colour, font and spacing are tokens (research R6), and N uses `formatted()`, so 1204 reads "~1,204 missing" in en_US (FR-008). Extend the parts preview with a 3 and a 1,204 line.
- [ ] T015 [US1] Pass `missing: store.missingEstimate` to the `.latest` `RecordDateDetail` in `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift` and in both detail layouts of `lottoApp2/Presentation/StartPage/Widgets/CompactSourceEntryView.swift`.
- [ ] T016 [P] [US1] Add preview mocks and light/dark `#Preview`s to `SourceEntryView.swift` for: an estimate of 0 (green, no line), 1 (yellow, "~1 missing"), many (red, "~3 missing"), and no estimate. Add the expanded compact equivalents to `CompactSourceEntryView.swift`. Give `Source.mbnetMock` in `lottoApp2/Presentation/Previews/PreviewFixtures.swift` a cadence, so the start page previews show the rule.
- [ ] T017 [US1] Build and run the full suite. It is green.

**Checkpoint**: The estimate drives the colour and is shown. Commit: `feat(009): colour sources by their missing-records estimate (LTA-4)`.

---

## Phase 4: User Story 3 — read the estimate in every appearance (P3)

- [ ] T018 [US3] Add AX5 `#Preview`s with the missing line, in light and dark, to `SourceEntryView.swift` and `CompactSourceEntryView.swift` (expanded). Check that the line wraps at word boundaries, the cards' reflow is unchanged, and VoiceOver hears "about N missing" (SC-005, FR-008).

**Checkpoint**: Commit: `feat(009): largest-text previews of the missing-records line (LTA-4)`.

---

## Phase 5: Polish & cross-cutting

- [ ] T019 Run the full suite plus a render check of both cards with the line (throwaway `ImageRenderer` test, not committed). Fix any regression.
- [ ] T020 [P] Update `CLAUDE.md` §Domain model: add a "Missing records" bullet (DrawCadence, persisted as `SourceMeta.drawsInWindow`, severity from the estimate with the day-based fallback).
- [ ] T021 [P] Move `.tickets/4.yaml` to `status: in-review`.
- [ ] T022 Mark every task done and commit: `chore(009): polish and move LTA-4 to in-review`.

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5.
- In Phase 2: T002, T003, T004 and T005 come before T006 and T008. T006 comes before T007, T008 and T009.
- In Phase 3: T011 and T012 come before T013. T013 comes before T014 and T015, and T015 before T016.
- US1 and US2 share one phase because the estimate and the colour come from the same mapping (contracts §3). Neither is shippable alone without contradicting the other (spec US2 "ships with Story 1").

## Parallel Opportunities

- T002, T003 and T004 (different files, apart from T002 and T003 sharing a new file).
- T011 and T012. T020 and T021.

## Implementation Strategy

- **MVP**: Phases 1–3. Phase 4 adds the AX previews, and Phase 5 polishes.
