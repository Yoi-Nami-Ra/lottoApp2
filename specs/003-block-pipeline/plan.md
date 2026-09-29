# Implementation Plan: Processing Block Pipeline

**Branch**: `003-block-pipeline` | **Date**: 2026-09-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-block-pipeline/spec.md`

## Summary

Turn the display-only block catalogue into a pipeline a person can build, run, save and reuse. A chain is
a tree of blocks rooted at an implicit input; each run feeds it the draws of the source chosen on the
start page. Blocks exchange three kinds of data (draws, count results, a number), and a pure Domain rule
refuses any block whose input doesn't match its parent's output. A run evaluates every block once, parents
first, streaming per-node results so progress is visible and one failing leaf doesn't stop the others.
Every result carries a stamp (source, source data state, chain revision), which is how shown and saved
results know they are out of date. Chains, saved results and per-chain drafts persist as JSON files.

Technical approach: inner-to-outer per the constitution.

- **Domain entities** (LTA-6/7): draws as `Combination`/`Game` with sorted-array set semantics.
- **Pipeline Domain types**: `BlockValue`, `CountResult`, a `Block` enum with its kind table, a `Chain` of
  parent-pointer nodes.
- **Pure rules and evaluator**: attach, edit, remove, evaluate.
- **`ChainRunner` dependency**: streams `RunEvent`s.
- **`ChainsRepo` contract**: a Domain contract with a file-backed Data implementation.
- **Existing seams**: `SourcesBLogic`/`SourcesRepo` gain `gameFor`/`dataStateFor`, and `SourceMeta` gains a
  content digest.
- **Presentation**: `BlocksPage` becomes the chain list, with new `ChainEditor`, `AddBlock` and `ResultPage`
  reducers pushed as nested tree-based destinations.

**No new SPM dependency.** CryptoKit (system) is used for the digest.

## Technical Context

**Language/Version**: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (non-UI types `nonisolated`),
Xcode 27 Beta toolchain.

**Primary Dependencies**: `ComposableArchitecture`, `swift-dependencies`, `swift-identified-collections`,
`swift-navigation`; system `CryptoKit` (SHA-256 digest) and `Foundation` (JSON). No new package.

**Storage**: JSON files in Application Support (`lottoApp2/chains/<id>/…`) for chains, saved results and
drafts; `sources/<name>/meta.json` gains `contentDigest`. See [data-model.md](./data-model.md#persistence-domainrepos-contract-datarepos-impl).

**Testing**: swift-testing + TCA `TestStore`. Pure Domain rules and the evaluator get plain `@Test`s over a
hand-computed reference set; reducers are tested exhaustively with dependencies overridden; the file repo is
tested against a temp directory (the existing `LocalStore` pattern).

**Target Platform**: iOS 18.6+ (iPhone, iPad, Mac "Designed for iPad", visionOS per the target settings).

**Project Type**: Mobile app, single target, layered `Presentation` / `Domain` / `Data`.

**Performance Goals**: No hard time limits (clarified). A run streams per-node progress, and the UI stays
responsive because evaluation runs off the main actor (SC-003). A shared node is evaluated once per run
(SC-004). Expected workload: about 7,000 draws. Elements come to about 42k updates, pairs about 105k,
triples about 140k.

**Constraints**:
- Reducers stay pure: the only effects are repo I/O, `gameFor`, and consuming the runner stream.
- Sub-combination work is capped at 5,000,000 per leaf (FR-022).
- iOS offers no hook when the app is closed from the switcher, so drafts are written on
  `scenePhase == .background` (FR-031).

**Scale/Scope**:
- **Domain:** about 9 new entity types, 3 rule/evaluator files and 2 new dependencies.
- **Data:** 1 new repo implementation and 2 modified files.
- **Presentation:** 3 new reducers and views; `BlocksPage` rewritten as the chain list.
- **Delivery:** spread across LTA-6/7/9/18/19/20–27 and the follow-up tickets.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment | Status |
|-----------|------------|--------|
| I. Layered Clean Architecture | New entities, pipeline types, rules, `ChainRunner` and the `ChainsRepo` contract live in Domain. The only Data additions are `ChainsRepoImpl` and the `SourceMeta` digest. Presentation reaches data only through `blSources`, `chainRunner` and `chainsRepo`. Domain types are `Codable` (a standard-library protocol), which imports nothing from Data (research R9). | ✅ Pass |
| II. TCA for state & logic | `ChainEditor`, `AddBlock` and `ResultPage` are `@Reducer`s with `@ObservableState`. All branching sits in reducers or pure Domain rules: attach validity, out-of-date state, unsaved-results checks, the leave warning. Runs are `.run` effects with `cancelInFlight`. Views only render state and send actions; the custom back button just sends `backTapped`. | ✅ Pass |
| III. Test-First (NON-NEGOTIABLE) | Every rule and block has a failing test first against the reference set. The attach table is enumerated exhaustively (SC-002). Runner tests cover sharing, failure isolation and cancellation. Reducer `TestStore`s assert every mutation and every received `runEvent`. The repo is tested in a temp directory. No test touches real disk or network. | ✅ Pass |
| IV. DI via swift-dependencies | New `ChainRunner` and `ChainsRepo` are struct-of-closures `DependencyKey`s with `liveValue`, `previewValue` and an `unimplemented` `testValue`. `SourcesBLogic`/`SourcesRepo` gain closures in the same shape. Nothing is constructed directly in reducers or views. | ✅ Pass |
| V. Declarative Views with Design Tokens | Chain outline, add-block sheet and result views follow the LTA-21 and LTA-22 proposals. Every colour, size, image and piece of copy is a token, and each view has light and dark `#Preview`s for its states (not run, running, fresh, out of date, failed, empty, restore prompt). | ✅ Pass |

