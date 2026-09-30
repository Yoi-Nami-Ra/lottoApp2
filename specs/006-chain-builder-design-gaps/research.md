# Research: Chain-Builder Design Gaps

## R1 — Where the draw size comes from

- **Decision**: In `ChainEditor.onAppear`, call `blSources.gameFor(source.id)` alongside the existing reads.
  Success sends `snapshot.game.type.combinationType.pick` as `drawSize` in `.loaded`; failure sends `nil`.
  `gameLoaded(.success)` also sets `state.drawSize`, so a run refreshes it (spec clarification Q1).
- **Rationale**: `gameFor` is the Domain contract that already reads a source's stored draws. It fails when
  the source has no stored draws, which is exactly the design's "never synced → unknown". There is no new
  closure and no Data import.
- **Alternatives**: A new `gameTypeFor` closure backed by `SourceRegistry` would always know the draw size,
  which contradicts the approved "unknown when never synced" rule and adds a seam. Learning the size only
  from a run was rejected by clarification Q1, because the bound would be missing on first open.

## R2 — Parent size

- **Decision**: `ChainEditor.State.parentSize(of parentID: ChainNode.ID?) -> ParentSize?`:
  - `nil` (the source) → `sourceRecordsCount` as `.draws`;
  - a node whose `results[id]` is `.value(.draws(game), _)` → `game.entries.count` as `.draws`;
  - `.value(.counts(result), _)` → `result.counts.count` as `.items`;
  - `.number`, not run, running or failed → `nil`.

  The value is used whether the result is fresh or out of date (spec assumption).
- **Rationale**: It reuses the results the editor already holds, and the design says "when a previous run
  knows the parent's size".

## R3 — Where hint and bound logic lives

- **Decision**: `BlockParameters.State` holds `context: Context` (`parentSize`, `drawSize`). Computed
  properties give `hint: Hint?`, `directionPreview: DirectionPreview?`, `maximum: UInt?`, `invalidReason:
  InvalidReason?` and `canIncrement`. `incrementTapped` clamps at `maximum`.
- **Rationale**: Principle II keeps branching in reducers, and the rules become testable through `TestStore`
  state assertions. The view maps each enum case to a token.
- **Alternatives**: Computing the strings in the view would keep the logic out of tests.

## R4 — Hint precedence and wording

- **Decision**: In edit mode `Hint.was(original)` wins, and in add mode it is `Hint.parentSize` when known.
  Only the `.count` parameter (x) shows the parent size. `.was` applies to x, z and direction.
- **Rationale**: This matches the edit frame (only "Was 100…"). Clarified in spec FR-003.

## R5 — Rename as reducer state

- **Decision**: `BlocksPage.State.renaming: Chain.ID?` and `renameDraft: String`. The actions are
  `renameTapped(Chain.ID)` (sets both, the draft being the current name), `renameDraftChanged(String)`,
  `renameConfirmed` (the old trimmed/blank/unchanged rules, then save), and `renameCancelled`.
  `renameChain(id, name)` is removed; tests move to the new flow.
- **Rationale**: TCA's `AlertState` has no text fields, so the alert stays a SwiftUI `.alert` bound to
  store state. The ticket requires rename from the swipe to be covered by `TestStore`. One action serves the
  swipe, the menu and the accessibility action.
- **Alternatives**: Keeping `@State` in the view (today's approach) can't be tested.

## R6 — Empty-state gate

- **Decision**: `hasLoaded` is set on `.chainsLoaded`, and `showsEmptyState = hasLoaded && chains.isEmpty`.
- **Rationale**: This avoids a flash of "No chains yet" before existing chains load (spec edge case).

## R7 — Accessibility readings

- **Decision**: Rows use `.accessibilityElement(children: .ignore)` plus an `.accessibilityLabel` composed
  from token functions in `BlockTokens` (`rowReading`). Chain rows add `.accessibilityAction(named:)` for
  Rename and Delete. Disabled catalogue rows get a label "<block>, unavailable, <reason>". The number
  control gets `.accessibilityAdjustableAction`, which sends `incrementTapped`/`decrementTapped` (the reducer
  already honours the bounds). The "+" label is "Add block under <title>" or "<source name>".
- **Rationale**: These are native SwiftUI modifiers, and the copy stays in tokens.

## R8 — Accessibility-size layout

- **Decision**: Read `@Environment(\.dynamicTypeSize)`. When `isAccessibilitySize` is true, use
  `AnyLayout(VStackLayout)` instead of `HStackLayout` for the editor row's title/status and for the
  parameter field/stepper, and use the `indentPerLevelAccessible = 12` token instead of `indentPerLevel = 22`.
- **Rationale**: `AnyLayout` keeps view identity while switching axes. The threshold is the system's own
  accessibility-size boundary.
