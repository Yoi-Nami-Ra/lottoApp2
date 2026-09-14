# Implementation Plan: Source Selection, Bottom Action Bar & Processing Blocks Page

**Branch**: `002-blocks-page-navigation` | **Date**: 2026-08-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-blocks-page-navigation/spec.md`

## Summary

Turn the start screen from a single-screen viewer into the first step of a flow. A bar pinned to the
bottom of the sources list carries one **Next** button; the source list gains single selection (auto-chosen
when exactly one source is known, picked by tapping a card when there are several, marked by a border plus
a checkmark); and **Next** pushes a new Processing Blocks page that names the chosen source in a header and
lists the one block the app offers today, "Count Unique Elements". The start screen also gains an explicit
loading state so the "no sources" message can never be shown before a result has arrived.

Technical approach: stay entirely inside the Presentation layer plus one small Domain addition. Selection is
parent-owned state on `StartPage` (`selectedSourceID`), mirrored onto each `SourceEntry.State.isSelected` by
a single private helper so the at-most-one invariant has exactly one enforcement point. The card tap
follows the existing child→parent pattern (`SourceEntry` sends a delegate; `StartPage` decides). Navigation
is tree-based TCA navigation — `@Presents var blocks` on `StartPage` plus one `NavigationStack` in
`StartPageView` and `.navigationDestination(item:)` — which makes FR-023's double-tap requirement
structural rather than guarded. The block catalogue is a new Domain enum `ProcessingBlockKind` with a single
case; its human-readable copy lives in the Presentation layer as `LocalizedStringKey` tokens, so no UI copy
enters Domain. **No new SPM dependency, no storage, no Data-layer change.**

## Technical Context

**Language/Version**: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (non-UI types declared
`nonisolated`), building against the Xcode 27 Beta toolchain.

**Primary Dependencies**: `ComposableArchitecture`, `swift-dependencies`, `swift-identified-collections`,
`swift-navigation` (already used for `AlertState`/`PresentationAction`; this feature additionally uses its
`navigationDestination(item:)` integration). **No new SPM dependency is introduced.**

**Storage**: N/A — FR-018 forbids persisting the chosen source; all new state is in-memory reducer state.

**Testing**: swift-testing (`import Testing`, `@Test`, `#expect`) + TCA `TestStore`, matching
`lottoApp2Tests/Reducers/`. Every new reducer behaviour is asserted through a `TestStore`.

**Target Platform**: iOS 18.6+, SwiftUI app via `lottoApp2.xcodeproj` (single scheme `lottoApp2`).

**Project Type**: Mobile app (single iOS target; layered `Presentation` / `Domain` / `Data`).

**Performance Goals**: Processing Blocks page fully presented within 1s of the tap with no loading indicator
(SC-006) — it renders fixed content and performs no I/O; list scrolling and selection stay at 60fps.

**Constraints**: No I/O of any kind is added — the only asynchronous work remains the existing
`blSources.knownSources()` load. Reducer tests must not touch network or disk (Principle III/IV), which is
free here because nothing new is injected. The loading indication is shown only before the *first* result of
a screen's life (FR-006), never on the reload that FR-030 requires after returning.

**Scale/Scope**: 1 new screen, 1 new reducer (`BlocksPage`), 1 new Domain enum, 2 modified reducers, 3
modified/new views, 1 new widget view. 3 known sources today; a block catalogue of exactly 1 entry.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment | Status |
|-----------|------------|--------|
| I. Layered Clean Architecture | Dependencies still point inward. The only Domain addition is `ProcessingBlockKind` (identity, `CaseIterable`) with **no** UI copy and no Data reference; Presentation maps kind → `LocalizedStringKey`. Nothing in Data changes; Presentation reaches no further than the existing `blSources` seam. | ✅ Pass |
| II. TCA for state & logic | `BlocksPage` is a new `@Reducer` with `@ObservableState`, an `Action` enum and one `body`. Selection, `Next` enablement, the loading flag and navigation all live in reducers; views render `store` and send actions. Navigation uses `@Presents` + `.navigationDestination(item:)`. All state stays `Equatable`. | ✅ Pass |
| III. Test-First (NON-NEGOTIABLE) | Red→Green per behaviour: auto-select-when-one, no-auto-select-when-many, card tap selects / re-tap keeps / different card moves, reload keeps-or-drops the choice, refresh never moves the choice, `Next` enablement, double-tap pushes once, loading→empty vs loading→list, and `BlocksPage` listing exactly one block. Tests are written and failing before each implementation step. | ✅ Pass |
| IV. DI via swift-dependencies | No new collaborator is needed, so no new `DependencyKey`. Existing `@Dependency(\.blSources)` / `@Dependency(\.date)` usage is unchanged; nothing is constructed directly in reducers or views. New value types are `Sendable`/`nonisolated` where they cross concurrency boundaries. | ✅ Pass |
| V. Declarative Views with Design Tokens | Every new visual value — bar background, selected border colour and width, checkmark image, empty-state and loading copy, "Next", "Processing Blocks", "Count Unique Elements" — is a named token in a `// MARK: - Resources` block. New/changed views ship `#Preview`s across light/dark × {loading, empty, one source, several sources, selected}. | ✅ Pass |

