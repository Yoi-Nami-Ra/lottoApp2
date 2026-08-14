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

## Domain model & block pipeline (target design)

This section is the target conceptual model the Domain layer is growing toward. It is
documentation, not yet fully implemented; items marked **TBD** are open design questions
that are *not* to be resolved by guessing — raise them before committing to a shape.

### Entities

- **Element** — a single drawable value. Modeled as `UInt` for now (may become a richer
  type later).
- **CombinationType** — an "**x of y**" rule: a combination of `x` non-repeating elements
  drawn from a pool of `y` elements, with `x <= y`. (`x` = pick count, `y` = pool size.)
- **Combination** — a concrete draw: a **CombinationType** plus a list of exactly `x`
  non-repeating **Element**s.
- **SubCombination** — a combination of `z` elements where `z < x`, *derived from* a
  Combination. **TBD:** whether a SubCombination references the **GameEntry**, the
  **CombinationType** it was produced from, or **both** — leave undecided until specified.
- **GameEntry** — one row of a game's history: an **index**, a **date**, and a
  **Combination**.
- **Game** — what a **Source** produces: a list of **GameEntry**s, described by a
  **GameType**.
- **GameType** — describes a Game; **mainly** carries the **CombinationType**. Many Games
  can share the same GameType.

Ownership arrows: `Source → Game`, `Game → GameType`, `Game → [GameEntry]`,
`GameType → CombinationType`, `GameEntry → Combination`, `Combination → CombinationType + [Element]`.

### Blocks (typed pipeline)

The app is composed of **blocks**. Each block takes an **input of a given type** and
produces an **output of the same or another type**; blocks compose into a pipeline.

- **Source** — a *special* block with **no input** that produces a **Game**. (The existing
  `Source`/`SourcesRepo`/`SourceModule` machinery is the current head of this pipeline.)
- **Filter blocks** — `dropLast(x)`, `dropFirst(x)`, `prefix(x)`, `suffix(x)`.
  (User wrote "sufix"; correct spelling is **suffix** per the typo rule above.)
- **Sorting blocks** — sort by **date**, sort by **index**, sort by **count**.
- **Count blocks**:
  - **count all elements** — total element count across the processed list.
  - **count unique elements** — produces a list of **UniqueCount**, each holding a unique
    element and its number of occurrences in the processed list.

**TBD / to specify before implementing:** the concrete I/O *types* that flow between blocks
(e.g. what "sort by count" sorts, what a filter operates over — `[GameEntry]` vs `[Element]`
vs `[UniqueCount]`), and how block chains are represented/executed. Do not invent these; they
need a spec.

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

## Architecture layout

```
lottoApp2/
  App/            @main entry — composes the root Store (StartPage)
  Presentation/   UI layer: <Feature>.swift (the @Reducer) + <Feature>View.swift (thin SwiftUI)
    StartPage/    StartPage reducer + StartPageView; Widgets/ holds child reducers (SourceEntry)
    Previews/     PreviewFixtures.swift — sample data for #Previews (kept out of Domain)
  Domain/         Inner layer — no Data imports
    Ents/         Entities (Source)
    Repos/        Repository *contracts* (SourcesRepo) as struct-of-closures + DependencyKey
    BLogic/       Business logic (SourcesBLogic) — depends on repo contracts, not impls
  Data/           Outer layer — implements Domain contracts
    Repos/        SorcesRepoImp (SourcesRepo.live), source modules (SourceModule/SourceRegistry)
    Sources/      RemoteSources / LocalStore / NetworkClient / MBNetParser — I/O-facing collaborators
lottoApp2Tests/Reducers/   TestStore tests + mocks (SourceBLogicMocks.swift)
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
