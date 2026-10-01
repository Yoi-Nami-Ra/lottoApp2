# Research: Fix Repo Filenames and Docs TODO

## R1 — Does the Xcode project list the files individually?

- **Decision**: No project file edit. Rename with `git mv` only.
- **Rationale**: `lottoApp2.xcodeproj/project.pbxproj` declares `lottoApp2` and `lottoApp2Tests` as
  `PBXFileSystemSynchronizedRootGroup`s. Xcode picks up whatever is in those folders, and neither file appears
  in the project's exception set. `git mv` keeps the rename detectable, because the content is 100% similar
  (FR-003, SC-005).
- **Alternatives considered**: Renaming in Xcode. That gives the same result on disk, but it isn't scriptable
  and might also rewrite the project file for no reason.

## R2 — Does any content reference the old names?

- **Decision**: Only `CLAUDE.md` (lines 19 and 113) and the historical specs mention them. No Swift file does. *(Corrected during implementation: both files' header comments and the suite type `SorcesRepoImp_Tests` also did. See the tasks.md Notes.)*
- **Rationale**: `grep -rn Sorces` over `*.swift`, `*.pbxproj`, `*.md` and `*.yaml` outside `specs/` matched
  only `CLAUDE.md` and `.tickets/17.yaml`. The ticket's text describes its own task and stays (spec Edge
  Cases). Test names such as `SourcesRepoImplTests` are not derived from the filename, because swift-testing
  suites are named by their type.
- **Alternatives considered**: Also rewriting the historical specs. Rejected by FR-010: they record the state
  at the time of writing.

## R3 — How is the DocC page checked, given the app build doesn't compile it?

- **Decision**: Run `xcrun docc convert lottoApp2/Documentation.docc` into a scratch output directory and
  require no warnings. Also check that the page has no `@START_MENU_TOKEN@` placeholder.
- **Rationale**: `Documentation.docc` is in the target's `membershipExceptions`, so `xcodebuild build` never
  processes it. A standalone convert is the cheapest check that the Markdown still parses as a DocC page
  (US2-AS4).
- **Alternatives considered**: A `docbuild` of the scheme. It wouldn't include the excluded catalogue.

## R4 — What goes in the refreshed TODO list?

- **Decision**: Keep the outline style (`++` done, `-+` partly done, `--` open). The list has three parts:
  - **Shipped**: one line per spec, 001–009, each naming its spec and what shipped.
  - **Open questions without a ticket**: none remain. The question "do we want UI auto tests?" was settled: the
    `lottoApp2UITests` target has an XCUITest happy path, added with LTA-23 (done), so it becomes a shipped line.
    Linting and view snapshot tests already have the idea ticket "Add linting and view snapshot tests", so
    they move out of the list. The open-questions part is omitted rather than left empty.
  - **A pointer**: "Open feature work is tracked in `.tickets/` (LTA-N)".
- **Rationale**: This follows the clarification (Session 2026-10-01). Copying the backlog would drift exactly
  as the old list did. Every done line names a spec, which makes SC-004 checkable.
- **Alternatives considered**: Deleting the TODO list outright. Rejected: the ticket asks for it to be
  refreshed, and the shipped summary is a useful overview for a reader of the docs.
