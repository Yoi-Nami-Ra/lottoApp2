<!--
Sync Impact Report
==================
Version change: 1.0.0 → 1.0.1
Bump rationale: PATCH — reconcile the Technology & Platform Constraints "Testing" line from "XCTest"
to "swift-testing" to match the codebase's actual test runner and CLAUDE.md guidance. No principle
added, removed, or redefined; the Principle III MUST (test behavior via TCA TestStore) is unchanged and
runner-agnostic. Resolves finding C1 from /speckit-analyze on 001-mbnet-source.

--- Prior entry ---
Version change: (unratified template) → 1.0.0
Bump rationale: Initial ratification. The file previously contained only unfilled
placeholder tokens; this is the first concrete, adopted version → MAJOR baseline 1.0.0.

Modified principles: none (initial definition)
Added principles:
  - I. Layered Clean Architecture (Dependencies Point Inward)
  - II. TCA for All Feature State & Logic
  - III. Test-First (NON-NEGOTIABLE)
  - IV. Dependency Injection via swift-dependencies
  - V. Declarative Views with Design Tokens
Added sections:
  - Technology & Platform Constraints
  - Development Workflow
  - Governance

Templates requiring updates:
  - ✅ .specify/templates/plan-template.md — "Constitution Check" gate is derived from
       this file at plan time; no hardcoded gates to change.
  - ✅ .specify/templates/tasks-template.md — "Tests" note updated to defer to the
       constitution's Test-First principle for this project.
  - ✅ .specify/templates/spec-template.md — no constitution-driven mandatory sections
       added/removed; no change required.
  - ✅ Spec Kit command skills (.claude/skills/speckit-*) — reviewed; use generic
       guidance, no outdated agent-specific references introduced.

Follow-up TODOs: none.
-->

# lottoApp2 Constitution

## Core Principles

### I. Layered Clean Architecture (Dependencies Point Inward)

The codebase is organized into three layers with a strict, one-directional dependency rule:
**Scenes (UI) → Domain (BLogic, Repos, Ents) → Data (Repos impl, Sources)**.

- Source dependencies MUST point inward only. Domain code MUST NOT import or reference
  concrete Data-layer types; the UI (Scenes) MUST NOT reach past the Domain layer into
  Data implementations.
- The Domain layer owns the contracts (entities and repository/business-logic interfaces).
  The Data layer provides implementations; the Scenes layer consumes Domain interfaces.
- Cross-layer collaboration happens exclusively through abstractions declared in the
  inner layer (see Principle IV), never through direct construction of an outer layer's
  concrete types.

Rationale: A one-directional dependency graph keeps business rules independent of
frameworks, storage, and UI, so each layer can evolve, be replaced, and be tested in
isolation. This is the property the current folder structure already encodes and MUST
be preserved.

### II. TCA for All Feature State & Logic

All feature state, actions, and side effects MUST be modeled with The Composable
Architecture (TCA).

- Every scene/widget with behavior is a `@Reducer` with `@ObservableState`, an `Action`
  enum, and a single `body`. Composition uses `Scope`, `IdentifiedActionOf`, and
  `IdentifiedArrayOf` rather than ad-hoc parent/child wiring.
- Views MUST be thin: they render `store` state and send actions. Business decisions,
  branching, and data transformation belong in reducers or the Domain layer, never in
  `View` bodies.
- Side effects MUST run through TCA `Effect`s (`.run`, etc.); reducers MUST remain pure
  and synchronous outside of returned effects. State MUST be `Equatable`.

Rationale: A single, uniform state-management pattern makes every feature testable via
`TestStore`, keeps effects explicit, and eliminates hidden mutable state.

### III. Test-First (NON-NEGOTIABLE)

Test-Driven Development is mandatory for reducers and Domain business logic.

- The cycle is strict: write the test → confirm it fails (Red) → implement the minimum
  to pass (Green) → refactor. Implementation code for a reducer or business-logic unit
  MUST NOT be merged ahead of a test that exercises it.
- Reducers MUST be tested with TCA `TestStore`, asserting every state mutation and every
  emitted action. Dependencies MUST be overridden with test values (Principle IV) so
  tests are deterministic and hermetic — no real network or disk access.
- A change to a reducer's or Domain unit's observable behavior MUST be accompanied by a
  test change in the same commit/PR. Bug fixes MUST start with a failing regression test.

Rationale: TCA's design makes exhaustive, fast unit testing cheap; requiring tests first
guarantees that behavior is specified, regressions are caught, and refactors stay safe.

### IV. Dependency Injection via swift-dependencies

