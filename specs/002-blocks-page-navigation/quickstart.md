# Quickstart & Validation: Source Selection, Bottom Action Bar & Processing Blocks Page

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contracts**: [contracts/feature-contracts.md](./contracts/feature-contracts.md)

How to build, test, and prove this feature works. Requirement ids refer to [spec.md](./spec.md).

## Prerequisites

- Xcode 27 Beta toolchain (this repo builds against it), iOS 18.6 simulator.
- No new SPM dependency — `Package.resolved` should not change in this feature.
- Pick a simulator that exists on the machine:

```bash
xcrun simctl list devices available
```

## Build

```bash
xcodebuild build -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

New files under `lottoApp2/Presentation/BlocksPage/`, `lottoApp2/Domain/Ents/`, and
`lottoApp2Tests/Reducers/` join their targets automatically — the project uses file-system synchronized
groups, so **do not** edit `project.pbxproj`.

## Run the unit tests

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests
```

Single suite or single test (swift-testing suites are plain structs):

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests/StartPage_Tests
```

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests/BlocksPage_Tests
```

> Reducer tests that reach a dependency must override it — `swift-dependencies` fails an unimplemented
> dependency rather than silently returning a default. Existing tests override `\.blSources` and `\.date`;
> this feature adds no new dependency to override.

## Test-first order (Principle III)

Each row is one Red → Green cycle. Write the test, watch it fail, then implement the minimum.

| # | Test | Proves |
|---|------|--------|
| 1 | `SourceEntry`: `.cardTapped` emits `.delegate(.selectionRequested)` and mutates nothing | FR-011, C1 |
| 2 | `SourceEntry`: `.cardTapped` while `isRefreshing` still emits the delegate | FR-017, FR-019 |
| 3 | `StartPage`: `.sourcesResponse([one])` sets `hasLoaded`, chooses it, mirrors `isSelected` | FR-006, FR-009 |
| 4 | `StartPage`: `.sourcesResponse([many])` chooses nothing; `isNextEnabled == false` | FR-010, FR-020 |
| 5 | `StartPage`: `.sourcesResponse([])` sets `hasLoaded` with no choice — the empty state is reachable only after a result | FR-005, FR-006, FR-008 |
| 6 | `StartPage`: selection delegate for id X selects X; for Y moves it; for X again keeps it | FR-013, FR-014 |
| 7 | `StartPage`: reload keeps a still-present choice; drops a vanished one | FR-016, FR-029 |
| 8 | `StartPage`: reload shrinking many → one auto-chooses the survivor | FR-009, R8 |
| 9 | `StartPage`: a never-synced, zero-record source is choosable and auto-chosen when alone | FR-019, I6 |
| 10 | `StartPage`: refresh success **and** failure leave `selectedSourceID` untouched | FR-017, I8 |
| 11 | `StartPage`: `.nextButtonTapped` with no choice is a no-op; with a choice sets `blocks` with the right id and name | FR-020, FR-021, FR-022 |
| 12 | `StartPage`: two `.nextButtonTapped` in a row leave exactly one destination | FR-023 |
| 13 | `StartPage`: dismissing `blocks` leaves `selectedSourceID` and `hasLoaded` intact | FR-029, FR-030 |
| 14 | `StartPage`: five push → dismiss cycles end in the same state as a single push | SC-007 |
| 15 | `BlocksPage`: initial state lists exactly `[.countUniqueElements]` and carries the source name | FR-024, FR-025, FR-026 |

Existing regressions that must stay green (do not rewrite them to fit new state):
`sourcesResponse_preservesInFlightRefreshAndAlert`, `refreshResponse_forRemovedEntry_isIgnored`,
`sourcesResponse_derivesSyncSeverityFromInjectedClock`.

## Preview validation (Principle V)

Open the canvas for each view and confirm both `.light` and `.dark`:

| View | Preview states |
|------|----------------|
| `StartPageView` | loading; no sources; one source (auto-chosen); several with none chosen; several with one chosen |
| `SourceEntryView` | existing states, each additionally in a selected variant (border **and** checkmark) |
| `BottomActionBar` | **Next** enabled; **Next** disabled |
| `BlocksPageView` | short source name; long source name |

The checkmark must be present in the selected previews — a border/tint alone fails FR-015.

## Manual end-to-end validation

Run the app on the simulator:

```bash
xcodebuild build -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

| # | Steps | Expected | Requirement |
|---|-------|----------|-------------|
| 1 | Cold launch, watch the first frames | A loading indication — **never** the "no sources" message — then the list | FR-006, SC-009 |
| 2 | With several sources known, look at the bar | **Next** visibly disabled; no card highlighted | FR-010, FR-020, FR-021 |
| 3 | Tap a card's body | Border + checkmark appear on it; **Next** becomes enabled | FR-011, FR-015 |
| 4 | Tap another card | Highlight moves; only one card is ever highlighted | FR-014, I1 |
| 5 | Tap the highlighted card again | It stays chosen; **Next** stays enabled | FR-013 |
| 6 | Tap **Refresh** on a *different* card | That source refreshes; the highlight does **not** move | FR-012, FR-017 |
| 7 | Tap **Next** | Processing Blocks page pushes, header names the chosen source, list shows "Count Unique Elements" | FR-022, FR-024, FR-026 |
| 8 | Tap **Next** twice quickly (step 7 again) | Exactly one page is pushed — one back tap returns to the list | FR-023 |
| 9 | Swipe back | Sources list returns, same source still highlighted, list stays on screen (no spinner) while it reloads | FR-029, FR-030 |
| 10 | Repeat step 7 → step 9 **five times** | Same chosen source, one screen on the stack, list never reset | SC-007 |
| 11 | Scroll to the end of a long list | Last card can be brought fully into view above the bar | FR-004, SC-005 |
| 12 | Settings → Accessibility → larger text, relaunch | **Next**, the header and the message grow; nothing is clipped | SC-003 |
| 13 | VoiceOver on: swipe through a card, the bar, the empty state, and the blocks page | The card is one element announced as a button, "selected" when chosen; Refresh is its own element; **Next** announces as dimmed/unavailable when no source is chosen; the no-sources message, the loading indication, the blocks header and every block row are reachable and read out | FR-032, FR-033 |

### States that need a fixture to reach

The live registry currently yields a single real source, so some states are only reachable via previews or
by overriding `\.blSources` (as `PreviewFixtures.swift` already does with `Source.mocks`):

- **No sources**: `knownSources: { [] }`.
- **Several sources**: the existing `Source.mocks` (three entries).
- **Never-synced source**: the existing `Source.neverSyncedMock`.

## Definition of done

- [X] All 15 tests above written first, failing, then passing; existing suite still green.
- [X] Previews cover the state matrix in both colour schemes.
- [ ] Manual checks 1–13 pass on the simulator — **partial**: 1, 7, 8, 9, 11, 12 verified on iPhone 17 Pro.
      Checks 2–6 need several sources, which the live single-source registry cannot produce (reducer tests
      and previews cover them); check 10 is covered by test 14; check 13 (VoiceOver) is unverified.
- [X] `Package.resolved` unchanged; nothing added under `Data/`; no new `DependencyKey`.
      (`Package.resolved`, `project.pbxproj` and `Config/Info.plist` carry edits that pre-date this feature.)
- [X] No inline colour, font, spacing, image name, or copy literal in any view body.
