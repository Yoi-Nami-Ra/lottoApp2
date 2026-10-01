# Implementation Plan: Fetch Button on Never-Synced Sources

**Branch**: `008-fetch-never-synced` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/008-fetch-never-synced/spec.md`

## Summary

A source card's sync button offers **Fetch** while the source has never synced successfully, and **Refresh** once it has (LTA-3). `SourceEntry.State` gets a `syncAction` (`.fetch` / `.refresh`). It is derived from `lastSync`, so it can never go stale and it flips to `.refresh` the moment `apply(_:now:)` records the first successful sync. Both card views read it for their label, idle icon, spoken name and in-progress label. While a sync runs the icon is still the spinning sync arrows. The general-purpose failure alert takes the action too, so a failed first fetch says "Couldn't fetch …". The sync path (`refreshButtonTapped` → delegate → `blSources.fetchFrom`) is unchanged. See [research.md](research.md) for the decisions.

## Technical Context

**Language/Version**: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, Xcode 27 toolchain

**Primary Dependencies**: swift-composable-architecture, swift-dependencies (no new ones)

**Storage**: N/A. The action is derived from the stored `lastSync`; nothing new is persisted.

**Testing**: swift-testing (`@Test`, `#expect`), TCA `TestStore` for `SourceEntry` and `StartPage`

**Target Platform**: iOS 18.6 (iPhone and iPad), plus the macOS test destination

**Project Type**: mobile app (single Xcode project)

**Performance Goals**: N/A (a derived enum read per render)

**Constraints**: Constitution v1.0.2 principles I–V. The one-line label and the large-text reflow rules from spec 007 must hold for "Fetch" / "Fetching…".

**Scale/Scope**: 2 card views, 1 reducer state type, 1 alert builder, 1 parent call site; about 6 new copy and icon tokens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How |
| --- | --- | --- |
| I. Layered architecture | ✅ | Presentation only. The action is derived from `SourceEntry.State.lastSync`, which already comes from the Domain `Source`. Domain and Data are untouched. |
| II. TCA | ✅ | The Fetch-or-Refresh choice lives in `SourceEntry.State` (the reducer layer), not in the views. Views only read `store.syncAction`. No new actions or effects. |
| III. Test-first | ✅ | Failing tests first: state mapping (`sourceEntryState`, `apply`), the `StartPage` success and failure paths (the flip to `.refresh`, staying `.fetch` on failure), and the alert wording by action. |
| IV. DI | ✅ | No new collaborators. Tests reuse the existing `blSources` and `date` overrides. |
| V. Design tokens | ✅ | New `LocalizedStringKey` / `LocalizedStringResource` copy and an `ImageType` fetch glyph, all as `fileprivate static` tokens. The views pick values through dictionaries keyed by `SyncAction`, following the existing `syncSeverity` pattern. Light/dark previews for never-synced cards, idle and fetching. |

No violations; Complexity Tracking is empty.

**Post-design re-check**: ✅ unchanged. The design adds one enum and one computed property on the state, plus token dictionaries.

## Project Structure

### Documentation (this feature)

```text
specs/008-fetch-never-synced/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/ui-contracts.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
lottoApp2/Presentation/StartPage/
├── StartPage.swift                      # pass the entry's syncAction into .syncFailed(...)
└── Widgets/
    ├── SourceEntry.swift                # SyncAction enum + State.syncAction; syncFailed(_:sourceName:action:)
    ├── SourceCardParts.swift            # SyncIcon (fetch glyph idle / spinning arrows while syncing), tokens
    ├── SourceEntryView.swift            # label + in-progress label by action; never-synced previews
    └── CompactSourceEntryView.swift     # idle icon + VoiceOver labels by action; never-synced previews
lottoApp2Tests/Reducers/
├── SourceEntryTests.swift               # syncAction mapping, apply() flip, alert wording by action
└── StartPageTests.swift                 # first fetch success → .refresh; first fetch failure → stays .fetch + fetch wording
```

**Structure Decision**: the existing Presentation/StartPage feature folder. No new files except the spec docs.

## Complexity Tracking

None.