**Deviations**: None.

**Gate result**: PASS. Proceed to Phase 0.

**Post-analysis re-check (2026-09-29)**: PASS. The `/speckit-analyze` findings that touched design are
resolved in research R11 (revised) and R13–R16, and carried into data-model.md, contracts and quickstart:
- **II**: leaf and intermediate summaries are a Domain function, not view code (R14), and every action
  payload stays `Equatable` (`SourceSnapshot`, `ChainSource`, R16).
- **III**: opening a saved result, per-source freshness and dismiss-cancels-run each have a named test
  home (contracts §5, quickstart §1).
- **IV**: new node ids come from `@Dependency(\.uuid)` through `attaching(_:under:id:)` (R16).
- **V**: alert copy uses `AlertState` builders over `TextState` tokens, the `SourceEntry` pattern (R16).

**Post-Phase-1 re-check**: PASS.
- The design adds two injected seams and one Data implementation, with no layer crossing.
- The one view-level behaviour, owning the back button, only sends an action; the decision stays in the reducer (research R11).
- The `Codable`-on-Domain choice is recorded in R9 with the DTO alternative. It isn't a principle violation, so no Complexity Tracking entry is needed.

## Project Structure

### Documentation (this feature)

```text
specs/003-block-pipeline/
├── plan.md                     # This file
├── research.md                 # Phase 0 — decisions R1–R16
├── data-model.md               # Phase 1 — types, invariants, lifecycles, storage layout
├── quickstart.md               # Phase 1 — tests to run and manual end-to-end checks
├── contracts/
│   └── domain-contracts.md     # Phase 1 — rule functions, ChainRunner, ChainsRepo, SourcesBLogic additions, reducer surfaces
├── checklists/
│   └── requirements.md         # Spec quality checklist
└── tasks.md                    # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
lottoApp2/
├── Domain/
│   ├── Ents/
│   │   ├── Draws.swift                  # NEW — Element, CombinationType, Combination, SubCombination, GameEntry, GameType, Game, DomainError (LTA-6/7)
│   │   ├── PipelineValues.swift         # NEW — ValueKind, BlockValue, CountItem, UniqueCount, CountResult, SortDirection
│   │   ├── Block.swift                  # NEW — Block enum + accepts/output table
│   │   ├── ProcessingBlockKind.swift    # MODIFIED — every catalogue case + defaultBlock
│   │   ├── Chain.swift                  # NEW — Chain, ChainNode, ChainError
│   │   └── RunResults.swift             # NEW — SourceDataState, SourceSnapshot, RunStamp, BlockFailure, NodeResult, RunEvent, SavedResult, ChainDraft, ValueSummary, ResultFreshness
│   ├── BLogic/
│   │   ├── ChainRules.swift             # NEW — attaching / updating / removingSubtree / outputKind / path
│   │   ├── BlockEvaluator.swift         # NEW — filters, sorts, counts, sub-combination budget
│   │   ├── ChainRunner.swift            # NEW — DependencyKey; live walks nodes parents-first, streams RunEvent
│   │   ├── Freshness.swift              # NEW — ResultFreshness per result, judged against the stamp's own source (R13)
│   │   ├── ResultSummary.swift          # NEW — BlockValue → ValueSummary for every node that ran (R14)
│   │   └── SourcesBLogic.swift          # MODIFIED — gameFor, dataStateFor
│   └── Repos/
│       ├── SourcesRepo.swift            # MODIFIED — gameFor, dataStateFor
│       └── ChainsRepo.swift             # NEW — contract + DependencyKey (live → ChainsRepoImpl.live)
├── Data/
│   ├── Repos/
│   │   ├── SorcesRepoImp.swift          # MODIFIED — DrawDTO → GameEntry mapping, SourceDataState (existing misspelled filename, LTA-17)
│   │   ├── mbnetSourceModule.swift      # MODIFIED — declares its GameType (Lotto 6/49)
│   │   └── ChainsRepoImpl.swift         # NEW — file-backed ChainStore actor
│   └── Sources/
│       └── LocalStore.swift             # MODIFIED — SourceMeta.contentDigest, computed on save
└── Presentation/
    ├── BlocksPage/
    │   ├── BlocksPage.swift             # MODIFIED — becomes the chain list (FR-017)
    │   └── BlocksPageView.swift         # MODIFIED
    ├── ChainEditor/
    │   ├── ChainEditor.swift            # NEW — outline, run, results, save, back-warning, draft
    │   ├── ChainEditorView.swift        # NEW — per design/proposal/21-chain-builder.html
    │   ├── AddBlock.swift               # NEW — catalogue + parameter step (sheet)
    │   └── AddBlockView.swift           # NEW — per design/proposal/22-add-block-sheet.html
    ├── Results/
    │   ├── ResultPage.swift             # NEW — element list (LTA-9), grouped combinations (LTA-18)
    │   └── ResultPageView.swift         # NEW
    └── Previews/
        └── PreviewFixtures.swift        # MODIFIED — sample games, chains, results

lottoApp2Tests/
├── Domain/                              # NEW folder — ReferenceDraws (fixture), CombinationTests, PipelineValuesTests, BlockEvaluatorTests, ChainRulesTests, ChainRunnerTests, FreshnessTests, ResultSummaryTests
├── Data/                                # NEW folder — ChainsRepoImplTests, LocalStoreDigestTests
└── Reducers/
    ├── BlocksPageTests.swift            # MODIFIED — chain list
    ├── ChainEditorTests.swift           # NEW
    ├── AddBlockTests.swift              # NEW
    ├── ResultPageTests.swift            # NEW
    └── PipelineMocks.swift              # NEW — in-memory ChainsRepo, scripted/controlled ChainRunner
```

