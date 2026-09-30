# Implementation Plan: Specific Sync Errors

**Branch**: `004-sync-error-details` | **Date**: 2026-09-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-sync-error-details/spec.md`

## Summary

Every failed sync is currently collapsed into `SourcesBLogic.Error.somethingWentWrong`, and every failed
run read the same way, so the source card can only say "check your connection". This change replaces
both generic errors with two Domain types:

- `SyncFailure`: offline, server unreachable, server error with its status, unreadable data, source
  unavailable, storage failure, unknown, plus a never-shown `cancelled`.
- `SourceReadFailure`: source unavailable, unreadable stored draws.

The Data layer classifies what `URLSession`, `NetworkClient`, the source module and the store throw. The
typed failure then passes unchanged through `SourcesRepo` and `SourcesBLogic` to `StartPage`/`SourceEntry`
and `ChainEditor`, which choose a matching alert message from design tokens. See
[research.md](./research.md) for the decisions and [contracts](./contracts/domain-contracts.md) for the
classification and copy tables.

## Technical Context

**Language/Version**: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (non-UI types `nonisolated`),
Xcode 27 Beta toolchain.

**Primary Dependencies**: `ComposableArchitecture`, `swift-dependencies`; system `Foundation` (`URLError`)
and `OSLog`. No new package.

**Storage**: No change. No persisted format is touched.

**Testing**: swift-testing + TCA `TestStore`; parameterised `@Test(arguments:)` for the classification and
per-kind reducer tests; repo integration tests with stubbed `networkClient` and temp/in-memory `localStore`.

**Target Platform**: iOS 18.6+ (the existing target settings).

**Project Type**: Mobile app, single target, layered `Presentation` / `Domain` / `Data`.

**Performance Goals**: None. Classification is a constant-time switch on the error path only.

**Constraints**: Reducers stay pure. Copy comes only from tokens. No raw error text reaches the UI
(FR-009). Previously stored data is untouched on every failure (FR-006).

**Scale/Scope**: 2 new Domain enums, 1 Data classification function, about 8 production files changed,
about 7 test files changed or added.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Pre | Post |
| --- | --- | --- | --- |
| I. Layered architecture | Failure types are Domain entities. Classification of `URLError`/`NetworkClient.Failure`/`RemoteSourceError` is in the Data layer (R2). Presentation sees only Domain types. | ✅ | ✅ |
| II. TCA | Message choice lives in `AlertState` factories built by the reducers. `.cancelled` handling is a reducer branch. Views are unchanged apart from previews. | ✅ | ✅ |
| III. Test-first | Every kind gets a failing test first: classification, repo, BLogic, reducers (R6). Existing tests that assert `.somethingWentWrong`/`.syncFailed` are rewritten before the types change. | ✅ | ✅ |
| IV. DI | No new dependency. Tests override `networkClient`, `localStore`, `sourcesRepo` and `blSources` as today. | ✅ | ✅ |
| V. Tokens & previews | All new copy is `LocalizedStringResource` tokens. The `SourceEntryView` "error alert" previews show a specific kind, and `ChainEditorView` gains read-failed alert previews, each in light and dark. | ✅ | ✅ |

No violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/004-sync-error-details/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/domain-contracts.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
lottoApp2/
  Domain/
    Ents/SourceFailures.swift            # NEW: SyncFailure, SourceReadFailure
    Repos/SourcesRepo.swift              # Error enum removed; typed Results
    BLogic/SourcesBLogic.swift           # Error enum removed; pass-through
  Data/
    Repos/SyncFailureClassification.swift  # NEW: SyncFailure(classifying:)
    Repos/SorcesRepoImp.swift            # step-wise mapping (contracts §2)
  Presentation/
    StartPage/StartPage.swift            # refreshResponse: kind → alert; cancelled → none
    StartPage/Widgets/SourceEntry.swift  # AlertState.syncFailed(_:sourceName:) + copy tokens
    StartPage/Widgets/SourceEntryView.swift  # previews use a specific kind
    ChainEditor/ChainEditor.swift        # gameLoaded: AlertState.readFailed(_:sourceName:)
    ChainEditor/ChainEditorView.swift    # read-failed alert previews, light + dark
    Previews/PreviewFixtures.swift       # previewMock failures use the new kinds
lottoApp2Tests/
  Data/SyncFailureClassificationTests.swift  # NEW
  SorcesRepoImpTests.swift               # exact kinds + new per-kind cases
  TestBSources.swift                     # pass-through per kind
  Reducers/SourceBLogicMocks.swift       # failureMock → specific kinds; failing(sync:read:)
  Reducers/StartPageTests.swift          # per-kind alert, cancelled
  Reducers/SourceEntryTests.swift        # distinct messages
  Reducers/ChainEditorTests.swift        # both read kinds
```

**Structure Decision**: This is the existing single-target layered layout. New files go in the layer that
owns them: Domain for the entities, Data for classification. The misspelled `SorcesRepoImp*.swift`
filenames are kept, since they're only referenced, not newly created.

## Complexity Tracking

None.
