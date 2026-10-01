---

description: "Task list for LTA-17 — fix repo filenames and docs TODO"
---

# Tasks: Fix Repo Filenames and Docs TODO

**Input**: Design documents from `/specs/010-fix-repo-filenames/`

**Prerequisites**: plan.md, spec.md, research.md, quickstart.md

**Tests**: Per the project constitution (Principle III, Test-First — NON-NEGOTIABLE), reducer and Domain
business-logic tasks MUST include `TestStore`/unit test tasks written before their implementation. This
feature changes no reducer and no Domain behaviour (plan, Constitution Check), so it has no new test tasks.
The regression check is the existing suite, with its count compared before and after (T001, T006).

**Organization**: Tasks are grouped by user story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

---

## Phase 1: Setup

**Purpose**: Record the baseline that SC-002 is measured against.

- [X] T001 Record the baseline unit-test count. Run `xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests -skipMacroValidation`, falling back to the `My Mac` destination if the simulators are wedged. Write the count and the destination used into the Notes section of specs/010-fix-repo-filenames/tasks.md (quickstart §1).

---

## Phase 2: Foundational

None. The two stories touch disjoint files.

---

## Phase 3: User Story 1 — Find the sources repository by its real name (Priority: P1) 🎯 MVP

**Goal**: Both files are named after `SourcesRepoImpl`, and the project guide no longer carries the misspelling.

**Independent Test**: `git grep -n "Sorces" -- ':!specs/' ':!.tickets/17.yaml'` prints nothing. The build and
tests are green with the T001 count (quickstart §2, §4).

- [ ] T002 [P] [US1] Rename lottoApp2/Data/Repos/SorcesRepoImp.swift to lottoApp2/Data/Repos/SourcesRepoImpl.swift with `git mv`, changing no content (FR-001, FR-003, research R1).
- [ ] T003 [P] [US1] Rename lottoApp2Tests/SorcesRepoImpTests.swift to lottoApp2Tests/SourcesRepoImplTests.swift with `git mv`, changing no content (FR-002, FR-003).
- [ ] T004 [US1] Edit CLAUDE.md in two places (FR-005):
  - Line 19: drop the clause about `SorcesRepoImp.swift` / `SorcesRepoImpTests.swift` still being misspelled filenames. Keep the general "correct existing typos, don't propagate them" rule and the `firstRecord` note.
  - Line 113: change the layout entry `SorcesRepoImp (SourcesRepo.live)` to `SourcesRepoImpl (SourcesRepo.live)`.
- [ ] T005 [US1] Run `git grep -n "Sorces" -- ':!specs/' ':!.tickets/17.yaml'` and fix any remaining hit outside the historical specs (FR-006, SC-001). Leave `specs/001…009` untouched (FR-010).
- [ ] T006 [US1] Build and run the unit tests with the T001 command and destination. Require 0 failures and a count equal to the T001 baseline. Confirm with `git log --follow` that both renamed files' history reaches back past the rename (SC-002, SC-005; quickstart §3–4).

**Checkpoint**: US1 is complete and can be committed on its own.

---

## Phase 4: User Story 2 — Read an accurate project overview (Priority: P2)

**Goal**: The DocC main page has a real summary, no typos, the shipped scenario option marked, and a TODO list
that matches what has shipped.

**Independent Test**: quickstart §5. `docc convert` gives no warnings, there are 0 `START_MENU_TOKEN`s, every
`++` line names a spec, and no open line copies a `.tickets/` title.

- [ ] T007 [P] [US2] In lottoApp2/Documentation.docc/Documentation.md, replace the `<!--@START_MENU_TOKEN@-->Summary<!--@END_MENU_TOKEN@-->` line with a one-sentence summary of the app: it syncs lottery draw history from sources and runs chains of processing blocks over it (FR-007).
- [ ] T008 [US2] In the same file's S01 scenario, fix the spelling and do not rewrite it (FR-009):
  - "alunched" → "launched", "highlite" → "highlight", "les than" → "less than", "it's form" → "its form".
  - Mark option `(o1) - basic` as shipped before spec 001 (the initial start page).
  - Mark option `(o2) - update 01` as shipped in spec 009 (missing-records estimate).
  - Mark the never-synced blue state as shown by the "Fetch" button, shipped in spec 008.
- [ ] T009 [US2] In the same file, rebuild the `## TODO` list in its `++` / `-+` / `--` outline style (FR-008, research R4):
  - one `++` line per shipped spec, each naming it: 001 MBNet source, 002 blocks page navigation, 003 block pipeline, 004 sync error details, 005 skipped rows note, 006 chain-builder design gaps, 007 source cards, 008 Fetch on never-synced sources, 009 missing records estimate;
  - a `++` line for UI automation tests (an XCUITest happy path in `lottoApp2UITests`, LTA-23);
  - a closing line that points to `.tickets/` (LTA-N) for open feature work, including linting and view snapshot tests.

  Remove the stale startPage `--`/`-+` items, which have all shipped, and do not copy any backlog ticket.
- [ ] T010 [US2] Validate the page per quickstart §5:
  - Run `xcrun docc convert lottoApp2/Documentation.docc --output-path "$TMPDIR/lta17.doccarchive"` and require no warnings.
  - Check that `grep -c START_MENU_TOKEN` prints 0.
  - Check that every `++` line names a spec or ticket (SC-003, SC-004).

**Checkpoint**: US2 is complete.

---

## Phase 5: Polish

- [ ] T011 Re-run the quickstart end to end (§2–§5) on the final tree. Then tick the US1/US2 acceptance scenarios against the result, and record anything that deviated in the Notes below.

---

## Dependencies & Execution Order

- T001 comes before everything (baseline).
- US1: T002 ∥ T003, then T004, then T005, then T006.
- US2: T007, then T008, then T009, then T010. These tasks all edit one file, so only T007 is marked [P], and only relative to US1.
- US1 and US2 are independent and can run in parallel after T001. T011 comes last.

### Parallel example

```text
Task: T002 git mv SorcesRepoImp.swift → SourcesRepoImpl.swift
Task: T003 git mv SorcesRepoImpTests.swift → SourcesRepoImplTests.swift
Task: T007 DocC summary line
```

## Implementation Strategy

1. T001 baseline, then US1 (T002–T006), committed as the MVP. Removing the misspelling is the defect the ticket is named for.
2. US2 (T007–T010), committed.
3. T011 polish, committed.

## Notes

- Baseline (T001): `iPhone 17 Pro` simulator (iOS 27.0), `xcresulttool` summary: totalTestCount 348, passed 348 (408 including parameterized-argument runs), 0 failed, 0 skipped. `** TEST SUCCEEDED **`.
