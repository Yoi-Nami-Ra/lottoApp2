# Data Model: Chain-Builder Design Gaps

Presentation state only. No Domain entity or persisted format changes.

## BlockParameters.Context

| Field | Type | Meaning |
| --- | --- | --- |
| `parentSize` | `ParentSize?` | The parent's last known size, or `nil` when unknown (R2). |
| `drawSize` | `Int?` | The number of elements per draw of the chosen source, or `nil` when unknown (R1). |

`ParentSize { count: Int; unit: Unit }` where `Unit` is `.draws` or `.items`.

`Context.unknown` sets both fields to `nil`, and it is the default so existing call sites and previews keep
working.

## BlockParameters.State additions

| Member | Kind | Rule |
| --- | --- | --- |
| `context` | stored | Set at creation by `AddBlock` or `ChainEditor`. |
| `hint: Hint?` | computed | `.was(original)` in edit mode when `parameter != .none`. Otherwise `.parentSize(p)` when `parameter == .count` and the parent size is known. Otherwise `nil`. |
| `directionPreview: DirectionPreview?` | computed | For sort kinds, the pair (kind, direction) → `.mostFrequent`/`.leastFrequent`, `.oldest`/`.newest`, or `.lowestIndex`/`.highestIndex`. `nil` otherwise. |
| `maximum: UInt?` | computed | For `.size` with a known draw size, `drawSize − 1` (it may fall below `minimum`). `nil` otherwise. |
| `count: UInt?` | computed (changed) | Valid only when `minimum ≤ value ≤ maximum` (when `maximum` exists). |
| `invalidReason: InvalidReason?` | computed | `nil` when valid. `.drawsTooSmall` when a size's `drawSize ≤ 2`. `.range(2, max)` when a size has a known draw size. Otherwise `.atLeast(minimum)`. |
| `canIncrement: Bool` | computed | `false` when `count == maximum` or `maximum < minimum`. |

Enums: `Hint { parentSize(ParentSize), was(Block) }`, `InvalidReason { atLeast(UInt), range(UInt, UInt),
drawsTooSmall }`, and `DirectionPreview { mostFrequent, leastFrequent, oldest, newest, lowestIndex,
highestIndex }`.

## AddBlock.State

`AddBlock.State` gains `context: BlockParameters.Context`, passed through to `BlockParameters.State(kind:mode:context:)`
on `kindTapped`.

## ChainEditor.State additions

| Member | Kind | Rule |
| --- | --- | --- |
| `drawSize` | stored `Int?` | Set by `.loaded(…, drawSize:)` and by `gameLoaded(.success)`. |
| `parentSize(of:)` | func | See R2. |
| `context(under:)` | func | `Context(parentSize: parentSize(of:), drawSize: drawSize)`. Used by `addTapped` (the parent) and `startEditing` (the node's parent). |

The action change is `.loaded(savedResults:draft:dataStates:drawSize:)`.

## BlocksPage.State additions

| Member | Kind | Rule |
| --- | --- | --- |
| `hasLoaded` | stored `Bool` | `false` until the first `.chainsLoaded`. |
| `renaming` | stored `Chain.ID?` | Non-nil while the rename alert shows. |
| `renameDraft` | stored `String` | The typed name, starting at the chain's current name. |
| `showsEmptyState` | computed | `hasLoaded && chains.isEmpty`. |

The action changes are `renameTapped(Chain.ID)`, `renameDraftChanged(String)`, `renameConfirmed` and
`renameCancelled`. `renameChain(Chain.ID, String)` is removed.

State transitions for rename:
`idle → renameTapped(id) → editing(id, name) → renameDraftChanged* → renameConfirmed | renameCancelled → idle`.
`renameConfirmed` saves only when the trimmed draft is non-empty, differs from the current name, and the chain
still exists.
