# Phase 0 Research: Processing Block Pipeline

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-29

The spec entered planning with no `[NEEDS CLARIFICATION]` markers: ticket refinement (LTA-6 … LTA-27)
plus three `/speckit-clarify` sessions settled 25 questions. What remained were design decisions. Each
is recorded as Decision / Rationale / Alternatives considered.

---

## R1 — Domain value types for draws

**Decision**: Add the LTA-6 entities to `Domain/Ents/`: `Element` (`UInt` typealias), `CombinationType`
(`pick`, `pool`), `Combination` (a `CombinationType` plus its elements stored as a **sorted, duplicate-free
`[Element]`**), `SubCombination` (same storage, `size` z, parent `CombinationType`), `GameEntry` (`index`,
`date`, `combination`), `GameType` (`id`, `name`, `combinationType`), `Game` (`type`, `entries`). All are
`nonisolated`, `Hashable`, `Sendable`, `Codable`. Constructors are `throws(DomainError)` and enforce every
FR-001/FR-002 invariant.

**Rationale**:

- A sorted array gives set semantics for equality and hashing (FR-001) *and* a total order for free:
  comparing two sorted arrays element by element is exactly the tie-break FR-008 asks for. A `Set` would
  need a second, derived sorted form for ordering and display.
- Typed throws name the broken rule (x > y, wrong count, duplicate, out of pool, mixed shapes), which is
  what LTA-6's tests and LTA-2's sync-time validation both need.

**Alternatives considered**: `Set<Element>` storage (no inherent order; every sort and display re-sorts);
failable initialisers (lose the reason); precondition traps (a malformed stored row would crash a read).

---

## R2 — The three data kinds as one enum

**Decision**: `BlockValue` is an enum with `.draws(Game)`, `.counts(CountResult)` and `.number(Int)`; its
`kind` is the matching case of `ValueKind { draws, counts, number }`. `CountResult` holds
`[UniqueCount]` and an `ordering` of `.unordered` or `.byCount(SortDirection)`. `UniqueCount` is
`(item: CountItem, count: Int)` where `CountItem` is `.element`, `.combination` or `.subCombination`.
An unordered result is always *stored* item-ascending, so equality and display are deterministic (FR-025).

**Rationale**: Blocks are chained at run time (FR-013), so the compiler cannot check the wiring; one enum
makes the three kinds explicit and lets the attach rule and the evaluator switch exhaustively. Storing the
unordered form canonically means two equal results compare equal in tests without sorting first.

**Alternatives considered**: Generic `Block<Input, Output>` — rejected in LTA-8 because chains are built
by the person, not in code; `Any`-typed values — no exhaustiveness, easy to misroute.

---

## R3 — Blocks as data, not closures

**Decision**: A `Block` enum with associated parameters:
`dropFirst(UInt)`, `dropLast(UInt)`, `prefix(UInt)`, `suffix(UInt)`, `sortByDate(SortDirection)`,
`sortByIndex(SortDirection)`, `sortByCount(SortDirection)`, `countUniqueElements`,
`countUniqueCombinations`, `countUniqueSubCombinations(z: Int)`, `countAllElements`. Each case declares
`accepts: Set<ValueKind>` and `output(given: ValueKind) -> ValueKind` (filters return what they are given).
`ProcessingBlockKind` stays the catalogue identity — one case per `Block` case without parameters — and
gains `defaultBlock` (e.g. `prefix(10)`, `sortByCount(.descending)`, `countUniqueSubCombinations(z: 2)`).

**Rationale**: A value-type block is `Equatable` and `Codable`, so it can live in TCA state (Principle II)
and be saved with a chain (FR-017) with no mapping. The kind table in FR-010 becomes two small exhaustive
switches that a test can enumerate for SC-002.

**Alternatives considered**: a protocol per block with an `apply` method (not `Equatable`/`Codable` without
type erasure); storing closures in the chain (not persistable, not comparable).

---

## R4 — Chain as a flat list of parent pointers

