# Implementation Plan: Fix Repo Filenames and Docs TODO

**Branch**: `010-fix-repo-filenames` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-fix-repo-filenames/spec.md`

## Summary

LTA-17 is maintenance work with no behaviour change. It has three parts:

1. **Rename two files.** `git mv` `lottoApp2/Data/Repos/SorcesRepoImp.swift` to `SourcesRepoImpl.swift` and
   `lottoApp2Tests/SorcesRepoImpTests.swift` to `SourcesRepoImplTests.swift`. Both targets are
   file-system-synchronized groups, so the Xcode project needs no edit (R1). No Swift file mentions either
   filename, so no file content changes (R2).
2. **Fix the project guide.** Correct the layout line in `CLAUDE.md` and drop its "keep the misspelled
   filenames" clause, keeping the rule against propagating typos.
3. **Refresh the DocC page.** `lottoApp2/Documentation.docc/Documentation.md` gets a real summary, fixed
   typos, the shipped S01 option marked with spec 009, and a TODO list rebuilt from specs 001–009 that
   points to `.tickets/` for open feature work (R3, R4).

The existing unit suite is the regression check. It must pass with an unchanged test count.

## Technical Context

**Language/Version**: Swift 6, Xcode 27 Beta toolchain. No Swift source is edited.

**Primary Dependencies**: None added or touched.

**Storage**: N/A.

**Testing**: The existing swift-testing suite (`lottoApp2Tests`), run before and after the rename to compare
counts. There are no new tests, because there is no new or changed behaviour (see Constitution Check).

**Target Platform**: iOS 18.6+.

**Project Type**: Mobile app, single target, layered into `Presentation` / `Domain` / `Data`.

**Performance Goals**: N/A.

**Constraints**: The renames must be recorded as renames (R1). Historical `specs/001…009` are not edited
(FR-010). The `Documentation.docc` catalogue is excluded from the app target's membership, so the app build
does not compile it. Its validity is checked with `xcrun docc convert` instead (R3).

**Scale/Scope**: 2 renamed files, 2 edited Markdown files (`CLAUDE.md`, `Documentation.md`), and the ticket
status.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Note |
|---|---|---|
| I. Layered Clean Architecture | Pass | The files stay in their layers (`Data/Repos`, tests). No imports change. |
| II. TCA for feature state | N/A | No reducer is touched. |
| III. Test-First | Pass | No reducer or Domain behaviour changes, so there is no new test to write first. The full existing suite, with an unchanged count, is the regression check (SC-002). |
| IV. Dependency Injection | N/A | No collaborator is touched. |
| V. Design tokens & previews | N/A | No view is touched. |
| Naming (Development Workflow) | Pass | This change removes an existing typo from filenames, as the rule asks. |

Post-design re-check: unchanged, and every gate passes. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/010-fix-repo-filenames/
├── plan.md              # This file
├── research.md          # Phase 0 (R1–R4)
├── quickstart.md        # Phase 1 validation guide
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

`data-model.md` and `contracts/` are not produced, because the feature adds no entity and changes no
interface.

### Source Code (repository root)

```text
lottoApp2/
  Data/Repos/
    SorcesRepoImp.swift  →  SourcesRepoImpl.swift        # git mv, content unchanged
  Documentation.docc/
    Documentation.md                                     # summary, typos, S01 marker, TODO list
lottoApp2Tests/
  SorcesRepoImpTests.swift  →  SourcesRepoImplTests.swift   # git mv, content unchanged
CLAUDE.md                                                # typo note + layout line
.tickets/17.yaml                                         # status only (ticket flow)
```

**Structure Decision**: The existing single-app layout is kept. Nothing moves between folders.

## Complexity Tracking

None.
