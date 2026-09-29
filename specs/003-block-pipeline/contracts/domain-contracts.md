# Domain Contracts: Processing Block Pipeline

**Feature**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md)

The seams this feature adds, in the project's struct-of-closures + `DependencyKey` shape (Principle IV).
Signatures are the contract; bodies belong to implementation. Every contract ships a `liveValue` and a
`testValue` built from `unimplemented(...)` so an unexpected call fails a test.

## 1. Pure rules (no dependency — plain functions, Domain/BLogic)

```swift
extension Block {
    var accepts: Set<ValueKind> { get }
    func output(given input: ValueKind) -> ValueKind
}

extension Chain {
    func outputKind(of nodeID: ChainNode.ID?) throws(ChainError) -> ValueKind   // nil → .draws
    func attaching(_ block: Block, under parentID: ChainNode.ID?) throws(ChainError) -> (Chain, ChainNode.ID)
    func updating(_ nodeID: ChainNode.ID, to block: Block) throws(ChainError) -> Chain
    func removingSubtree(_ nodeID: ChainNode.ID) throws(ChainError) -> (Chain, removed: Int)
    func children(of nodeID: ChainNode.ID?) -> [ChainNode]
    func path(to nodeID: ChainNode.ID) -> [Block]                       // root → node
    var leaves: [ChainNode] { get }
}

enum BlockEvaluator {
    static let subCombinationBudget = 5_000_000                        // FR-022, one tunable constant
    static func evaluate(_ block: Block, on input: BlockValue) throws(BlockFailure) -> BlockValue
}
```

Guarantees: `attaching` never returns a chain containing a mismatched edge (FR-015); every mutating
function increments `revision`; `evaluate` is deterministic for equal inputs (SC-001).

## 2. `ChainRunner` (Domain/BLogic, `@Dependency(\.chainRunner)`)

```swift
nonisolated struct ChainRunner: Sendable {
    var run: @Sendable (Chain, Game) -> AsyncStream<RunEvent>
}
```

- Emits exactly one `.nodeFinished` per node, parents before children, then `.finished` (FR-018, FR-019).
- A node whose parent failed finishes with `.failure(.upstreamFailed)`; siblings are unaffected (FR-023).
- Stops promptly when the consuming task is cancelled (FR-020); no events after cancellation.
- `liveValue` evaluates off the main actor using `BlockEvaluator`; tests supply a scripted stream.

## 3. `SourcesBLogic` additions (Domain/BLogic, existing `@Dependency(\.blSources)`)

```swift
var gameFor: @Sendable (_ sourceID: String) async -> Result<(Game, SourceDataState), SourcesBLogic.Error>
var dataStateFor: @Sendable (_ sourceID: String) async -> SourceDataState?     // nil → source unavailable
```

Backed by new `SourcesRepo` closures of the same shape; `SourcesRepoImpl` maps `DrawDTO` → `GameEntry`
(LTA-6) and `SourceMeta` → `SourceDataState`.

## 4. `ChainsRepo` (Domain/Repos contract, Data/Repos impl, `@Dependency(\.chainsRepo)`)

```swift
nonisolated struct ChainsRepo: Sendable {
    // chains (FR-017)
    var listChains: @Sendable () async -> [Chain]
    var saveChain: @Sendable (Chain) async throws -> Void                 // insert or replace by id
    var deleteChain: @Sendable (Chain.ID) async throws -> Void            // cascades results + draft

    // saved results (FR-027 – FR-030)
    var listResults: @Sendable (Chain.ID) async -> [SavedResult]
    var saveResult: @Sendable (SavedResult) async throws -> Void
    var deleteResult: @Sendable (SavedResult.ID) async throws -> Void

    // drafts (FR-031)
    var draft: @Sendable (Chain.ID) async -> ChainDraft?
    var putDraft: @Sendable (ChainDraft) async throws -> Void             // replaces any existing
    var deleteDraft: @Sendable (Chain.ID) async throws -> Void
}
```

`liveValue = ChainsRepoImpl.live` (file-backed, Application Support); `previewValue` is in-memory;
`testValue` is `unimplemented`.

## 5. Reducer surfaces (Presentation)

### `BlocksPage` (changed — chain list)

| Action | Effect |
|---|---|
| `onAppear` | `chainsRepo.listChains` → `chainsLoaded` |
| `newChainTapped` | creates an empty named chain, saves it, presents `editor` |
| `chainTapped(Chain.ID)` | presents `editor` for that chain |
| `renameChain(Chain.ID, String)` | saves the chain |
| `deleteChainTapped(Chain.ID)` | loads its saved-result count → alert "Delete chain and N saved results?" → `deleteChain` |
| `editor(.presented(.delegate(.chainChanged(Chain))))` | replaces the row |

### `ChainEditor` (new — chain outline, LTA-21/LTA-23)

| Action | Behaviour |
|---|---|
| `onAppear` | loads saved results and `dataStateFor(source)`; if a draft exists → restore alert |
| `addTapped(parent: ChainNode.ID?)` | presents `AddBlock` with the parent's output kind |
| `addBlock(.presented(.delegate(.added(Block))))` | `attaching` → save chain; new leaf `.notRun` |
| `nodeTapped(ChainNode.ID)` | leaf with a value → push `result`; otherwise present `AddBlock` in edit mode |
| `removeTapped(ChainNode.ID)` | confirm if it has children → `removingSubtree` → save chain |
| `runTapped` | `gameFor(source)` then `chainRunner.run`, `cancelInFlight`; every node → `.running` |
| `runEvent(RunEvent)` | sets `NodeResult`; `.finished` clears `isRunning` |
| `saveResultTapped(ChainNode.ID)` | builds `SavedResult` (path, value, stamp) → `saveResult` |
| `backTapped` | unsaved results → alert Save / Discard / Cancel; else dismiss (FR-032) |
| `scenePhaseChanged(.background)` | unsaved results → `putDraft` (FR-031) |
| delegate `.chainChanged(Chain)` | tells `BlocksPage` to refresh its row |

`hasUnsavedResults` = any `.value`/`.failed` node whose value has not been saved since the last run.

### `AddBlock` (new — sheet, LTA-22)

Catalogue step lists every `ProcessingBlockKind`, each marked available iff
`kind.defaultBlock.accepts.contains(parentOutput)`, with a reason otherwise. Parameter step validates
(x whole ≥ 0; z ≥ 2) and returns `.delegate(.added(Block))` or `.delegate(.edited(ChainNode.ID, Block))`.

## 6. Data-layer changes

- `SourceMeta` gains `contentDigest: String` (decoded with a default when missing, so existing
  `meta.json` files still load; the next sync writes it).
- `LocalStore.save` computes the digest over the merged, index-sorted draws.
- New `ChainsRepoImpl` with a private `ChainStore` actor per root, atomic writes, directory-per-chain.
