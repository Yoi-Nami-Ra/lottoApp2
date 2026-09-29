# Data Model: Processing Block Pipeline

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

All types below are `nonisolated`, `Sendable`, `Equatable`/`Hashable` and — where they are persisted —
`Codable`. Layer is noted per type. Requirement ids refer to the spec.

## Draws (Domain/Ents — LTA-6, LTA-7)

| Type | Fields | Invariants |
|---|---|---|
| `Element` | typealias of `UInt` | 1 … y of its `CombinationType` |
| `CombinationType` | `pick: Int` (x), `pool: Int` (y) | 1 ≤ x ≤ y |
| `Combination` | `type: CombinationType`, `elements: [Element]` | exactly x elements, strictly ascending (so no duplicates), each in 1…y. Equality/hash over the sorted array → order never matters (FR-001). `Comparable` element by element (FR-008 tie-break). |
| `SubCombination` | `parentType: CombinationType`, `elements: [Element]` | 2 ≤ z < x, strictly ascending, each in 1…y. Equality ignores the source draw. |
| `GameEntry` | `index: Int`, `date: Date`, `combination: Combination` | — |
| `GameType` | `id: String`, `name: String`, `combinationType: CombinationType` | declared by the source's `SourceModule` |
| `Game` | `type: GameType`, `entries: [GameEntry]` | every entry's combination type == `type.combinationType` (FR-002). A source's Game is ordered by index ascending (FR-013). |
| `DomainError` | `.invalidType`, `.wrongCount(expected:got:)`, `.duplicate(Element)`, `.outOfPool(Element)`, `.mixedShapes`, `.invalidSubCombinationSize(z)` | typed throws from every constructor |

## Pipeline values (Domain/Ents)

| Type | Shape | Notes |
|---|---|---|
| `ValueKind` | `.draws`, `.counts`, `.number` | FR-003 |
| `BlockValue` | `.draws(Game)`, `.counts(CountResult)`, `.number(Int)` | `kind` derives `ValueKind` |
| `CountItem` | `.element(Element)`, `.combination(Combination)`, `.subCombination(SubCombination)` | `Comparable` within a case (element ascending; arrays element by element) |
| `UniqueCount` | `item: CountItem`, `count: Int` | count ≥ 1 (FR-004) |
| `CountResult` | `counts: [UniqueCount]`, `ordering: .unordered \| .byCount(SortDirection)` | every item once; `.unordered` is stored item-ascending (FR-025) |
| `SortDirection` | `.ascending`, `.descending` | FR-009 |

## Blocks and chains (Domain/Ents + Domain/BLogic)

| Type | Shape | Notes |
|---|---|---|
| `Block` | `dropFirst(UInt)`, `dropLast(UInt)`, `prefix(UInt)`, `suffix(UInt)`, `sortByDate(SortDirection)`, `sortByIndex(SortDirection)`, `sortByCount(SortDirection)`, `countUniqueElements`, `countUniqueCombinations`, `countUniqueSubCombinations(z: Int)`, `countAllElements` | `accepts` and `output(given:)` encode the FR-010 table |
| `ProcessingBlockKind` | one case per `Block` case (existing `countUniqueElements` plus the rest) | catalogue identity; `defaultBlock`; UI copy stays in Presentation |
| `ChainNode` | `id: UUID`, `parentID: UUID?`, `block: Block` | `parentID == nil` → under the chain's input |
| `Chain` | `id: UUID`, `name: String`, `revision: Int`, `nodes: IdentifiedArrayOf<ChainNode>` | a tree: every `parentID` exists and no cycles; a node under `countAllElements` is impossible (FR-012); `revision` +1 on every structural or parameter edit |
| `ChainError` | `.inputMismatch(needs: Set<ValueKind>, got: ValueKind)`, `.unknownNode`, `.invalidParameter(String)` | FR-015 |

### Attach rule (FR-010, FR-015)

```text
parentOutput = outputKind(of: parent)   // nil parent → .draws
accept iff block.accepts.contains(parentOutput)
```

| Block | accepts | output |
|---|---|---|
| dropFirst / dropLast / prefix / suffix | draws, counts | same as input |
| sortByDate / sortByIndex | draws | draws |
| sortByCount | counts | counts |
| countUniqueElements / countUniqueCombinations / countUniqueSubCombinations | draws | counts |
| countAllElements | draws | number (nothing accepts number) |

## Runs and results (Domain/Ents)

