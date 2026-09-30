# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`lottoApp2` is an iOS/SwiftUI app built with **The Composable Architecture (TCA)** and **swift-dependencies**. It is an early-stage project: much of the Data layer is stubbed (see the `// TODO` markers and placeholder `RemoteSourcesManagerImp.live` returning empty data), while the Domain contracts, reducers, and their tests are the parts that are real and enforced.

## Governance — read this first

`.specify/memory/constitution.md` (v1.0.2) is the binding source of truth for this codebase and **supersedes ad-hoc conventions**. Any change is reviewed against it. The five principles below are non-negotiable; the constitution has the full text and rationale.

1. **Layered Clean Architecture** — dependencies point inward only: `Presentation (UI) → Domain → Data`. Domain must not reference concrete Data types; Presentation must not reach past Domain into Data. Layers collaborate only through Domain-declared abstractions.
2. **TCA for all feature state & logic** — every behavioral scene/widget is a `@Reducer` with `@ObservableState`, an `Action` enum, and one `body`. Views are thin (render `store`, send actions); all branching/transformation lives in reducers or Domain. Side effects go through `Effect` (`.run`); reducers stay pure; state is `Equatable`.
3. **Test-First (NON-NEGOTIABLE)** — write the failing test, then the minimum implementation. Reducer/Domain behavior changes must ship with test changes in the same PR; bug fixes start with a failing regression test. Reducers are tested with TCA `TestStore` asserting every mutation and received action.
4. **Dependency Injection via swift-dependencies** — every cross-boundary collaborator is a `struct` of `@Sendable` closures conforming to `DependencyKey`, exposed via a `DependencyValues` computed property, consumed with `@Dependency`. Never construct collaborators directly in reducers/views. Provide `liveValue`; override with mocks in tests/previews. Concurrency-crossing types are `Sendable`.
5. **Declarative Views with Design Tokens** — no inline literals for colors/fonts/spacing/radii/opacity/image names/copy. Define them as named, typed token extensions (`Color`, `Font`, `CGFloat`, `ImageType`, `LocalizedStringKey`) grouped under `// MARK: - Resources` / `Styles`. Every view ships `#Preview`s covering `.light` and `.dark` plus meaningful state variants.

Correct existing typos in new code; do not propagate them. `firstRecrd` has been fixed to `firstRecord` everywhere; `SorcesRepoImp.swift` / `SorcesRepoImpTests.swift` are still misspelled *filenames* (the types inside are `SourcesRepoImpl`) — match those only where already referenced, don't invent new ones.

## Domain model & block pipeline

Implemented by spec 003 (`specs/003-block-pipeline/`); the spec, `data-model.md` and
`contracts/domain-contracts.md` are the detailed reference. Anything not listed there is still
open — raise it rather than guessing.

### Entities (`Domain/Ents/Draws.swift`)

- **Element** — `UInt`, `1…y` of its type.
- **CombinationType** — "x of y": `pick` (x) non-repeating elements from a `pool` (y), `1 ≤ x ≤ y`.
- **Combination** — a CombinationType plus exactly x distinct elements, stored ascending, so
  equality ignores order and `Comparable` compares element by element.
- **SubCombination** — z elements of a combination, `2 ≤ z < x`, keeping only its parent's
  CombinationType (LTA-7): equal sub-combinations from different draws are equal and count together.
- **GameEntry** (index, date, combination), **GameType** (declared by each `SourceModule`),
  **Game** (a GameType plus entries of that one shape).
- Every constructor, and every `Codable` decode, goes through a `throws(DomainError)` init that
  enforces these invariants.

### Pipeline (`Domain/Ents`, `Domain/BLogic`)

- **Values** — three kinds flow between blocks (`BlockValue`): `.draws(Game)`,
  `.counts(CountResult)` (unique item → count ≥ 1; unordered results are stored item-ascending), and
  `.number(Int)`.
- **Blocks** — a `Block` enum with parameters: filters (`dropFirst`/`dropLast`/`prefix`/`suffix`,
  on draws or counts), sorts (by date/index on draws, by count on counts, each with a direction),
  and counts (unique elements, combinations and sub-combinations of size z, and count all, which
  ends a branch). `accepts` and `output(given:)` are the FR-010 attach table.
- **Chains** — a `Chain` is a saved tree of `ChainNode` parent pointers rooted at an implicit
  input, not tied to any source. `revision` grows on every structural or parameter edit (not on a
  rename). The pure rules live in `ChainRules.swift`.
- **Running** — `ChainRunner` evaluates each node once, parents first, off the main actor (inside a
  per-run actor), and streams one `RunEvent` per node. A failed node fails only its subtree.
  `BlockEvaluator` holds the algorithms and the 5,000,000 sub-combination budget.
