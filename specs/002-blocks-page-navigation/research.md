# Phase 0 Research: Source Selection, Bottom Action Bar & Processing Blocks Page

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-08-16

The spec entered planning with no `[NEEDS CLARIFICATION]` markers — two `/speckit-clarify` sessions
resolved eight questions into requirements. What remained were *design* decisions, not requirement gaps.
Each is recorded below as Decision / Rationale / Alternatives considered.

---

## R1 — Navigation mechanism: tree-based `@Presents`, not a `StackState` path

**Decision**: `StartPage.State` gains `@Presents var blocks: BlocksPage.State?` and
`Action.blocks(PresentationAction<BlocksPage.Action>)`. `StartPageView` wraps its content in a single
`NavigationStack` and pushes with `.navigationDestination(item: $store.scope(state: \.blocks, action: \.blocks))`.
The app entry point and root store are unchanged.

**Rationale**:

- FR-023 ("activating **Next** more than once in quick succession MUST result in exactly one forward move")
  becomes structural instead of guarded: assigning `state.blocks` twice replaces the same optional, so a
  double tap still yields one destination. A `StackState` path would append twice and need an explicit
  `guard state.path.isEmpty` — a rule that must then be tested and can be forgotten by the next step's author.
- The destination is statically known and singular, which is exactly the case TCA's Tree-Based Navigation
  article addresses.
- No root-level `AppFeature` is needed, so `lottoApp2App.swift` and the existing `StartPage` root store stay
  untouched, keeping the diff inside the feature.

**Alternatives considered**:

- **`StackState<Path.State>` on a new root `AppFeature`** — the idiomatic shape once the flow is a
  multi-step pipeline (source → blocks → parameters → results, per the target domain model in CLAUDE.md).
  Rejected *for now* as scope beyond this feature: it adds a reducer, a view, an app-entry change and its
  own tests to deliver one push. Migration cost later is low and mechanical — each `@Presents` destination
  becomes a `Path` case — and this is the point at which to revisit it, not before.
- **`.sheet` / modal presentation** — contradicts FR-028, which requires the platform's standard back
  gesture and control.

---

## R2 — Selection lives on the parent, mirrored to children by one helper

**Decision**: `StartPage.State.selectedSourceID: SourceEntry.State.ID?` is the single source of truth.
`SourceEntry.State` carries a derived `var isSelected: Bool = false` purely so the card can render itself.
Exactly one private helper on `StartPage.State` — `applySelectionRules()` — recomputes both after any change
to `sources` or `selectedSourceID`, and every code path that touches either calls it.

**Rationale**:

- FR-007 (at most one source chosen) is an invariant across the whole list; expressing it as one optional id
  on the parent makes it impossible to represent two selections, whereas N independent `isSelected` flags
  make the illegal state representable and rely on discipline to avoid it.
- FR-020 (**Next** availability) is a parent-level question and reads directly off `selectedSourceID`.
- The child still needs to know it is selected in order to draw the border and checkmark. Mirroring one
  `Bool` avoids the alternative of the view computing `store.selectedSourceID == entry.id` inline, which
  would put a comparison in the view body against Principle II.
- Funnelling every mutation through one helper is what keeps the mirror honest — FR-008 to FR-010, FR-016 and
  FR-019 are all expressed inside it, in one place, and tested there.

**Alternatives considered**:

- **`isSelected` on children only, with `selectedSourceID` as a computed property** — reads well, but every
  selection change must still clear the other flags, so the invariant enforcement does not actually
  disappear; it just loses its obvious home.
- **View-side derivation (`isSelected:` passed as a view parameter)** — smallest state, but moves a decision
  into the view body and makes the selected state invisible to `TestStore` assertions.

---

## R3 — Loading is a one-shot flag, not a state machine

**Decision**: `StartPage.State.hasLoaded: Bool = false`, set to `true` when the first `sourcesResponse`
arrives and never reset. The view renders: `!hasLoaded` → loading indication; `hasLoaded && sources.isEmpty`
→ the no-sources message; otherwise the list.

**Rationale**:

- It expresses FR-006's exact wording — the loading indication belongs to the period "before the first
  result of a screen's life" — with one value.
- It satisfies FR-030's *second* clause for free. `StartPage.State` survives the push and pop (the reducer's
  state is not recreated), so `hasLoaded` is still `true` on return and the reload never swaps the populated
  list back to a spinner. FR-030's *first* clause — that returning actually starts the load — depends on
  whether the view's `.task` re-fires on pop, which is a platform behaviour to verify rather than assume
  (contract C4, task T035).
- Three view states from one `Bool` plus `sources.isEmpty` needs no extra enum, and both inputs are already
  `Equatable` reducer state, so all three are assertable in a `TestStore`.

**Alternatives considered**:

- **`enum LoadState { loading, loaded }`** — identical information, more ceremony; would earn its keep only
  once a `failed` case exists, and this load has no failure path today (`knownSources()` returns `[Source]`,
  not a `Result`).
- **`isLoading: Bool` toggled on every load** — would satisfy FR-006 but violate FR-030 by showing the
  loading indication again on the reload after returning.

---

## R4 — Whole-card tap via `.onTapGesture`, with the Refresh button left intact

**Decision**: `SourceEntryView` applies `.contentShape(Rectangle())` and `.onTapGesture { store.send(.cardTapped) }`
to the card content. The existing Refresh `Button` stays exactly as it is, nested inside.

**Rationale**:

- FR-012 requires that tapping Refresh never moves the choice. A `Button` nested inside another `Button` is
  the failure case here — the outer control swallows or ambiguates the inner one. A tap gesture on the
  container does not compete with a real `Button` inside it: the button consumes its own hits first.
