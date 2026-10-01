# Research: Compact and Wide Source Cards

No `NEEDS CLARIFICATION` items were left in the Technical Context. Each decision below was checked against the
code on `main` (`b6f7c28`).

## R1 — How the page picks the variant

- **Decision**: `StartPageView` reads `@Environment(\.horizontalSizeClass)`. `.compact` renders the compact
  card list, and anything else (`.regular`, or `nil`) renders the full-card grid. The value never reaches the
  reducer.
- **Rationale**: Size class is a property of where the view is drawn, not of feature state. `SourceEntryView`
  already reads `dynamicTypeSize` the same way to choose its reflow. Reading the environment means iPad split
  view, rotation and Mac window resizing switch the layout with no extra code (LTA-5). Because the reducer's
  state is the same in both variants, a switch keeps selection, an in-flight sync and every `isExpanded`
  (FR-010, US3-AS5).
- **Alternatives considered**:
  - *Mirror the size class into `StartPage.State`*: this adds an action that only echoes the environment, and
    it makes tests assert layout. Rejected.
  - *`#if os(macOS)` or idiom checks*: LTA-5 forbids platform checks. Rejected.
  - *`ViewThatFits` on width*: it decides by content fit, not size class, so an iPad in slide-over would
    show the wrong variant. Rejected.

## R2 — Where the expanded state lives

- **Decision**: Add `SourceEntry.State.isExpanded: Bool = false` and a new action
  `SourceEntry.Action.disclosureButtonTapped` that toggles it. The action has no effect and no delegate.
- **Rationale**: The ticket asks for TCA state, not view `@State` (Principle II). Keeping it per entry makes
  "several open at once" automatic. The field is not in `Source` and is never written to disk, so it cannot
  persist (FR-010). The parent never needs to know, so there is no delegate. That also keeps the toggle
  from touching selection or sync (US2-AS4).
- **Alternatives considered**:
  - *`StartPage.State.expandedIDs: Set<ID>`*: the parent would then have to prune ids on reload, and the
    child view would have to get its flag from the parent. Rejected.
  - *View `@State`*: it is lost on every width switch (the view tree changes) and can't be tested. Rejected
    by the ticket.

## R3 — Keeping `isExpanded` across reloads and syncs

- **Decision**: `StartPage`'s `.sourcesResponse` copies `isExpanded` from the existing entry, next to
  `isRefreshing` and `alert`, which it already copies. `SourceEntry.State.apply(_:now:)` leaves it alone.
- **Rationale**: Today a reload rebuilds every entry from `Source`, which would collapse every card when the
  user comes back from the blocks page (US2-AS8). `apply` already updates only the analytics fields, so a
  finished or failed sync keeps the flag without any change. A source removed by a reload takes its flag with
  it, and a new source starts at the `false` default (Edge Cases).

## R4 — Sharing the card parts between the two variants

- **Decision**: Move the parts both cards draw into a new `Widgets/SourceCardParts.swift` with no change in
  behaviour:
  - `SyncStatusBadge(lastSync:severity:)`, the severity-coloured "Last synced: …" / "Not synced" capsule;
  - `SkippedRecordsNote(count:)`, the spec 005 warning row;
  - `RefreshButtonStyle`, the spin, dim, border and background for both the labelled and icon-only buttons;
  - `SourceCardStyle`, which already exists and moves here unchanged;
  - shared tokens (the severity colour switch, refresh colours, light/dark tint opacities, and the copy for
    "Not synced", "N/A", "Last synced: …", the skipped wording, "First Record:" and "Latest Record:") as
    `internal` statics under `// MARK: - Resources`.

  `SourceEntryView` switches to these parts. Its layout, previews and accessibility do not change.
- **Rationale**: FR-005 and FR-008 require the compact card to look and behave exactly like the full card's
  badge, note and refresh button. Copying the tokens would let the two drift apart. `ChainEditor/BlockTokens.swift`
  sets the precedent for internal tokens that several views share.
- **Alternatives considered**:
  - *Copy the `fileprivate` tokens into the new view*: the two copies would drift, and the constitution asks
    for named tokens rather than duplicates. Rejected.
  - *Make the compact card a mode of `SourceEntryView`*: one view would hold two unrelated layouts and their
    reflow rules, and it is already 700+ lines. Rejected.

## R5 — The compact card view

- **Decision**: A new `Widgets/CompactSourceEntryView.swift` driven by the same `StoreOf<SourceEntry>`. It has:
  - **Row** `HStack`: the dot (12 pt circle in the severity colour, `accessibilityHidden`); the name, a `Text`
    with a `.compactName` font token (`.headline`) and
    `fixedSize(horizontal: false, vertical: true)` so it wraps; the checkmark when selected; inline
    "Not synced" in `.caption` / `textSecondary` when `lastSync == nil`; the icon-only refresh `Button`
    (`RefreshButtonStyle`, `.fixedSize()`); and the chevron `Button` (`chevron.down`/`chevron.up`,
    `.fixedSize()`). Minimum height 52 pt.
  - **Details** (when `isExpanded`): a divider; then a two-column `Grid` with Records | Last sync
    (`SyncStatusBadge`); then `SkippedRecordsNote` spanning both columns when present (clarification 2); then
    First record | Latest record. At accessibility sizes the details use an `AnyLayout` of a `VStackLayout`
    instead, the same pattern as `SourceEntryView.detailsLayout`.
  - **Whole card**: `SourceCardStyle(isSelected:)`, `.contentShape(Rectangle())` and
    `.onTapGesture { send(.cardTapped) }`. The gesture sits on the whole card, details included
    (clarification 1). The two `Button`s take their own taps, as Refresh does on the full card today.
