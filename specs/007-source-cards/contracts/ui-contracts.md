# UI Contracts: Compact and Wide Source Cards

These are the Presentation-layer contracts. No Domain or Data contract changes.

## §1 — Reducer: `SourceEntry`

```swift
@ObservableState struct State {
    // …existing fields…
    var isExpanded: Bool = false              // new
}

enum Action {
    case refreshButtonTapped                  // unchanged: guarded while refreshing → .delegate(.refreshRequested)
    case cardTapped                           // unchanged: → .delegate(.selectionRequested)
    case disclosureButtonTapped               // new: isExpanded.toggle(), no effect, no delegate
    case delegate(Delegate)
    case alert(PresentationAction<Alert>)
}
```

Invariants:

- `disclosureButtonTapped` changes only `isExpanded`. It never emits a delegate.
- `apply(_:now:)` never writes `isExpanded`.
- `Source.sourceEntryState(now:)` yields `isExpanded == false`.

## §2 — Reducer: `StartPage`

- `.sourcesResponse`: for each new entry whose id already existed, copy `isRefreshing`, `alert` **and
  `isExpanded`** from the old entry.
- Every other action is unchanged.

## §3 — View: `StartPageView` variant switch

| `horizontalSizeClass` | Content | Card view | Bottom bar |
| --- | --- | --- | --- |
| `.compact` | `List`, one column, today's row insets | `CompactSourceEntryView` | Next full width |
| `.regular` / `nil` | `ScrollView` + `LazyVGrid(.adaptive(minimum: 320))` | `SourceEntryView` (unchanged), filling its row height | Next fixed 320 pt, trailing |

The loading and empty states are the same at both widths.

## §4 — View: `CompactSourceEntryView(store: StoreOf<SourceEntry>)`

| Region | Content | Sends |
| --- | --- | --- |
| Row (min 52 pt) | severity dot · name [· checkmark if selected] [· "Not synced" if `lastSync == nil`] · refresh icon button · chevron button | — |
| Refresh button | icon only; spins and dims while `isRefreshing`; disabled while refreshing | `.refreshButtonTapped` |
| Chevron button | `chevron.down` collapsed / `chevron.up` expanded | `.disclosureButtonTapped` (animated unless Reduce Motion) |
| Details (when `isExpanded`) | Records · Last-sync badge / skipped note (full width, if any) / First record · Latest record; "N/A" when missing | — |
| Whole card except the two buttons | tap target | `.cardTapped` |

Accessibility:

| Element | Label | Traits / actions |
| --- | --- | --- |
| Card | `name`, then `"Last synced: <date>"` or `"Not synced"` | `.isButton` (+ `.isSelected`); action "Choose this source" |
| Severity dot | hidden | — |
| Refresh | "Refresh" / "Refreshing" | button |
| Chevron | "Show details" / "Hide details" | button |

At accessibility text sizes the name wraps, the two buttons keep their intrinsic size, and the details become one
column.

## §5 — Shared parts: `SourceCardParts.swift`

| Part | Used by | Notes |
| --- | --- | --- |
| `SourceCardStyle(isSelected:)` | both cards | moved from `SourceEntryView`; gains a flexible max-height frame so grid cells fill their row |
| `SyncStatusBadge(lastSync:severity:)` | both cards | the existing badge, unchanged look |
| `SkippedRecordsNote(count:)` | both cards | the existing spec 005 note, unchanged look and accessibility |
| `RefreshButtonStyle(isRefreshing:)` | both refresh buttons | colours, border, corners and the spin on the icon; the label text belongs to each caller |
| Shared tokens | both cards | `internal` statics: severity colours, refresh colours, tint opacities, shared copy |

## §6 — View: `BottomActionBar`

The inputs are unchanged. It reads `horizontalSizeClass`: at `.regular` the button is `frame(width: 320)` and
aligned to the trailing edge; otherwise it is full width.
