# Phase 1 Contracts: Source Selection, Bottom Action Bar & Processing Blocks Page

**Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Data model**: [data-model.md](../data-model.md)

This app exposes no network API, CLI, or public library surface. Its contracts are the **seams between
features**: each reducer's `State`/`Action` surface, the child→parent delegate boundary, and the navigation
boundary. Those are what tests bind to, so they are specified here.

Signatures below are the contract. Bodies are deliberately omitted — they belong to implementation.

---

## C1 — `SourceEntry` (child): card tap is an intent, not a decision

```swift
@ObservableState
struct State: Equatable, Identifiable {
    // ... existing fields unchanged ...
    var isSelected: Bool = false      // NEW — mirror only; written by the parent
}

enum Action {
    case refreshButtonTapped          // existing
    case cardTapped                   // NEW
    case delegate(Delegate)
    case alert(PresentationAction<Alert>)

    @CasePathable
    enum Delegate: Equatable {
        case refreshRequested         // existing
        case selectionRequested       // NEW
    }
}
```

**Contract**

| Rule | Requirement |
|------|-------------|
| `.cardTapped` returns `.send(.delegate(.selectionRequested))` and mutates nothing | FR-011 |
| `.cardTapped` is **not** guarded by `isRefreshing` — a refreshing source is still choosable | FR-017, FR-019 |
| `SourceEntry` never writes `isSelected`; only the parent does | data-model I3 |
| `.refreshButtonTapped` keeps its existing behaviour and its `isRefreshing` guard, and emits no selection intent | FR-012 |

The child deciding nothing mirrors the existing refresh split — the parent owns the fetch, and now the
choice too, because the at-most-one invariant is a list-level fact (research R2).

---

## C2 — `StartPage` (parent): owns the choice, the load flag, and the push

```swift
@ObservableState
struct State: Equatable {
    var sources: IdentifiedArrayOf<SourceEntry.State> = []
    var selectedSourceID: SourceEntry.State.ID? = nil     // NEW
    var hasLoaded: Bool = false                           // NEW
    @Presents var blocks: BlocksPage.State?               // NEW

    var isNextEnabled: Bool { selectedSourceID != nil }   // NEW — derived
}

enum Action {
    case task                                             // existing
    case sourcesResponse([Source])                        // existing
    case refreshResponse(id: SourceEntry.State.ID, Result<Source, SourcesBLogic.Error>)  // existing
    case sources(IdentifiedActionOf<SourceEntry>)         // existing
    case nextButtonTapped                                 // NEW
    case blocks(PresentationAction<BlocksPage.Action>)    // NEW
}
```

**Contract**

| Rule | Requirement |
|------|-------------|
| `.sourcesResponse` sets `hasLoaded = true` (and never back to `false`) before applying selection rules | FR-006, FR-030, I7 |
| `.sourcesResponse` preserves the existing carry-over of `isRefreshing` and `alert` | regression — existing `StartPage_Tests.sourcesResponse_preservesInFlightRefreshAndAlert` |
| `.sources(.element(id:action:.delegate(.selectionRequested)))` sets `selectedSourceID = id`, then re-applies the rules | FR-011, FR-013, FR-014 |
| `.nextButtonTapped` with `selectedSourceID == nil` returns `.none` and mutates nothing | FR-021 |
| `.nextButtonTapped` with a chosen id sets `state.blocks` from that source's `id` + `name` | FR-022, FR-024 |
| `.refreshResponse` (success or failure) leaves `selectedSourceID` untouched | FR-017 |
| `applySelectionRules()` is private, is the only writer of `isSelected`, and runs after every change to `sources` or `selectedSourceID` | I2–I5 |
| No selection rule reads `recordsCount`, `lastSync`, or `lastSyncSeverity` | FR-019, I6 |

Body composition keeps the existing `.forEach(\.sources, action: \.sources) { SourceEntry() }` and adds
`.ifLet(\.$blocks, action: \.blocks) { BlocksPage() }`.

---

## C3 — `BlocksPage` (new): fixed content, no effects

```swift
@Reducer
struct BlocksPage {
    @ObservableState
    struct State: Equatable {
        let sourceID: String
        let sourceName: String
        var blocks: [ProcessingBlockKind] = ProcessingBlockKind.allCases
    }

    enum Action { }        // no user-driven actions at this stage

    var body: some Reducer<State, Action> { ... }
}
```

**Contract**

| Rule | Requirement |
|------|-------------|
| `State.blocks` equals `ProcessingBlockKind.allCases`, i.e. exactly `[.countUniqueElements]` | FR-025, FR-026 |
| The reducer returns `.none` for everything and runs **no** effects — no loading, no I/O | SC-006 |
| `sourceName` is set by the parent at push time and is never re-read or refreshed while presented | FR-024 |
| Nothing on this page is selectable, configurable, or runnable | spec, Out of Scope |

If `Action` being empty proves awkward for the `@Reducer` macro, the minimal escape is a single unused case;
it must not become a place to hang behaviour that Out of Scope excludes.

---

## C4 — Navigation boundary

| Rule | Requirement |
|------|-------------|
| `StartPageView` hosts exactly one `NavigationStack`; the destination is attached with `.navigationDestination(item: $store.scope(state: \.blocks, action: \.blocks))` | research R1 |
| Presenting is `state.blocks = BlocksPage.State(...)`; dismissal is the platform back affordance driving it to `nil` | FR-028 |
| A second `.nextButtonTapped` while presented replaces the same optional — one destination, never two | FR-023 |
| `StartPage.State` is not reset by presenting or dismissing, so `selectedSourceID` and `hasLoaded` survive the round trip | FR-029, FR-030 |
| The pop must re-run the load, and the populated list must stay on screen while it runs (because `hasLoaded` is already `true`). Whether the view's existing `.task` re-fires on pop is a **platform behaviour to verify empirically, not to assume** — if it does not, an explicit trigger is required (tasks T035) | FR-030 |

---

## C5 — Domain: `ProcessingBlockKind`

```swift
nonisolated enum ProcessingBlockKind: String, CaseIterable, Equatable, Sendable {
    case countUniqueElements
}
```

**Contract**

| Rule | Requirement |
|------|-------------|
| `allCases.count == 1` at this stage | FR-026 |
| No display copy, no `LocalizedStringKey`, no SwiftUI import in this file | Principle I, Principle V |
| Presentation maps kind → label with an exhaustive `switch`, so a new case fails to compile rather than rendering wrong | precedent: `SourceEntryView.syncSeverityForeground` |
| Defines no block input/output type, composition, or execution | CLAUDE.md — block pipeline types are TBD |

---

## C6 — Presentation tokens introduced (Principle V)

No literal may appear inline in a view body. This feature introduces at least:

| Token kind | Tokens |
|------------|--------|
| `LocalizedStringKey` | `.nextButton` ("Next"), `.noSourcesMessage`, `.loadingSources`, `.blocksPageTitle` ("Processing Blocks"), block label per `ProcessingBlockKind` ("Count Unique Elements") |
| `Color` | selected card border/tint, checkmark tint, bottom bar background, bottom bar separator |
| `CGFloat` | selected border width, bar vertical/horizontal padding, checkmark spacing |
| `ImageType` | `.selectedCheckmark` (SF Symbol) |

Every new or modified view ships `#Preview`s covering `.light` and `.dark` across the meaningful states:
loading, no sources, one source (auto-chosen), several sources with none chosen, several with one chosen.