Every cross-boundary collaborator (business logic, repositories, remote sources, local
store, clocks, etc.) MUST be provided through `swift-dependencies`.

- Dependencies are modeled as `struct`s of `@Sendable` closures conforming to
  `DependencyKey`, exposed via a `DependencyValues` computed property, and consumed with
  `@Dependency`. Concrete collaborators MUST NOT be constructed directly inside reducers,
  views, or other dependencies.
- Each dependency MUST supply a `liveValue`. Test and preview values MUST be provided (or
  overridden at the call site) wherever the live value performs I/O, so tests and
  `#Preview`s never touch real infrastructure.
- Types crossing concurrency boundaries MUST be `Sendable`.

Rationale: Struct-of-closures DI is what makes Principles I–III enforceable in practice —
it is the seam that lets the UI depend on Domain abstractions and lets tests substitute
deterministic behavior.

### V. Declarative Views with Design Tokens

SwiftUI views MUST be declarative and free of hard-coded design values.

- Colors, fonts, spacing, corner radii, opacities, image names, and copy MUST be defined
  as named, typed token extensions (e.g. `Color`, `Font`, `CGFloat`, `ImageType`,
  `LocalizedStringKey`) rather than inline literals scattered through the view body.
- Every view MUST provide `#Preview`s covering both `.light` and `.dark` color schemes,
  and the meaningful state variants it can render (e.g. empty / populated, each severity).
- View files SHOULD keep tokens and styles grouped in clearly marked sections
  (`// MARK: - Resources` / `Styles`).

Rationale: Centralized tokens keep the UI visually consistent, make theming and
light/dark support reliable, and turn previews into a lightweight, always-on visual
test surface.

## Technology & Platform Constraints

- **Language/UI**: Swift with SwiftUI. Target platform is Apple (iOS) via the
  `lottoApp2.xcodeproj` Xcode project.
- **Architecture stack**: The Composable Architecture (`ComposableArchitecture`) and
  `swift-dependencies` (`Dependencies`) are the mandated state-management and DI
  frameworks. Introducing an alternative state-management or DI framework requires a
  constitution amendment.
- **Testing**: swift-testing (`import Testing`, `@Test`, `#expect`) with TCA's `TestStore`. Tests live
  under `lottoApp2Tests/`. (The test *runner* is swift-testing; the reducer-testing MUST in Principle III —
  exercising behavior through `TestStore` — is independent of the runner and still binding.)
- **Package management**: Dependencies are managed through Swift Package Manager; the
  resolved graph (`Package.resolved`) is committed.
- **Specification-driven delivery**: Non-trivial features are developed through the Spec
  Kit workflow (`/speckit-specify` → `/speckit-plan` → `/speckit-tasks` →
  `/speckit-implement`), with feature specs stored under `specs/`.

## Development Workflow

- **Layered order of work**: Features are built inner-to-outer where practical — Domain
  entities and contracts, then reducers (with tests), then Data implementations (with
  tests), then Views. Mock/stub implementations of outer layers are acceptable
  intermediate steps and MUST be tracked as such.
- **Definition of done for a behavioral unit**: reducer/Domain code + `TestStore`/unit
  tests passing + dependencies injected (no direct construction) + views (if any) using
  design tokens with light/dark previews.
- **Review gate**: Every change MUST be reviewed against these principles before merge.
  A reviewer MUST reject changes that violate layering, bypass DI, ship untested
  reducer/Domain behavior, or inline design literals, unless the deviation is recorded
  and justified per Governance.
- **Naming**: New identifiers MUST be spelled correctly and descriptively; do not
  propagate existing typos into new code.

## Governance

- This constitution supersedes other conventions and ad-hoc practices for this project.
  Where guidance conflicts, the constitution wins.
- **Amendments**: Changes to this document require a PR that states the motivation, the
  affected principles, and a version bump per the policy below. Merging the amendment
  requires the same review as production code.
- **Versioning policy** (semantic):
  - **MAJOR**: Backward-incompatible governance changes — removing or redefining a
    principle, or changing a mandated framework/architecture.
  - **MINOR**: Adding a new principle/section or materially expanding existing guidance.
  - **PATCH**: Clarifications, wording, and non-semantic refinements.
- **Compliance**: All PRs and reviews MUST verify compliance with these principles.
  Any justified deviation MUST be documented in the plan's Complexity Tracking table
  (or the PR description) with the reason and the simpler alternative that was rejected.
  Unjustified complexity MUST be removed.

**Version**: 1.0.1 | **Ratified**: 2026-07-27 | **Last Amended**: 2026-07-30
