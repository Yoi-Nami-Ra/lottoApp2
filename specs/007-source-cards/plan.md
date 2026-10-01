# Implementation Plan: Compact and Wide Source Cards

**Branch**: `007-source-cards` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-source-cards/spec.md`

## Summary

The start page shows one large card per source at every width. This change (LTA-28 + LTA-29, parent LTA-5)
does five things:

1. **Approves the design.** The LTA-28 proposal is promoted to `design/final/source-cards.html` with the
   clarifications applied and a re-rendered snapshot. The tickets are updated (R10).
2. **Switches the variant by size class.** `StartPageView` reads `horizontalSizeClass`: compact width shows a
   `List` of a new `CompactSourceEntryView`, and regular width shows a `LazyVGrid` of today's `SourceEntryView`
   with adaptive columns of at least 320 pt whose cards fill their row's height (R1, R6).
3. **Adds the expand flag in TCA.** `SourceEntry.State.isExpanded` is toggled by
   `disclosureButtonTapped`, carried over on reload and never persisted (R2, R3).
4. **Shares the card parts.** The badge, skipped note, refresh styling, card style and their tokens move into
   `SourceCardParts.swift`, so both cards look the same. `SourceEntryView` keeps its behaviour (R4).
5. **Adds a wide Next bar.** At regular width `BottomActionBar` gives Next a fixed 320 pt width at the trailing
   edge (R7).

## Technical Context

**Language/Version**: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Xcode 27 Beta toolchain.

**Primary Dependencies**: `ComposableArchitecture`, SwiftUI. No new package.

**Storage**: None. `isExpanded` is screen state only.

**Testing**: swift-testing + TCA `TestStore` (`SourceEntryTests`, `StartPageTests`). Layout is checked through
`#Preview`s.

**Target Platform**: iOS 18.6+ (iPhone, iPad; Mac through the same size classes).

**Project Type**: Mobile app, single target, layered `Presentation` / `Domain` / `Data`.

**Performance Goals**: A handful of sources (1 today). `LazyVGrid` and `List` are both lazy, so there is no
measurable cost.

**Constraints**: No platform checks (LTA-5). The full card's layout and AX reflow stay unchanged. All
values are tokens. Reducers stay pure. The animation goes through `send(_:animation:)`, and Reduce Motion is
respected.

**Scale/Scope**: 7 production files, plus a preview fixture:
- new: `CompactSourceEntryView`, `SourceCardParts`;
- changed: `SourceEntry`, `StartPage`, `StartPageView`, `SourceEntryView`, and `BottomActionBar`;
- possibly `PreviewFixtures` (a fourth preview source).

2 test files: `SourceEntryTests` and `StartPageTests`. Plus design files and 2 ticket YAMLs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Pre | Post |
| --- | --- | --- | --- |
| I. Layered architecture | Presentation only. No Domain or Data type changes. The views consume the `SourceEntry` store as today. | ✅ | ✅ |
| II. TCA | The expand flag is reducer state with its own action (not view `@State`). The views stay thin: they send `cardTapped` / `refreshButtonTapped` / `disclosureButtonTapped`. Size class and Dynamic Type are environment-driven *layout* choices, the same as the existing `dynamicTypeSize` reflow. They are not feature logic. | ✅ | ✅ |
| III. Test-first | Failing `TestStore` tests come first: the toggle, the initial state, `apply` keeping the flag, reload carry-over, refresh keeping it, and selection staying the same. Existing suites prove the behaviour is the same from both variants. | ✅ | ✅ |
| IV. DI | No new dependency. | ✅ | ✅ |
| V. Tokens & previews | New tokens cover the dot size, row height and padding, the grid's minimum column and spacing, the Next width, chevron images, copy ("Show details", "Hide details", "Refresh", "Refreshing") and the animation. Shared tokens move to `SourceCardParts.swift` under `// MARK: - Resources`. Light and dark previews cover compact collapsed, expanded, selected, refreshing, never synced, skipped note and AX5, plus the regular-width grid. | ✅ | ✅ |

There are no violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/007-source-cards/
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
design/
  final/source-cards.html, source-cards.png    # promoted from proposal/28-source-cards.* (deleted)
.tickets/28.yaml, 29.yaml                        # designs, status, blocked_by
lottoApp2/Presentation/StartPage/
  StartPage.swift                                # .sourcesResponse carries isExpanded over
  StartPageView.swift                            # size-class switch; compact List / regular LazyVGrid; previews
  Widgets/
    SourceEntry.swift                            # State.isExpanded; Action.disclosureButtonTapped
    SourceCardParts.swift                        # new: SourceCardStyle, SyncStatusBadge, SkippedRecordsNote,
                                                 #      RefreshButtonStyle, shared tokens
    SourceEntryView.swift                        # uses the shared parts; layout/previews unchanged
    CompactSourceEntryView.swift                 # new: compact row + inline details, tokens, previews
    BottomActionBar.swift                        # fixed-width trailing Next at regular width; previews
lottoApp2Tests/Reducers/
  SourceEntryTests.swift                         # toggle, initial state, apply keeps flag
  StartPageTests.swift                           # several expanded, reload carry-over, refresh keeps, selection
```

**Structure Decision**: Use the existing single-target layout. The two new files sit in
`Presentation/StartPage/Widgets/` next to the card they complement.

## Complexity Tracking

No entries.