- **Rationale**: This follows the proposal frame by frame and uses the full card's tap and accessibility
  pattern, which was already checked for nested-button conflicts (spec 001 FR-012).

## R6 — The regular-width grid and equal row heights

- **Decision**: At regular width, replace the `List` with
  `ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: .gridMinColumn), spacing: …)], spacing: …) }`
  with `gridMinColumn = 320`. Each `SourceEntryView` gets `.frame(maxHeight: .infinity, alignment: .top)` so it
  fills its row. The compact width keeps today's `List` with its row insets.
- **Rationale**: `LazyVGrid` sizes each row to its tallest cell. A cell with a flexible vertical frame
  then stretches to that height, which gives "cards in a row share its height" (FR-014). An adaptive
  `GridItem` gives the "as many ≥320 pt columns as fit" rule with no width maths. The full card's background
  is drawn by `SourceCardStyle`, so the flexible frame must sit *inside* the style (before its background)
  for the background to stretch: `SourceCardStyle` gains `.frame(maxHeight: .infinity, alignment: .top)` ahead
  of its padding and background. That is a no-op in
  the `List`, whose rows size to their content, and it fills the cell in the grid. This is verified in the
  regular-width preview (quickstart §2).
- **Alternatives considered**:
  - *`Grid` with manual `GridRow`s*: this needs the column count to be computed from a `GeometryReader`. Rejected.
  - *`List` at all widths*: a `List` can't lay out columns. Rejected.

## R7 — The Next bar on wide screens

- **Decision**: `BottomActionBar` reads `@Environment(\.horizontalSizeClass)`. At `.regular` the button gets
  a fixed `frame(width: .nextRegularWidth)` (320 pt) and the bar's content is aligned `.trailing`. At
  `.compact` the button stays full width as today.
- **Rationale**: This is FR-015. The bar owns no state and is a pure function of its inputs plus the
  environment, as in R1. 320 pt matches the grid's minimum column, so on a three-column iPad the button
  lines up with one card's width, as the proposal's tablet frame shows.

## R8 — Accessibility of the compact card

- **Decision**:
  - The card is `.accessibilityElement(children: .contain)`. Its label is `Text(name)`, followed by the status
    (`"Last synced: …"` or `"Not synced"`), so severity is read as text and the dot is hidden. Its traits are
    `.isButton` plus `.isSelected` when chosen. It keeps the "Choose this source" action, as on the full card.
  - Refresh: `.accessibilityLabel(isRefreshing ? "Refreshing" : "Refresh")`.
  - Chevron: `.accessibilityLabel(isExpanded ? "Hide details" : "Show details")`.
  - At accessibility sizes the row keeps its `HStack`, with the buttons `.fixedSize()` and the name wrapping.
    The details switch to one column (R5).
- **Rationale**: This covers FR-011 to FR-013 and US4. The full card's pattern (`.contain` + label + traits +
  action) has already been checked with VoiceOver, so the compact card reuses it rather than inventing one.
  The status wording reuses the full card's copy (spec Assumptions).

## R9 — Animating expand/collapse

- **Decision**: The chevron button calls `store.send(.disclosureButtonTapped, animation: .disclosure)`, with
  `disclosure = .snappy` as a token. When Reduce Motion is on, the view passes `nil`, so the change has
  no animation.
- **Rationale**: TCA's `send(_:animation:)` keeps the reducer pure and puts the animation on the
  transaction. Honouring Reduce Motion is cheap and expected.

## R10 — Promoting the LTA-28 design

- **Decision**: Copy `design/proposal/28-source-cards.html` to `design/final/source-cards.html` and edit it for
  the clarifications:
  - the skipped-records note row appears in the expanded frame, between the count/badge and the record dates;
  - the caption says the details area selects the card too;
  - the badge reads "Last synced: …";
  - the "proposal" wording is dropped.

  Re-render `design/final/source-cards.png` with the headless Chrome command in `design/README.md`. Delete both
  proposal files. In `.tickets/28.yaml` set `designs: [design/final/source-cards.html]` and `status: done`; in
  `.tickets/29.yaml` set `designs: [design/final/source-cards.html]` and `blocked_by: []`.
- **Rationale**: This is the lifecycle in `design/README.md` §Lifecycle and the precedent of `727ccce`
  (LTA-21/22/32 promoted to final). It is done first, so the build is checked against the approved file
  (FR-018).

## R11 — Testing strategy

- **Decision**:
  - `SourceEntryTests`: `disclosureButtonTapped` toggles `false → true → false`, with no received actions,
    which also proves it neither selects nor refreshes. `apply(_:now:)` keeps `isExpanded`. `sourceEntryState`
    starts collapsed.
  - `StartPageTests`: expanding two entries keeps both. A `.sourcesResponse` reload keeps the flag for
    survivors and starts new sources collapsed. A refresh success or failure keeps it. Expanding does not change
    `selectedSourceID`.
  - Both card variants send only the existing `cardTapped` / `refreshButtonTapped` actions plus the new toggle,
    so the existing selection and refresh suites already cover "behaves the same from both variants" (SC-003).
    The views are checked through previews (quickstart §2).
- **Rationale**: Principle III. Reducer behaviour is the only testable logic; the layout is declarative.