**Deviations**: None.

**Gate result**: PASS (no violations). Proceed to Phase 0.

**Post-Phase-1 re-check**: PASS. The design added no dependency, no layer crossing, and no view-side
branching beyond rendering; see [research.md](./research.md) decisions R1–R7 and
[data-model.md](./data-model.md) for the enforced invariants.

## Project Structure

### Documentation (this feature)

```text
specs/002-blocks-page-navigation/
├── plan.md              # This file
├── research.md          # Phase 0 output — resolved design decisions
├── data-model.md        # Phase 1 output — state shapes, invariants, transitions
├── quickstart.md        # Phase 1 output — how to run and validate the feature
├── contracts/
│   └── feature-contracts.md   # Phase 1 output — reducer State/Action surfaces, delegate + navigation contracts
├── checklists/
│   └── requirements.md  # Spec quality checklist (from /speckit-specify, re-validated by /speckit-clarify)
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lottoApp2/
├── App/
│   └── lottoApp2App.swift               # unchanged — root store stays StartPage
├── Presentation/
│   ├── StartPage/
│   │   ├── StartPage.swift              # MODIFIED — selectedSourceID, hasLoaded, @Presents blocks, selection rules
│   │   ├── StartPageView.swift          # MODIFIED — NavigationStack, navigationDestination, bottom bar, loading/empty states
│   │   └── Widgets/
│   │       ├── SourceEntry.swift        # MODIFIED — isSelected state, cardTapped action, selectionRequested delegate
│   │       ├── SourceEntryView.swift    # MODIFIED — selected border + checkmark, whole-card tap, a11y traits
│   │       ├── SourceTitle.swift        # unchanged
│   │       └── BottomActionBar.swift    # NEW — the pinned bar with the single Next button
│   ├── BlocksPage/
│   │   ├── BlocksPage.swift             # NEW — @Reducer for the processing blocks step
│   │   └── BlocksPageView.swift         # NEW — source header + block list
│   └── Previews/
│       └── PreviewFixtures.swift        # MODIFIED — fixtures for single-source / empty / selected previews
└── Domain/
    └── Ents/
        └── ProcessingBlockKind.swift    # NEW — catalogue identity only (no UI copy, no pipeline I/O types)

lottoApp2Tests/
└── Reducers/
    ├── StartPageTests.swift             # MODIFIED — selection, Next enablement, loading, navigation
    ├── SourceEntryTests.swift           # MODIFIED — cardTapped → delegate
    └── BlocksPageTests.swift            # NEW — catalogue contents, header source
```

**Structure Decision**: The existing three-layer tree is kept exactly as-is. All UI work lands under
`lottoApp2/Presentation/`, mirroring the `StartPage/` shape for the new `BlocksPage/` (reducer +
thin view, side by side). The single Domain addition sits in `Domain/Ents/` alongside `Source`. Nothing is
added to `Data/`. The Xcode project uses file-system synchronized groups
(`PBXFileSystemSynchronizedRootGroup`), so new files placed in these directories join their target
automatically — **no `project.pbxproj` edit is required**.

## Complexity Tracking

> No Constitution Check violations. This table is retained empty per the template's instruction.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| _(none)_ | — | — |
