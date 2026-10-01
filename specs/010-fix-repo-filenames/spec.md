# Feature Specification: Fix Repo Filenames and Docs TODO

**Feature Branch**: `010-fix-repo-filenames`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "LTA-17 — Fix misspelled repo filenames and stale docs TODO. Rename `Data/Repos/SorcesRepoImp.swift` and `lottoApp2Tests/SorcesRepoImpTests.swift` to match the `SourcesRepoImpl` type (update the Xcode project and CLAUDE.md, which mentions the misspelling). Refresh the TODO list in `Documentation.docc/Documentation.md`, which predates specs 001/002, and fill in its `Summary` placeholder. Analysis notes: the Xcode project uses file-system-synchronized groups so no pbxproj edit is needed; new names SourcesRepoImpl.swift / SourcesRepoImplTests.swift; historical specs/ docs keep old names (recommended default); also fix typos in Documentation.md; no behaviour change, build + unit tests stay green."

## Clarifications

### Session 2026-10-01

- Q: Should the docs TODO list repeat the open work items, or point to the ticket backlog for them? → A: List the shipped areas (specs 001–009) and the general open questions that have no ticket; point to the `.tickets/` backlog for open feature work instead of copying it.
- Q: Should the docs' S01 scenario text be brought up to date with shipped behaviour, or only have its typos fixed? → A: Fix the typos and mark each scenario option that has shipped with its spec (the missing-records estimate, option o2, shipped in spec 009); don't rewrite the scenario.

## User Scenarios & Testing *(mandatory)*

The people served here are the maintainers of the codebase (and the coding agents working on it). Nothing changes for people using the app.

### User Story 1 - Find the sources repository by its real name (Priority: P1)

A maintainer looks for the file that implements the sources repository, or its tests, by the name of the type they hold. Today the files are misspelled ("Sorces…Imp") while the type is spelled correctly ("Sources…Impl"), so a search by type name finds the type but not the file, and the project guide has to carry a warning about the misspelling. After this change the files are named after the type they hold, and the warning is gone.

**Why this priority**: This is the defect the ticket is named for. The misspelling has already leaked into five specs and keeps being copied, so it is worth stopping at the source.

**Independent Test**: Search the working tree, outside the historical specs, for the misspelled name. Nothing is found. The project builds and every unit test passes, with the same test count as before.

**Acceptance Scenarios**:

1. **Given** the renamed files, **When** a maintainer searches the code, project guide and ticket backlog for "Sorces", **Then** nothing is found outside the historical `specs/` folders and the LTA-17 ticket's own history.
2. **Given** the renamed files, **When** the app is built and the unit tests are run, **Then** the build succeeds and every test passes, with the same number of tests as before the rename.
3. **Given** the renamed files, **When** a maintainer reads the project guide, **Then** it names the files correctly and no longer tells readers to keep the old misspelled names.
4. **Given** the rename, **When** a maintainer looks at a renamed file's history, **Then** the file's earlier history is still reachable as a rename, not lost as a delete-and-add.

---

### User Story 2 - Read an accurate project overview (Priority: P2)

A maintainer opens the project's documentation catalogue. Today its summary is the template placeholder, its scenario text has typos, and its TODO list stops before spec 001, marking work as open that shipped long ago. After this change the summary says what the app is, the typos are fixed, and the TODO list reflects what has shipped and what is still open.

**Why this priority**: It is the second half of the ticket. The overview is read less often than the code, so a stale overview costs less than a misleading filename.

**Independent Test**: Open the documentation catalogue's main page. The summary is one real sentence, there is no template placeholder, and every item in the TODO list matches the state of the code and of the ticket backlog.

**Acceptance Scenarios**:

1. **Given** the refreshed page, **When** a maintainer reads its summary, **Then** it is a one-sentence description of the app, with no template placeholder left on the page.
2. **Given** the refreshed page, **When** a maintainer reads the TODO list, **Then** each shipped area (specs 001–009) is shown as done, each listed open question has no ticket of its own, and open feature work is found through a pointer to the ticket backlog rather than a copy of it.
3. **Given** the refreshed page, **When** a maintainer reads the scenario text, **Then** it has no spelling mistakes, and each scenario option that has shipped names the spec that shipped it.
4. **Given** the refreshed page, **When** the documentation catalogue is built, **Then** it builds without new warnings.

---

### Edge Cases

- **Historical specs**: specs 001–009 mention the old filenames in their plans and task lists. They record what was done at the time and are left unchanged; a reader of an old task finds the file by its new name with one search.
- **Ticket backlog**: the LTA-17 ticket names the old files in its description. That text describes the ticket's own task and stays as written.
- **Open feature branches**: a branch that still edits the old filename (for example `008-fetch-never-synced`) will see a rename on merge. Version control follows renames, so this is accepted and not worked around.
- **Case-insensitive file system**: the new names differ from the old ones by more than letter case, so the rename cannot be swallowed by a case-insensitive disk.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The sources repository implementation file MUST be named after the type it holds (`SourcesRepoImpl`).
- **FR-002**: The sources repository test file MUST be named after the type it tests (`SourcesRepoImplTests`).
- **FR-003**: The renames MUST be recorded as renames in version control, so each file's earlier history stays reachable.
- **FR-004**: The renames MUST NOT change any code, test, behaviour or test count.
- **FR-005**: The project guide MUST name the renamed files correctly and MUST drop its instruction to keep the misspelled names, while keeping the general rule to fix typos rather than propagate them.
- **FR-006**: Outside the historical specs and the LTA-17 ticket, no file in the repository MAY still mention the misspelled names.
- **FR-007**: The documentation catalogue's main page MUST replace its summary placeholder with a one-sentence description of the app.
- **FR-008**: The documentation catalogue's TODO list MUST show every shipped area (specs 001–009) as done, MUST list only general open questions that have no ticket (omitting that part when there are none), and MUST point to the ticket backlog for open feature work instead of copying its items.
- **FR-009**: The documentation catalogue's main page MUST have no spelling mistakes, and each scenario option that has shipped MUST name the spec that shipped it (or say "shipped before spec 001" for work that predates the specs); the scenario text is otherwise not rewritten.
- **FR-010**: The historical spec documents (specs 001–009) MUST be left unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A search for the misspelled name across the repository, excluding `specs/` and the LTA-17 ticket, returns 0 matches.
- **SC-002**: The project builds, and the unit tests pass with the same count as before the change (0 tests added, 0 removed, 0 failing).
- **SC-003**: The documentation catalogue's main page contains 0 template placeholders and 0 spelling mistakes.
- **SC-004**: Every done item in the refreshed TODO list names its spec or ticket, every open item has no ticket in the backlog, and 0 backlog tickets are copied into the list.
- **SC-005**: The history of both renamed files reaches back past the rename.

## Assumptions

- The Xcode project finds its source files by folder, not by a per-file list, so renaming a file needs no project file edit (checked: the project uses file-system-synchronized groups).
- Historical specs keep the old names, because they record the state at the time of writing (the analysis's recommended default; no one asked to change them).
- The TODO list keeps its existing outline style (`++` done, `-+` partly done, `--` open), so that only its content changes.
- No code inside the renamed files mentions its own filename, so no file content has to change for the rename.
