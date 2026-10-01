# Implementation Plan: Missing Records Estimate

**Branch**: `009-missing-records-estimate` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-missing-records-estimate/spec.md`

## Summary

Today a source's severity colour depends only on how long ago the app synced. LTA-4 makes it depend on how
many draws are probably missing. The work has five parts:

1. **A Domain rule.** `DrawCadence.measure` counts the draws in the two full UTC Monday-first weeks before the
   latest draw's week, or returns `nil` when there isn't enough history. `missing(since:now:)` is the
   ⌊count × elapsed / 14 days⌋ estimate. Storing the integer count avoids floating-point boundary errors
   (R1–R3).
2. **Persistence at sync.** `SourceMeta.drawsInWindow` is written by `LocalStore.meta(…)` from the merged set,
   and lifted to `Source.cadence`. Listing stays a metadata-only read, and older metadata decodes as `nil`
   (R4).
3. **The severity rule.** `SourceEntry` maps `Source` into `missingEstimate` plus severity, using the estimate
   when there is one and the unchanged day-based rule when there isn't, both from the injected clock (R5).
4. **The card line.** The shared `RecordDateDetail` shows "~N missing" under Latest Record on both cards, with
   an icon and a spoken "about N missing" (R6).
5. **Tests first** for every rule above (R7).

## Technical Context

**Language/Version**: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (non-UI types are `nonisolated`),
Xcode 27 Beta toolchain.

**Primary Dependencies**: `ComposableArchitecture`, `swift-dependencies`, SwiftUI, Foundation `Calendar`. No new
package.

**Storage**: `Application Support/lottoApp2/sources/<name>/meta.json` gains an optional `drawsInWindow`. Older
files still decode. `draws.json` is unchanged.

**Testing**: swift-testing plus TCA `TestStore`. There is a new pure Domain suite, `DrawCadenceTests`, built on
fixed UTC dates.

**Target Platform**: iOS 18.6+ (iPhone, iPad, and Mac through "Designed for iPad").

**Project Type**: Mobile app, single target, layered into `Presentation` / `Domain` / `Data`.

**Performance Goals**: `measure` is O(n) over about 7,400 dates and runs once per successful save. Listing
cost is unchanged (SC-004).

**Constraints**: Reducers stay pure, and `now` comes only from `@Dependency(\.date)`. The calendar is fixed
(UTC, Monday first) and passed in as a parameter. All copy, colours, icons and spacing are tokens.

**Scale/Scope**: About 8 production files:
- new: `DrawCadence.swift`;
- Domain: `Source`;
- Data: `LocalStore`, `SorcesRepoImp`;
- Presentation: `SourceEntry`, `SourceCardParts`, `SourceEntryView`, `CompactSourceEntryView`, and
  `PreviewFixtures`.

About 4 test files: the new `DrawCadenceTests`, plus `LocalStoreTests`, `SourceEntryTests` and
`StartPageTests`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Pre | Post |
| --- | --- | --- | --- |
| I. Layered architecture | The cadence rule and the estimate live in the Domain. Data calls `measure` when writing metadata, and Presentation calls `missing` when mapping. Both point inward. `Source` carries a Domain value type. | ✅ | ✅ |
| II. TCA | Severity and the estimate are worked out in the reducer's mapping (`sourceEntryState`/`apply`). The views only render `missingEstimate`. There are no new actions or effects. | ✅ | ✅ |
| III. Test-first | Failing tests come first for the Domain rule (window, edges, estimate), persistence (write, reload, legacy), the reducer mapping (severity table, fallback), and the StartPage refresh. | ✅ | ✅ |
| IV. DI | `now` comes from `@Dependency(\.date)` as before. The calendar is a parameter of a pure function, set to a fixed `Calendar.drawWeeks` constant. No new dependency. | ✅ | ✅ |
| V. Tokens & previews | The copy ("~N missing", "about N missing"), the icon, the font and the spacing are `fileprivate static` tokens. Light/dark previews cover each severity with and without an estimate, plus AX5. | ✅ | ✅ |

There are no violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/009-missing-records-estimate/
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
  Domain/
    BLogic/DrawCadence.swift              # new: DrawCadence, measure, missing, Calendar.drawWeeks
    Ents/Source.swift                     # Source.cadence: DrawCadence?
  Data/
    Sources/LocalStore.swift              # SourceMeta.drawsInWindow (+ legacy decode); meta(…) measures
    Repos/SorcesRepoImp.swift             # SourceMeta.source maps it to Source.cadence
  Presentation/
    StartPage/Widgets/SourceEntry.swift          # State.missingEstimate; severity from the estimate or fallback
    StartPage/Widgets/SourceCardParts.swift      # RecordDateDetail gains the "~N missing" line
    StartPage/Widgets/SourceEntryView.swift      # passes missingEstimate; previews
    StartPage/Widgets/CompactSourceEntryView.swift  # passes missingEstimate; previews
    Previews/PreviewFixtures.swift               # sample sources with a cadence
lottoApp2Tests/
  Domain/DrawCadenceTests.swift           # new
  LocalStoreTests.swift                   # writes, survives reload, legacy decode
  Reducers/SourceEntryTests.swift         # severity table, fallback, mapping, apply
  Reducers/StartPageTests.swift           # refresh recomputes
```

**Structure Decision**: Use the existing single-target layout, with one new Domain file and one new test file.

## Complexity Tracking

No entries.
