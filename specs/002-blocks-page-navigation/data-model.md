# Phase 1 Data Model: Source Selection, Bottom Action Bar & Processing Blocks Page

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

This feature adds no persisted data and no network payloads. "Data model" here means **reducer state**: the
shapes, the invariants that must hold over them, and the transitions between them. One Domain entity is
added.

---

## 1. Domain

### `ProcessingBlockKind` (new — `lottoApp2/Domain/Ents/ProcessingBlockKind.swift`)

| Field | Type | Notes |
|-------|------|-------|
| _(case)_ `countUniqueElements` | — | The only case at this stage (FR-026) |

- Declared `nonisolated enum ProcessingBlockKind: String, CaseIterable, Equatable, Sendable`.
- `rawValue` is the stable identity; `allCases` is the catalogue (FR-025).
- **Carries no display copy.** The label is a Presentation-layer `LocalizedStringKey` token (Principle V,
  research R5).
- **Not** a pipeline type: it says nothing about what a block consumes or produces. The block I/O design is
  marked TBD in CLAUDE.md and stays out of this feature.

### `Source` (existing — unchanged)

Referenced only for what the new code reads from it: `name` (the id used by `SourceEntry.State.id`) and
`displayName` (what the header names, FR-024). No field is added.

---

## 2. Presentation state

### `SourceEntry.State` (modified)

| Field | Type | Change | Requirement |
|-------|------|--------|-------------|
| `isSelected` | `Bool` (default `false`) | **new** | FR-015 — lets the card draw its border + checkmark |

Every other field is unchanged. `isSelected` is a **mirror**, never the source of truth: it is written only
by `StartPage.State.applySelectionRules()` (research R2). Nothing inside `SourceEntry` mutates it.

### `StartPage.State` (modified)

| Field | Type | Change | Requirement |
|-------|------|--------|-------------|
| `sources` | `IdentifiedArrayOf<SourceEntry.State>` | unchanged | — |
| `selectedSourceID` | `SourceEntry.State.ID?` (default `nil`) | **new** | FR-007, FR-008 — canonical choice; `nil` means none |
| `hasLoaded` | `Bool` (default `false`) | **new** | FR-005, FR-006 — `false` until the first `sourcesResponse` |
| `blocks` | `@Presents BlocksPage.State?` | **new** | FR-022 — non-`nil` while the blocks page is pushed |

Derived, not stored:

| Derived value | Definition | Requirement |
|---------------|------------|-------------|
| `isNextEnabled` | `selectedSourceID != nil` | FR-020 |
| list presentation | `!hasLoaded` → loading; `hasLoaded && sources.isEmpty` → no-sources message; else → list | FR-005, FR-006 |

### `BlocksPage.State` (new)

| Field | Type | Notes | Requirement |
|-------|------|-------|-------------|
| `sourceID` | `String` | The chosen source's id; carried for the steps that follow, not displayed | FR-022 |
| `sourceName` | `String` | The chosen source's `displayName`, shown in the header | FR-024 |
| `blocks` | `[ProcessingBlockKind]` (default `ProcessingBlockKind.allCases`) | The catalogue as presented | FR-025, FR-026 |

`Equatable`; holds no other state at this stage (spec, Key Entities).

---

## 3. Invariants

| # | Invariant | Enforced by | Requirement |
|---|-----------|-------------|-------------|
| I1 | At most one source is chosen | `selectedSourceID` is a single optional — two selections are unrepresentable | FR-007 |
| I2 | `selectedSourceID` always refers to a source present in `sources`, or is `nil` | `applySelectionRules()` clears it when the id is absent | FR-008, FR-016 |
| I3 | `sources[id].isSelected == (id == selectedSourceID)` for every entry | `applySelectionRules()` rewrites every entry's mirror after any change | FR-015 |
| I4 | With exactly one source, `selectedSourceID` is that source | `applySelectionRules()` | FR-009 |
| I5 | With two or more sources and no prior valid choice, `selectedSourceID == nil` | `applySelectionRules()` — it never picks on the person's behalf | FR-010 |
| I6 | Choosability never depends on a source's records or sync state | no rule reads `recordsCount` / `lastSync` / `lastSyncSeverity` | FR-019 |
| I7 | `hasLoaded` is monotonic — once `true`, never `false` again | only ever set to `true`, in `sourcesResponse` | FR-006, FR-030 |
| I8 | Choosing never touches sync state | selection paths write only `selectedSourceID` / `isSelected` | FR-017 |

**I2–I5 are one function.** `applySelectionRules()` is called from every path that changes `sources` or
`selectedSourceID`, and is the only writer of `isSelected`. Its whole contract:

```text
if selectedSourceID is not an id present in sources → selectedSourceID = nil
if sources.count == 1                               → selectedSourceID = the sole id
for each entry                                      → entry.isSelected = (entry.id == selectedSourceID)
```

Note the ordering: dropping a stale id *before* the single-source rule is what makes the "list shrinks to
one source" edge case select the survivor rather than leaving a dangling id (research R8).

---

## 4. Transitions

### Selection

| From | Event | To |
|------|-------|----|
| any | `sourcesResponse(sources)` | `sources` rebuilt (existing merge of `isRefreshing`/`alert` preserved), `hasLoaded = true`, then `applySelectionRules()` |
| `selectedSourceID == nil` | card tapped (id X) | `selectedSourceID = X`, mirrors updated |
| `selectedSourceID == X` | card tapped (id X) | unchanged — stays chosen (FR-013) |
| `selectedSourceID == X` | card tapped (id Y) | `selectedSourceID = Y`, X's mirror cleared (FR-014) |
| `selectedSourceID == X` | X refreshed (success or failure) | `selectedSourceID` unchanged (FR-017, I8) |
| `selectedSourceID == X` | reload where X is absent | `selectedSourceID = nil`, **Next** becomes unavailable (FR-016) |
| `selectedSourceID == X` | reload where X is present | `selectedSourceID = X` (FR-029) |
| any | app relaunch | state is constructed fresh — `selectedSourceID = nil`, `hasLoaded = false` (FR-018) |

### Screen presentation

| `hasLoaded` | `sources` | Shown | Requirement |
|-------------|-----------|-------|-------------|
| `false` | any | Loading indication; **no** no-sources message | FR-006 |
| `true` | empty | No-sources message | FR-005 |
| `true` | non-empty | The list | — |

The bottom bar and **Next** are present in all three (FR-003), with **Next** unavailable in the first two
because `selectedSourceID` is necessarily `nil` there.

### Navigation

| From | Event | To |
|------|-------|----|
| `blocks == nil`, `selectedSourceID == X` | **Next** tapped | `blocks = BlocksPage.State(sourceID: X, sourceName: <X's name>)` |
| `blocks == nil`, `selectedSourceID == nil` | **Next** tapped | no-op — the button is disabled, and the reducer also guards (FR-021) |
| `blocks != nil` | **Next** tapped again (double tap) | assignment replaces the same optional — still one destination (FR-023, research R1) |
| `blocks != nil` | back / dismiss | `blocks = nil`; `StartPage.State` is untouched, so the choice and `hasLoaded` survive (FR-029, FR-030) |

---

## 5. What this feature does **not** add

- No persistence of any kind (FR-018) — no `LocalStore` key, no `UserDefaults`, no new Data-layer type.
- No new `DependencyKey`: nothing new needs injecting (research R5).
- No change to `Source`, `SourcesBLogic`, `SourcesRepo`, or anything under `Data/`.
- No block execution, parameters, ordering, or composition — and no definition of what flows between
  blocks (Out of Scope; CLAUDE.md marks those TBD).