- `.contentShape(Rectangle())` makes the whole card area (including the transparent gaps between the title,
  badge and detail rows) hittable, which is what "tapping anywhere on its card" in FR-011 means.
- Rows already opt out of `List` decoration (`.listRowBackground(.clear)`, `.listRowSeparator(.hidden)`), so
  no `List` selection machinery is involved and nothing needs to be undone.

**Alternatives considered**:

- **Wrapping the card in a `Button`** — rejected per above; also inherits button styling and focus behaviour
  the card design does not want.
- **`List(selection:)`** — the platform's own single-selection API, but it draws its own selection chrome,
  which fights the card design and the FR-015 "border **and** checkmark" requirement, and it only behaves as
  desired in edit mode on iOS.

---

## R5 — The block catalogue is a Domain enum, and deliberately *not* the pipeline type design

**Decision**: Add `Domain/Ents/ProcessingBlockKind.swift` — a `nonisolated enum ProcessingBlockKind: String, CaseIterable, Equatable, Sendable`
with the single case `countUniqueElements`. `BlocksPage` lists `ProcessingBlockKind.allCases`. The
human-readable label lives in `BlocksPageView` as a `LocalizedStringKey` token keyed by kind.

**Rationale**:

- The spec's Key Entities call for "a stable identity and a human-readable name", app-provided and not
  fetched. `CaseIterable` gives FR-026's "exactly one entry at this stage" a single place to change, and
  makes a future second block a one-line addition plus its label token.
- Keeping the label out of Domain honours both Principle I (no UI concerns inward) and Principle V (copy is a
  token in the view file). A `switch` over the kind for the label — rather than a dictionary with a fallback —
  means adding a case fails to compile instead of silently rendering wrong, matching the existing precedent
  in `SourceEntryView.syncSeverityForeground`.
- **This is a catalogue identity only.** CLAUDE.md marks the block pipeline's I/O types as TBD and explicitly
  says not to invent them. Nothing here defines what a block consumes or produces, how blocks compose, or how
  a chain executes — `ProcessingBlockKind` names one block, and the spec's Out of Scope section keeps
  execution out of this feature.

**Alternatives considered**:

- **A `ProcessingBlocksRepo` / BLogic seam** — the project's standard shape for a collaborator, but there is
  nothing to collaborate with: no I/O, no configuration, no remote content. Adding a `DependencyKey` for a
  static one-case enum is the unjustified complexity Governance tells reviewers to remove.
- **A `struct ProcessingBlock { let id: String; let name: String }` in Domain** — carries display copy into
  the inner layer, breaking Principle V's token rule.
- **Hard-coding the row directly in `BlocksPageView`** — no identity to test against and no place for the
  second block to go.

---

## R6 — Canonical naming: "Processing Blocks", reducer `BlocksPage`

**Decision**: The screen is called the **Processing Blocks page** in all prose; the reducer and view are
`BlocksPage` / `BlocksPageView` in `Presentation/BlocksPage/`; the visible title is the
`LocalizedStringKey` token `.blocksPageTitle` = "Processing Blocks".

**Rationale**: This was the one Outstanding item left by `/speckit-clarify` (the feature description said
"block selection page", the spec says "processing blocks page"). "Selection" now unambiguously refers to
choosing a *source*, so reusing it for the blocks screen would collide with the feature's own vocabulary.
The type name follows the existing `StartPage`/`StartPageView` pairing so the directory shape stays uniform.

**Alternatives considered**: `BlockSelectionPage` — rejected because nothing on the page is selectable at
this stage (Out of Scope), so the name would describe behaviour the screen does not have.

---

## R7 — Accessibility of the selected card and the disabled action

**Decision**: The card exposes itself as one accessibility element with `.isButton`, adds `.isSelected` when
chosen, and keeps the Refresh button as its own element. **Next** uses SwiftUI's `.disabled(...)`, which
carries the not-enabled trait to assistive technology for free. The empty-state message and the loading
indication are readable elements, and the loading indication is announced rather than silent.

**Rationale**: FR-032 and FR-033 require assistive technology to convey *which* source is chosen and
*whether* **Next** is available. `.isSelected` is the platform's own vocabulary for the former, so
VoiceOver says "selected" without bespoke copy; `.disabled` is the latter. FR-015's "never depends on colour
alone" is answered visually by the checkmark and non-visually by the trait.

**Alternatives considered**: A custom `accessibilityValue` of "selected"/"not selected" — duplicates a
standard trait in hand-written copy that then needs localizing.

---

## R8 — The single-source rule is continuous, not first-load-only

**Decision**: `applySelectionRules()` (R2) runs on every `sourcesResponse`, so FR-009 auto-selects the sole
source whenever the list *becomes* one source — not only on first load.

**Rationale**: The spec's Edge Cases require exactly this: "the list shrinks to a single source → that
remaining source becomes the chosen one automatically", alongside FR-016's rule that a chosen source which
disappeared ceases to be chosen. Both fall out of running one ruleset after every list change, rather than
special-casing the first response.

**Alternatives considered**: Applying the rule only on the initial load — simpler to write, but leaves a
list that shrinks to one source with nothing chosen and **Next** unavailable for no reason the person can see.

---

## Resolved unknowns

| Technical Context field | Status |
|-------------------------|--------|
| Language/Version, Target Platform, Project Type | Known from the existing project — no research needed |
| Primary Dependencies | Resolved: no new SPM dependency (R1 uses the already-present TCA/swift-navigation integration) |
| Storage | Resolved: N/A by requirement (FR-018) |
| Testing | Known: swift-testing + `TestStore`, matching `lottoApp2Tests/Reducers/` |
| Performance Goals / Constraints | Resolved: no new I/O; SC-006 is met by construction since the page renders fixed content |

No `NEEDS CLARIFICATION` remains.