**Decision**: `Chain` is `id: UUID`, `name: String`, `revision: Int`, `nodes: IdentifiedArrayOf<ChainNode>`
where `ChainNode` is `id: UUID`, `parentID: UUID?` (`nil` = directly under the chain's input) and `block`.
The input itself is implicit: it always outputs `.draws` (FR-013). Every edit (add, remove, change
parameters, rename excluded) increments `revision`.

**Rationale**: A parent-pointer list is `Codable`, diff-friendly in `TestStore` assertions, and needs no
recursive enum. Children, paths and subtree removal are straightforward derived queries. The revision
counter gives FR-021's "edited since the run" a single integer comparison instead of a structural diff.

**Alternatives considered**: a recursive `indirect enum`/nested children arrays (awkward to edit in place
and to address a node by id); a separate input node with a source reference (contradicts the
source-independent chain from the clarifications).

---

## R5 — Attach rule and parameter validation are pure Domain functions

**Decision**: `Chain.attaching(_:under:) throws(ChainError) -> Chain`, `Chain.updating(_:to:)`,
`Chain.removingSubtree(_:)` and `Chain.outputKind(of:)` live in `Domain/BLogic/ChainRules.swift`. A refused
attach throws `.inputMismatch(needs: Set<ValueKind>, got: ValueKind)` and returns nothing, so the chain is
unchanged by construction (FR-015). Parameter bounds that do not depend on a source (x ≥ 0 by type,
z ≥ 2) are checked here; z < x is checked at run time (FR-011).

**Rationale**: pure functions are trivially testable with swift-testing and keep reducers thin — the
editor reducer calls the rule and stores the result or the error.

**Alternatives considered**: validating in the reducer (logic in Presentation, Principle II) or in the
view by hiding options (the rule must hold regardless of UI; LTA-22 greys options out *using* this rule).

---

## R6 — Execution: one pass, parents first, cooperative cancellation

**Decision**: `ChainRunner` (Domain/BLogic, a `DependencyKey` struct of closures) exposes
`run: @Sendable (Chain, Game) -> AsyncStream<RunEvent>` with events `.nodeFinished(id, Result<BlockValue,
BlockFailure>)` and `.finished`. The live implementation walks nodes in parent-before-child order,
evaluates each once and hands the value to every child (FR-019), checks `Task.isCancelled` between nodes
and inside the counting loops, and turns a per-node error into that node's failure (FR-023) — descendants
of a failed node fail with `.upstreamFailed`. The reducer starts it in `.run` with
`.cancellable(id: RunID, cancelInFlight: true)` (FR-020) and forwards events as actions, which also drives
progress (FR-018, SC-003).

**Rationale**: streaming per node gives visible progress with no extra machinery and makes "one leaf
fails, others succeed" natural. `cancelInFlight` is TCA's built-in answer to "a new run stops the old
one". The algorithms are pure functions over value types, so the stream is the only effectful edge.

**Alternatives considered**: a single `async throws -> [NodeID: BlockValue]` (no progress; one failure
aborts all); running each leaf's path separately (re-evaluates shared blocks, violates FR-019).

---

## R7 — Counting and sorting algorithms

**Decision**: counts use a `[CountItem: Int]` dictionary over one pass; sub-combinations are generated
per entry by an index-combination walk (C(x, z) per entry) after checking the FR-022 budget
(`entries × C(x, z) ≤ 5_000_000`, one named constant). Sorts are stable sorts with the explicit tie-breaks
(date → index ascending; count → item ascending regardless of direction). Filters use Swift's clamping
`prefix`/`suffix`/`dropFirst`/`dropLast`, which already match FR-006.

**Rationale**: ~7,000 draws × 6 elements is ~42k dictionary updates — negligible; pairs are ~105k, triples
~140k. The budget check before generating prevents pathological memory use for large-x games.

**Alternatives considered**: precomputing counts at sync time (couples sync to blocks; stale on edit);
lazily generated sub-combinations without a budget (unbounded work).

---

## R8 — Out-of-date detection: chain revision + source data state

**Decision**: every run result carries a `RunStamp` — `sourceName`, `SourceDataState` and
`chainRevision`. `SourceDataState` is `recordsCount`, `latestRecord` and a `contentDigest` (SHA-256 over
the stored draws, computed by `LocalStore` when it saves and persisted in `SourceMeta`). A shown result is
out of date when `chain.revision != stamp.chainRevision` or the source's current state differs; a saved
result only compares the source state (FR-030), and separately shows "chain changed since" when the
chain's revision moved on.

**Rationale**: the digest catches a sync that rewrites a draw without changing the count (the store's merge
updates same-index draws). Computing it at save time means checking staleness is a metadata read, not a
re-hash of every draw.

**Alternatives considered**: `lastSync` alone (every sync marks results stale even when nothing changed);
`recordsCount` + `latestRecord` alone (misses in-place corrections).

---

## R9 — Persistence of chains, saved results and drafts

**Decision**: a Domain contract `ChainsRepo` (struct of closures, `DependencyKey`) with list/save/delete for
chains, list/save/delete for a chain's saved results, and get/put/delete for a chain's draft. The Data
implementation `ChainsRepoImpl` is a file-backed actor like `LocalStore`'s `FileStore`, under
`Application Support/lottoApp2/chains/<chainID>/` — `chain.json`, `results/<resultID>.json`,
`draft.json` — written atomically. Deleting a chain removes its directory (FR-017's cascade). Domain value
types are `Codable` and encoded directly.

**Rationale**: matches the existing storage approach (plain JSON files, one actor per root) and keeps one
directory per chain, so the cascade delete and "list results of chain X" (FR-029) are directory operations.
`Codable` is a standard-library protocol, not a Data-layer type, so Domain stays free of Data imports.

**Alternatives considered**: SwiftData/Core Data (new framework and migration story for a handful of JSON
documents); Data-layer DTO mirrors of every Domain type (doubles the type count for no behavioural gain —
revisit if the stored format needs to diverge from the Domain shape).

---

## R10 — Navigation: nested tree-based destinations

**Decision**: keep `StartPage` as the root store with its existing `@Presents var blocks`. `BlocksPage`
becomes the **chain list** for the chosen source (FR-017) and gains `@Presents var editor:
ChainEditor.State?`; `ChainEditor` (new) is the chain outline (LTA-21) with `@Presents var result:
ResultPage.State?` and `@Presents var addBlock: AddBlock.State?` (sheet, LTA-22). Each view adds its own
`.navigationDestination(item:)` inside the single `NavigationStack` from spec 002.

**Rationale**: spec 002's R1 named a `StackState` migration as the step to revisit "once the flow is a
multi-step pipeline". The flow is now three pushes deep but still strictly linear with one destination per
level, which tree-based navigation models exactly; it keeps the app entry point unchanged and makes each
level's leave-warning (FR-032) a local concern.

**Alternatives considered**: a root `AppFeature` with `StackState<Path>` — worth it when screens can be
reached in more than one order; not yet the case, and it would move the FR-032 interception into a
generic path reducer.

---

## R11 — Warning before unsaved results are lost

**Decision**: `ChainEditorView` hides the system back button and provides its own, which sends
`backTapped`; the reducer either dismisses or presents a confirmation (`Save` / `Discard` / `Cancel`,
FR-032). Hiding the back button also disables the interactive swipe-back, so every in-app exit passes
through the reducer. *(Revised 2026-09-29, analysis follow-up.)* Opening another chain and deleting a
chain happen only from the chain list, after the editor has been left through this check, so
`BlocksPage` runs no second copy of it. What `BlocksPage` does check is the draft: `deleteChainTapped`
reads `chainsRepo.draft(id)` alongside the saved-result count, and the delete confirmation names both
("Delete chain, 3 saved results and its unsaved results?"). There is no save option from the list
(spec FR-017, FR-032).

Leaving the editor (the reducer sends `dismiss`, or the parent nils `editor`) cancels a run in progress
with no extra code: TCA's `ifLet` for a non-ephemeral `@Presents` child emits a cancel for that child's
effects when it is dismissed. This is tested once at the `BlocksPage` level (dismiss the editor mid-run
→ no further `runEvent`), not inside `ChainEditor`, which cannot observe its own dismissal.

**Rationale**: SwiftUI offers no hook to veto a `NavigationStack` pop; owning the back action is the
reliable way to ask first. One check at the one exit keeps the rule in one reducer.

**Alternatives considered**: re-pushing after an unwanted pop (visible flicker, racy); disabling the
swipe gesture through UIKit (reaches past SwiftUI for one behaviour).

---

## R12 — Drafts on backgrounding

**Decision**: `ChainEditorView` observes `@Environment(\.scenePhase)` and sends
`scenePhaseChanged(.background)`; the reducer, when it has unsaved results, writes them with
`chainsRepo.putDraft` in an effect (FR-031). On `onAppear` the editor reads the draft and, if present,
presents "Restore unsaved results?" — restore puts them back (the FR-021 out-of-date rules then apply
through their stamps); decline deletes the draft. Saving or discarding results deletes it too.

**Rationale**: `.background` is the last moment the app is guaranteed to run before the system may
terminate it; iOS gives no callback on swipe-to-close.

**Alternatives considered**: writing a draft after every run (unnecessary writes; the rule is "on
background"); saving drafts as regular saved results (rejected in clarification, option C).

---

## R13 — Freshness is judged against each result's own source *(added 2026-09-29, analysis follow-up)*

**Decision**: A result is compared with the current data state of **the source named in its stamp**, not
with the source the editor happens to have chosen. The freshness rules take a lookup rather than one
state: `isOutOfDate(chainRevision:, dataStates: [String: SourceDataState?])`. `ChainEditor` keeps
`dataStates: [String: SourceDataState?]`, filled on `onAppear` with one `blSources.dataStateFor` call per
distinct source among the chosen source, the saved results' stamps and a restored draft's stamps. A
missing key or a `nil` value means "source unavailable".

**Rationale**: FR-021 and FR-030 define staleness against *its* source. Saved results from source A are
listed while B is chosen (US8 AS4, SC-007), and a draft can be restored after the person switched source.
Comparing with the chosen source's state would mark A's untouched results out of date, or hide a real
change.

**Alternatives considered**: one `currentDataState` for the chosen source (wrong for every other source's
result); reading the state lazily when a row is drawn (puts I/O in the view path).

---

## R14 — Result summaries are Domain values *(added 2026-09-29, analysis follow-up)*

**Decision**: `ResultSummary` (Domain/BLogic) is a pure, tested function `BlockValue → ValueSummary`, with
`ValueSummary` = `.draws(count:)`, `.elements(count:)`, `.combinations(unique:, repeating:)`,
`.subCombinations(unique:, size:)`, `.number(Int)`, `.empty(ValueKind)`. `ChainEditor` exposes the
summary per node that has run (a leaf or an intermediate block, FR-024), and the view only maps each case
to a `LocalizedStringKey` token.

**Rationale**: "7,009 unique, 3 repeat" means counting repeats, which is data transformation. Principle II
keeps that out of views, and Principle III wants it under test.

**Alternatives considered**: formatting in a view-file extension (untested logic in Presentation);
storing the summary in `NodeResult` (duplicates the value and must be kept in step with it).

---

## R15 — The stamp carries the source's display name *(added 2026-09-29, analysis follow-up)*

**Decision**: `RunStamp` gains `sourceDisplayName: String`, taken from the editor's `ChainSource` when
the run starts. `sourceName` stays the id used for lookups (R13).

**Rationale**: US8 AS1 wants results to name their source, and a saved result must still name it when
the source no longer exists ("source unavailable", FR-030). A later lookup through `knownSources()`
cannot do that.

**Alternatives considered**: resolving the name through `blSources.knownSources()` on display (fails for
a removed source, and adds I/O to every list); showing the id (not user-facing copy).

---

## R16 — Small shapes that keep reducers testable *(added 2026-09-29, analysis follow-up)*

**Decision**:
- `gameFor` returns `Result<SourceSnapshot, SourcesBLogic.Error>` with `struct SourceSnapshot: Equatable,
  Sendable { game: Game, dataState: SourceDataState }`, not a tuple, so the action carrying it stays
  `Equatable`.
- `Chain.attaching(_:under:id:)` takes the new node's id from the caller (`@Dependency(\.uuid)` in the
  reducer), which keeps the rule pure and deterministic under `TestStore`.
- `ChainEditor.State.source` is `struct ChainSource: Equatable, Sendable { id: String, name: String }`
  (a tuple isn't `Equatable`).
- `editTapped(ChainNode.ID)` is its own action; `nodeTapped` on any node that has run opens its result
  (FR-024 now covers intermediate blocks), so editing can't hang off the same tap.
- `hasUnsavedResults` counts `.value` nodes not saved since the last run. A failure cannot be saved, so it
  doesn't trigger the FR-032 warning, but it still goes into the draft.
- Alert copy follows the existing pattern in `SourceEntry.swift`: `extension AlertState where Action ==
  <Feature>.Action.Alert` with `static` builders whose text comes from `TextState(.token)` tokens, so
  reducers never hold inline copy (Principle V).

**Rationale**: each is a small signature choice that the contracts need to fix before tasks. Together they
keep state `Equatable` (Principle II), ids injected (Principle IV) and copy in tokens (Principle V).

**Alternatives considered**: `UUID()` inside `attaching` (non-deterministic tests); `nodeTapped` doing
double duty (ambiguous for a node that has a result); counting failures as unsaved (the warning could only
be cleared by discarding).
