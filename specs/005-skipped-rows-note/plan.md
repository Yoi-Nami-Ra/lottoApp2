# Implementation Plan: Skipped Rows Note

**Branch**: `005-skipped-rows-note` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-skipped-rows-note/spec.md`

## Summary

Today a sync's skipped-row count reaches a log line and nowhere else (spec 001 FR-007), and draws that break
the game rules (for example a repeated number) are stored. This change does four things:

1. **Validates** every parsed draw against its source's `GameType` in the shared fetch step. It reuses the
   Domain `Combination` invariants, drops the draws that fail, and counts them next to the parser's skips (R1).
   A response with rows but no valid draw fails as `.unreadableData` (R2).
2. **Persists** the total count as `SourceMeta.lastSyncSkipped`, written by `LocalStore.save` on the success
   path only, so a failed sync leaves it as it was and a relaunch keeps it (R3).
3. **Lifts** the count into `Source.lastSyncSkipped` and then `SourceEntry.State.skippedInLastSync`, which is
   `nil` when 0 or never synced (R4).
4. **Shows** a warning note row between the card's header and its details. The row is built from tokens, with
   singular/plural copy, an icon plus colour, and wrapping at AX sizes (R5, R6).

## Technical Context

**Language/Version**: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (non-UI types `nonisolated`),
Xcode 27 Beta toolchain.

**Primary Dependencies**: `ComposableArchitecture`, `swift-dependencies`, SwiftUI, `OSLog`. No new package.

**Storage**: `Application Support/lottoApp2/sources/<name>/meta.json` gains an optional-on-read
`lastSyncSkipped` field. `draws.json` is unchanged. Metadata already on disk stays readable (FR-013).

**Testing**: swift-testing + TCA `TestStore`. Repo integration tests use `remoteSourcesManager = .live`, a
stubbed `networkClient` and a temp `fileBacked` store. A new pure-function suite covers
`FetchedDraws.validated(against:)`.

**Target Platform**: iOS 18.6+ (the existing target).

**Project Type**: Mobile app, single target, layered `Presentation` / `Domain` / `Data`.

**Performance Goals**: Validation is O(n · x log x) over about 7,400 draws of 6 numbers, well under a
millisecond next to the network fetch. No UI cost beyond one optional row.

**Constraints**: Reducers stay pure. The note's copy, colours, spacing and icon come from tokens. Stored draws
are never touched by a failed sync. Existing meta files still decode.

**Scale/Scope**: About 7 production files (`RemoteSources`, `mbnetSourceModule`, `SorcesRepoImp`,
`LocalStore`, `Source`, `SourceEntry`, `SourceEntryView`) and about 6 test files (the new validation suite, repo,
local store, digest, SourceEntry and StartPage tests).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Pre | Post |
| --- | --- | --- | --- |
| I. Layered architecture | Game rules stay in the Domain (`Combination.init`). The Data layer calls them, as `gameFor` already does. `Source` gains a plain `Int?`. Presentation sees only `Source`. | ✅ | ✅ |
| II. TCA | The "show note?" decision sits in the `sourceEntryState`/`apply` mapping, which is tested. The view only unwraps an optional. There are no new actions and no new effects. | ✅ | ✅ |
| III. Test-first | Each behaviour gets a failing test first: validation, repo sync (4 skip mixes, all-invalid, failed resync, zero replaces), meta persistence and legacy decode, reducer mapping, and StartPage success/failure. | ✅ | ✅ |
| IV. DI | No new dependency. `LocalStore.save` changes arity, and tests override it as today. `@Dependency(\.date)` still stamps the sync. | ✅ | ✅ |
| V. Tokens & previews | The icon, colours, font, paddings, corners and copy are `fileprivate static` tokens under `// MARK: - Resources`. New previews cover light, dark, and light/dark at AX5 with the note. | ✅ | ✅ |

There are no violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/005-skipped-rows-note/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/domain-contracts.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
lottoApp2/
  Data/
    Sources/RemoteSources.swift        # FetchedDraws.invalid, skippedTotal, validated(against:); sourceFor runs it
    Sources/LocalStore.swift           # SourceMeta.lastSyncSkipped (+ legacy decode); save(…, skipped)
    Repos/mbnetSourceModule.swift      # all-unusable check moves out to validated(against:)
    Repos/SorcesRepoImp.swift          # logs both counts; saves skippedTotal; SourceMeta.source maps it
  Domain/
    Ents/Source.swift                  # Source.lastSyncSkipped: Int?
  Presentation/
    StartPage/Widgets/SourceEntry.swift      # State.skippedInLastSync; mapping in sourceEntryState/apply
    StartPage/Widgets/SourceEntryView.swift  # skipped note row, tokens, previews, mocks
lottoApp2Tests/
  Data/FetchedDrawsValidationTests.swift     # new
  SorcesRepoImpTests.swift                   # sync mixes, all-invalid, failed resync, zero replaces
  LocalStoreTests.swift                      # persistence across reload, legacy decode, save arity
  Data/LocalStoreDigestTests.swift           # save arity only
  Reducers/SourceEntryTests.swift            # mapping nil/0/1/n; apply
  Reducers/StartPageTests.swift              # success updates note, failure keeps it
```

**Structure Decision**: Use the existing single-target layout. No new directories other than one new test
file under `lottoApp2Tests/Data/`.

## Complexity Tracking

No entries.
