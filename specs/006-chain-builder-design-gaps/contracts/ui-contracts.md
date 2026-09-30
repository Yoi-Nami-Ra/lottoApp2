# UI Contracts: Chain-Builder Design Gaps

These contracts cover the reducer interfaces and the copy each view must render. The copy is exact: it comes
from design/final/, with the spec's clarifications applied.

## C1 — BlockParameters

```swift
BlockParameters.State(kind: ProcessingBlockKind, mode: Mode, context: Context = .unknown)
```

| State | Rendered |
| --- | --- |
| `hint == .parentSize(.init(count: n, unit: .draws))` | "Of <n> draws. A larger x keeps them all." ("Of 1 draw. …") |
| `hint == .parentSize(.init(count: n, unit: .items))` | "Of <n> items. A larger x keeps them all." ("Of 1 item. …") |
| `hint == .was(block)` with x/z value v | "Was <v>. Saving marks this block's results out of date." |
| `hint == .was(block)` with direction d | "Was Ascending." / "Was Descending." + " Saving marks this block's results out of date." |
| `directionPreview` | `.mostFrequent` "Most frequent first." · `.leastFrequent` "Least frequent first." · `.oldest` "Oldest first." · `.newest` "Newest first." · `.lowestIndex` "Lowest index first." · `.highestIndex` "Highest index first." |
| `invalidReason == .atLeast(0)` | "Enter a whole number, 0 or more." |
| `invalidReason == .atLeast(2)` | "Enter a whole number, 2 or more." |
| `invalidReason == .range(2, m)` | "Enter a whole number from 2 to <m>." |
| `invalidReason == .drawsTooSmall` | "This source's draws are too small for sub-combinations." |

The number is grouped (`7,012`). An invalid reason replaces the hint in the footer. `incrementTapped` never
moves past `maximum`, and the "+" is disabled when `!canIncrement`.

## C2 — AddBlock

- `AddBlock.State(parentID:parent:parentOutput:context:)`, where `context` defaults to `.unknown`.
- `kindTapped(kind)` → `parameters = BlockParameters.State(kind:, mode: .add, context: state.context)`.
- A disabled row's accessibility label is "<block title>, unavailable, <reason text>".

## C3 — ChainEditor

- `.loaded(savedResults:draft:dataStates:drawSize:)`: `onAppear` reads `blSources.gameFor(source.id)` and
  sends `pick` on success, `nil` on failure.
- `gameLoaded(.success(snapshot))` sets `drawSize = snapshot.game.type.combinationType.pick`.
- `addTapped(parent:)` passes `context(under: parent)`.
- `startEditing(nodeID)` passes `context(under: node.parentID)`.
- Row reading: "<title>[, <parameters>][, <N> hidden], level <depth>, <state>[, Saved]". The state is one of
  "Not run", "Running", the failure text, "<summary>", or "<summary>, Out of date".
- Source row reading: "<source name>, source[, <N> draws]".
- "+" label: "Add block under <block title>" / "Add block under <source name>".
- At AX sizes the status sits under the title and each level indents 12 pt (22 pt otherwise).

## C4 — BlocksPage

| Action | Effect on state | Effect |
| --- | --- | --- |
| `chainsLoaded(chains)` | `chains = chains`, `hasLoaded = true` | — |
| `renameTapped(id)` | `renaming = id`, `renameDraft = chain.name` (ignored for an unknown id) | — |
| `renameDraftChanged(s)` | `renameDraft = s` | — |
| `renameConfirmed` | `renaming = nil`, `renameDraft = ""`; when the trimmed draft is valid and changed, the chain is renamed | `chainsRepo.saveChain` |
| `renameCancelled` | `renaming = nil`, `renameDraft = ""` | — |

View:

- The empty state (`showsEmptyState`) shows the ƒ icon (textTertiary), "No chains yet" (headline,
  textSecondary) and "A chain is a set of blocks that counts and sorts a source's draws. Tap New chain to
  build your first one." (footnote, textSecondary), above New chain.
- A leading swipe shows "Rename" with a pencil, tinted primaryBlue. The trailing swipe stays Delete.
- The context menu offers Rename, then Delete (destructive).
- Each row reads "<name>, <N> blocks" ("1 block") and offers the accessibility actions "Rename" and "Delete".