**Structure Decision**: the existing three-layer tree is kept.
- New Domain types split by concern under `Ents/`, and the logic under `BLogic/`.
- `ChainsRepo` follows the `SourcesRepo` shape: a contract in `Domain/Repos`, the implementation in `Data/Repos`.
- The chain editor gets its own `Presentation/ChainEditor/` folder, and result screens go in `Presentation/Results/`.
- The Xcode project uses file-system synchronized groups, so new files and test folders join their targets without a `project.pbxproj` edit.

**Delivery note**: this plan spans several tickets, per the spec's Delivery Map. `/speckit-tasks` should group tasks by ticket, inner to outer:
1. LTA-6/7: entities.
2. LTA-19: rules, evaluator, runner, freshness.
3. The saved-chains follow-up: `ChainsRepo`, digest, chain list.
4. LTA-9 and LTA-24 to LTA-27, LTA-18: blocks and result screens.
5. LTA-23: editor and add-block UI, once the LTA-21 and LTA-22 designs are final.

The tickets that were stale against the clarified spec have been updated, in commit 4183d4c before tasks were generated. LTA-19 and LTA-20 had described chains rooted at a source that lasted for the session only. LTA-23 had described evolving `BlocksPage` into the outline, where this plan makes it the chain list. LTA-30 to LTA-32 were added.

## Complexity Tracking

> No Constitution Check violations. This table is retained empty per the template's instruction.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| _(none)_ | — | — |