- **Freshness** — every result carries a `RunStamp`: source id, display name, `SourceDataState`
  (including `LocalStore`'s content digest), and chain revision. `Freshness.swift` always judges a
  result against *its own* source's current state.
- **Persistence** — `ChainsRepo` (contract) → `ChainsRepoImpl` (Data) keeps chains, saved results
  and one draft per chain as JSON under `Application Support/lottoApp2/chains/<id>/`.

## Build & Test

Single scheme `lottoApp2`; targets `lottoApp2`, `lottoApp2Tests`, `lottoApp2UITests` — all three on iOS 18.6 / Swift 6. Note this repo builds against an Xcode 27 Beta toolchain.

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is on for all targets, which is why non-UI types are declared `nonisolated` (and `XCTestCase` subclasses in the UI test target must be, since their overridden members are nonisolated).

```bash
# Build (pick an installed simulator for -destination)
xcodebuild build -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run all unit tests (pick a simulator that exists: `xcrun simctl list devices available`)
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests

# Run a single test (Type/method — swift-testing suites are plain structs)
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests/StartPage_Tests/action_task
```

**Tests use swift-testing (`import Testing`, `@Test`, `#expect`), not XCTest** — despite the constitution's "XCTest" wording, follow the code. Reducer tests are `@MainActor @Test` functions that build a `TestStore` with dependencies overridden via `.dependency(\.blSources, .mock)`. Because `swift-dependencies` guards against unimplemented deps, a reducer test that reaches a dependency must override it or it fails.

Never block a thread in a test (spin-waits, `Thread.sleep`, semaphores): suites run in parallel in one process, and a live `TestStore` switches on TCA's main-serial executor, which moves *all* background task work onto the main thread. A blocking wait then hangs the whole run. Wait with `await Task.yield()` loops, or make the code under test cancel or finish itself.

## Architecture layout

```
lottoApp2/
  App/            @main entry — composes the root Store (StartPage)
  Presentation/   UI layer: <Feature>.swift (the @Reducer) + <Feature>View.swift (thin SwiftUI)
    StartPage/    StartPage reducer + StartPageView; Widgets/ holds child reducers (SourceEntry)
    BlocksPage/   the chain list (saved chains, new, rename, delete)
    ChainEditor/  ChainEditor (outline, run, results, save, leave warning, draft), AddBlock (catalogue sheet),
                  BlockParameters (parameter step / edit sheet), BlockTokens (shared block copy)
    Results/      ResultPage — one block's full output (elements, ranking, grouped combinations, draws, number)
    Previews/     PreviewFixtures.swift — sample data for #Previews (kept out of Domain)
  Domain/         Inner layer — no Data imports
    Ents/         Entities (Source, SourceFailures, Draws, PipelineValues, Block, ProcessingBlockKind, Chain, RunResults)
    Repos/        Repository *contracts* (SourcesRepo, ChainsRepo) as struct-of-closures + DependencyKey
    BLogic/       Business logic (SourcesBLogic, ChainRules, BlockEvaluator, ChainRunner, Freshness,
                  ResultSummary) — depends on repo contracts, not impls
  Data/           Outer layer — implements Domain contracts
    Repos/        SorcesRepoImp (SourcesRepo.live), ChainsRepoImpl, source modules (SourceModule/SourceRegistry)
    Sources/      RemoteSources / LocalStore / NetworkClient / MBNetParser — I/O-facing collaborators
lottoApp2Tests/
  Domain/         pure-rule tests over the hand-computed ReferenceDraws fixture
  Data/           file-backed repo tests in temp directories
  Reducers/       TestStore tests + mocks (SourceBLogicMocks.swift, PipelineMocks.swift)
```

### How the layers wire together (dependency chain)

The data flow for the current feature is a clean example of the pattern to follow:

- **Reducer** (`StartPage`, `SourceEntry`) reads `@Dependency(\.blSources)` and calls it inside `.run` effects. It never sees a repo or a network source. It also reads `@Dependency(\.date)` — sync severity is derived from the injected clock, never from `Date()`/`timeIntervalSinceNow`, so it stays testable.
- **`SourcesBLogic`** (Domain/BLogic) is the injected boundary the UI depends on. Its `liveValue` resolves `@Dependency(\.sourcesRepo)` and delegates.
- **`SourcesRepo`** (Domain/Repos) is a *contract* (struct of closures + `DependencyKey`); `liveValue = SourcesRepoImpl.live` binds it to the Data layer.
- **`SourcesRepoImpl`** (Data/Repos) resolves `@Dependency(\.remoteSourcesManager)`, `@Dependency(\.localStore)` and `@Dependency(\.date)` to do the real work.
- **`SourceModule`** (Data/Repos) owns both a source's identity *and* its `fetchDraws()`, so `SourceRegistry.all` is the only place a source is declared — there is no separate string switch to keep in sync.

So each `struct`-of-closures both **declares a seam** (for DI/testing) and **points one layer inward** for its live implementation. When adding a collaborator, follow this shape: define the closure struct + `DependencyKey` (with `liveValue`) + `DependencyValues` accessor in the layer that *owns the contract*, and put the `.live` implementation in the layer below.

### Reducer composition

Parent reducers hold children as `IdentifiedArrayOf<Child.State>` and forward `IdentifiedActionOf<Child>` actions (see `StartPage.State.sources` / `Action.sources`). Entity → child-state mapping lives in a computed extension (`Source.sourceEntryState`).

### Design tokens

`ImageType` (`.system`/`.asset`) wraps SF Symbols vs. asset images; `Image(_ imageType:)` resolves it. Views pull all visual values from `fileprivate static` token extensions on `Color`/`Font`/`CGFloat`/`Double`/`LocalizedStringKey` at the bottom of the view file. When a value maps by state, use a dictionary keyed by the state enum (e.g. `Color.syncSeverityForeground[severity]`).

## Spec-driven workflow

Non-trivial features go through Spec Kit skills: `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`, with specs under `specs/`. Per the user's global instruction, when running `/speckit-specify`, first `git fetch --prune && git branch -r | grep -E 'spec|[0-9]{3}-'` to pick a non-colliding spec number across machines/branches.

Dependencies are managed via SPM with `Package.resolved` committed. The stack is the Point-Free ecosystem: `swift-composable-architecture`, `swift-dependencies`, `swift-identified-collections`, `swift-navigation`, `swift-clocks`.
