# Implementation Plan: Chain-Builder Design Gaps

**Branch**: `006-chain-builder-design-gaps` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-chain-builder-design-gaps/spec.md`

## Summary

LTA-23 shipped the chain list, chain editor and add-block sheet before their designs were final. This change
closes the twelve gaps LTA-33 lists, entirely in the Presentation layer, and adds no Domain or Data code:

1. **Parameter context** (R1–R4). `BlockParameters.State` gains a `Context`: the parent's last known size
   and kind, plus the chosen source's draw size. From it and `mode`, the reducer state derives the hint (parent
   size, or "Was …" when editing), the direction preview, and the z bound and its message. `ChainEditor` builds
   the context from its results, the source's record count, and a new `drawSize` it reads when the editor
   opens (through the existing `blSources.gameFor`) and refreshes on every run.
2. **Rename as feature state** (R5). `BlocksPage.State` gains `renaming` and `renameDraft`. The swipe, the
   long-press item and the accessibility action all send `renameTapped(id)`, so rename from the swipe can be
   tested with `TestStore`. `hasLoaded` gates the new empty state.
3. **Views and accessibility** (R6–R8). The chain list gets the empty state, a leading Rename swipe, Delete in
   its menu, and a row reading with custom actions. The editor gets one reading per row, the "+" labelled with
   its block, and an AX-size layout (summary under the title, 12 pt indent). The sheet gets disabled-row
   readings, an adjustable stepper, and a stacked field and stepper at AX sizes. Every value comes from a
   token, and every new state has light and dark previews.

## Technical Context

**Language/Version**: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Xcode 27 Beta toolchain.

**Primary Dependencies**: `ComposableArchitecture`, `swift-dependencies`, SwiftUI. No new package.

**Storage**: None. Nothing new is persisted: the rename draft is transient, and the draw size is read again on
every open.

**Testing**: swift-testing + TCA `TestStore` (`AddBlockTests`, `BlocksPageTests`, `ChainEditorTests`). Mocks
come from `SourceBLogicMocks.swift` (`gameFor` → `ReferenceDraws.threeOfFive`, draw size 3) and
`PipelineMocks.swift`.

**Target Platform**: iOS 18.6+ (the existing target; the Mac destination builds the same views).

**Project Type**: Mobile app, single target, layered `Presentation` / `Domain` / `Data`.

**Performance Goals**: Opening the editor adds one stored-draws read (about 7,000 draws, the same read a run
does) off the main actor inside the existing `onAppear` effect. The hints are O(1) computed properties.

**Constraints**: Reducers stay pure, and views only render state and send actions. All copy, colours, fonts,
spacings and point sizes are tokens. Out of scope: anything in the finals beyond LTA-33's list (FR-022).

**Scale/Scope**: 9 production files: `BlockParameters(.swift|View)`, `AddBlock(.swift|View)`,
`ChainEditor(.swift|View)`, `BlocksPage(.swift|View)`, and `BlockTokens`. 3 test files: `AddBlockTests`,
`ChainEditorTests`, `BlocksPageTests`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Pre | Post |
| --- | --- | --- | --- |
| I. Layered architecture | Only Presentation changes. The draw size comes from the Domain `SourcesBLogic.gameFor` contract (`Game.type.combinationType.pick`), and there is no Data import. | ✅ | ✅ |
| II. TCA | The hints, bound, messages, empty-state decision and rename flow are all reducer state or computed state. Views read them and send actions. The draw-size read is an `Effect` in `onAppear`. | ✅ | ✅ |
| III. Test-first | Failing `TestStore` tests come first: the context from the editor (parent size for draws, counts and source; original value), the z bound (valid, too large, unknown, draw size ≤ 2, increment cap), direction preview state, rename from the swipe, cancel, blank or unchanged name, and the empty-state gate. Existing `onAppear` tests are updated for the `drawSize` payload. | ✅ | ✅ |
| IV. DI | No new dependency. `ChainEditor` already holds `@Dependency(\.blSources)`, and tests override it as they do today. | ✅ | ✅ |
| V. Tokens & previews | The new copy (`LocalizedStringKey`/`LocalizedStringResource`), indents (12/22), icon names and colours are `fileprivate static` tokens under `// MARK: - Resources`, or shared ones in `BlockTokens`. Previews cover the empty list, the parent-size, edit and direction hints, and the z-bound message, each in light and dark. | ✅ | ✅ |

There are no violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/006-chain-builder-design-gaps/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/ui-contracts.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
lottoApp2/Presentation/
  ChainEditor/
    BlockParameters.swift      # Context, Hint, InvalidReason; z bound; canIncrement; directionPreview
    BlockParametersView.swift  # hint/preview/message rows, adjustable stepper, AX stacking, previews
    AddBlock.swift             # carries Context into BlockParameters.State
    AddBlockView.swift         # disabled-row reading
    ChainEditor.swift          # drawSize (onAppear + run), parentSize(of:), context(for:), loaded payload
    ChainEditorView.swift      # row reading, "+" label, AX layout + 12 pt indent
    BlockTokens.swift          # shared copy: hints, previews, messages, row reading parts
  BlocksPage/
    BlocksPage.swift           # hasLoaded, renaming/renameDraft + actions, showsEmptyState
    BlocksPageView.swift       # empty state, leading Rename swipe, Delete in menu, a11y actions, previews
lottoApp2Tests/Reducers/
  AddBlockTests.swift          # BlockParameters hints, preview, z bound
  ChainEditorTests.swift       # context passed to add/edit, drawSize load + refresh
  BlocksPageTests.swift        # rename flow, empty-state gate
```

**Structure Decision**: This follows the existing Presentation layout, with each reducer next to its view.
There is no new file, because each gap belongs to a screen that already exists.

## Complexity Tracking

No violations.