| Type | Fields | Notes |
|---|---|---|
| `SourceDataState` | `recordsCount: Int`, `latestRecord: Date?`, `contentDigest: String` | from `SourceMeta`; digest computed by `LocalStore` on save (research R8) |
| `RunStamp` | `sourceName: String`, `sourceDisplayName: String`, `dataState: SourceDataState`, `chainRevision: Int` | carried by every result (FR-021); `sourceName` is the source id used for lookups, `sourceDisplayName` is what screens show, kept so a removed source is still named (research R15) |
| `SourceSnapshot` | `game: Game`, `dataState: SourceDataState` | what `gameFor` returns (research R16) |
| `BlockFailure` | `.overBudget(limit: Int)`, `.invalidParameter(name: String)`, `.upstreamFailed`, `.cancelled` | per node (FR-022, FR-023, FR-011) |
| `NodeResult` | `.notRun`, `.running`, `.value(BlockValue, RunStamp)`, `.failed(BlockFailure, RunStamp)` | per node, in editor state |
| `RunEvent` | `.nodeFinished(UUID, Result<BlockValue, BlockFailure>)`, `.finished` | streamed by `ChainRunner` |
| `SavedResult` | `id: UUID`, `chainID: UUID`, `nodeID: UUID`, `path: [Block]` (root → node), `value: BlockValue`, `stamp: RunStamp`, `savedAt: Date` | FR-027, FR-028 |
| `ChainDraft` | `chainID: UUID`, `results: [UUID: NodeResult]` (only `.value`/`.failed`), `createdAt: Date` | at most one per chain (FR-031) |
| `ValueSummary` | `.draws(count:)`, `.elements(count:)`, `.combinations(unique:repeating:)`, `.subCombinations(unique:size:)`, `.number(Int)`, `.empty(ValueKind)` | derived from a `BlockValue` by `ResultSummary` (FR-024, research R14); the view maps each case to copy |
| `ResultFreshness` | `.current`, `.outOfDate`, `.sourceUnavailable` | derived; a saved result adds `chainChanged: Bool` as information only (FR-030) |

### Result freshness (FR-021, FR-030)

```text
current(s)                  = dataStates[s] ?? nil                       // lookup per source, research R13

shown result sourceUnavailable ⇔ current(stamp.sourceName) == nil
shown result outOfDate         ⇔ stamp.chainRevision != chain.revision
                                ∨ stamp.dataState   != current(stamp.sourceName)
saved result sourceUnavailable ⇔ current(stamp.sourceName) == nil
saved result outOfDate         ⇔ stamp.dataState   != current(stamp.sourceName)
saved result chainChanged      ⇔ stamp.chainRevision != chain.revision  // information only
```

When the stamp's source has no current state, **source unavailable takes precedence** over out of date:
the result reads "source unavailable", not "out of date".

The state is always the one for **the stamp's own source**, never the chosen source's, so a result from
source A keeps its freshness while B is chosen (SC-007). `dataStates` holds one entry per distinct source
among the chosen source, the saved results and a restored draft.

### Node result lifecycle (editor)

```text
notRun ──run──▶ running ──nodeFinished(ok)──▶ value(stamp)
                   │                               │
                   ├──nodeFinished(err)──▶ failed  │  (edit / sync ⇒ outOfDate, derived — no transition)
                   └──new run / leave──▶ notRun    │
value/failed ──new run──▶ running
```

### Draft lifecycle

```text
none ──app to background with unsaved results──▶ stored
stored ──chain opened──▶ offer restore ─┬─restore──▶ results shown, draft deleted
                                        └─decline──▶ draft deleted
stored ──save results / discard (FR-032)──▶ deleted
stored ──newer background──▶ replaced
```

## Persistence (Domain/Repos contract, Data/Repos impl)

`ChainsRepo` (Domain) is implemented by `ChainsRepoImpl` (Data), file-backed under
`Application Support/lottoApp2/chains/`:

```text
chains/
└── <chainID>/
    ├── chain.json          # Chain
    ├── draft.json          # ChainDraft (optional)
    └── results/
        └── <resultID>.json # SavedResult
```

Deleting a chain removes its directory (results and draft with it — FR-017). `SourceMeta` gains
`contentDigest`; `LocalStore.save` computes it from the merged draws.

## Presentation state (reducers)

| Reducer | New / changed state | Notes |
|---|---|---|
| `BlocksPage` (changed) | `sourceID`, `sourceName`, `chains: IdentifiedArrayOf<Chain>`, `@Presents editor: ChainEditor.State?`, `@Presents alert` (delete confirmation naming the saved-result count and a draft) | becomes the chain list (FR-017, FR-032) |
| `ChainEditor` (new) | `chain: Chain`, `source: ChainSource { id, name }`, `results: [UUID: NodeResult]`, `dataStates: [String: SourceDataState?]`, `isRunning`, `savedResults: IdentifiedArrayOf<SavedResult>`, `savedNodeIDs: Set<UUID>`, `collapsed: Set<UUID>`, `@Presents addBlock`, `@Presents result`, `@Presents alert` | derived: `freshness(nodeID)`, `summary(nodeID)` (every node that ran), `hasUnsavedResults` (`.value` nodes not in `savedNodeIDs`) |
| `AddBlock` (new) | `parentID: UUID?`, `parentOutput: ValueKind`, `path: StackState<Step>`, `draft: Block?`, `validation: ChainError?` | delegate `.added(Block)` / `.edited(UUID, Block)` |
| `ResultPage` (new, LTA-9/LTA-18) | `value: BlockValue`, `stamp: RunStamp`, `freshness: ResultFreshness`, `chainChanged: Bool` (saved results only) | opened for a shown result of any node that ran, or for a saved result; grouped view for combinations (LTA-18) |
