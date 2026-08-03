# Implementation Plan: Real MBNet Server Source

**Branch**: `001-mbnet-source` | **Date**: 2026-07-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-mbnet-source/spec.md`

## Summary

Turn the stubbed MBNet source into a real one: statically register "MBNet Server", fetch its full draw
history from `http://www.mbnet.com.pl/dl.txt`, parse every record (ordinal index + date + six numbers),
persist draws and source metadata locally, and reflect the refreshed analytics live on the existing source
card. Refresh is user-initiated from the card's "Refresh" button (idle ↔ "Refreshing…" with a rotating
icon), a failed refresh raises an alert and leaves prior data intact, and re-syncs merge additively keyed on
the ordinal index. Individual draw numbers are stored but not displayed in this change.

Technical approach: keep the existing inward dependency chain (`SourceEntry` reducer → `blSources` →
`sourcesRepo` → `remoteSourcesManager` + `localStore`). Implement the three currently-stubbed Data-layer
seams (`RemoteSourcesManagerImp.live`, `RemoteSource.fetchData`, `LocalStore.liveValue`), add a small
injectable `NetworkClient` dependency for the HTTP GET, extract a **pure MBNet parser** (unit-tested
first), and persist via `Codable` JSON files behind `LocalStore`. Add alert + refresh-guard state to
`SourceEntry` and tokenize its refresh button per Principle V.

## Technical Context

**Language/Version**: Swift (strict concurrency; `nonisolated` structs used throughout), building against the
Xcode 27 Beta toolchain.

**Primary Dependencies**: `ComposableArchitecture`, `swift-dependencies`, `swift-navigation` (AlertState /
PresentationAction), `swift-identified-collections`, `swift-clocks`. No new SPM dependency is introduced.
`Foundation.URLSession` (system) for HTTP; `Foundation` `Codable`/`FileManager` (system) for persistence.

**Storage**: Local `Codable` JSON files behind the `LocalStore` dependency (one file for draws, one for
source metadata, per source). See [research.md](./research.md) → *Persistence*.

**Testing**: swift-testing (`import Testing`, `@Test`, `#expect`) + TCA `TestStore`. Constitution v1.0.1's
Technology & Platform Constraints name swift-testing as the runner, so this is fully aligned (no deviation).

**Target Platform**: iOS (Apple), SwiftUI app via `lottoApp2.xcodeproj`.

**Project Type**: Mobile app (single iOS target, layered Scenes/Domain/Data).

**Performance Goals**: Parse + persist the full history (~7,400 records) in ≤1s on a typical device
(SC-006); UI stays at 60fps; end-to-end sync time additionally network-bound (best-effort).

**Constraints**: MBNet endpoint is plain **HTTP** → requires an App Transport Security exception for
`www.mbnet.com.pl` (SC/Assumptions). Unit tests MUST NOT touch real network or disk (Principle III/IV) →
`NetworkClient` and `LocalStore` overridden with test values. Network request timeout: **15s**
(see research.md → *Network timeout*).

**Scale/Scope**: 1 real source (MBNet) in this feature; ~7,400 draws today, growing ~2–3/week; ~256 KB
download re-served in full each fetch.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment | Status |
|-----------|------------|--------|
| I. Layered Clean Architecture | Dependency chain stays inward: reducer → `blSources` (Domain) → `sourcesRepo` (Domain contract) → `remoteSourcesManager`/`localStore` (Data). Draw parsing/persistence live entirely in Data; no new Domain→Data reference; Scenes never see draws or the network. | ✅ Pass |
| II. TCA for state & logic | `SourceEntry`/`StartPage` remain `@Reducer`s. New alert is `AlertState` + `PresentationAction`; refresh guard is a pure state check; all I/O via `.run` effects; state stays `Equatable`. Views stay thin. | ✅ Pass |
| III. Test-First (NON-NEGOTIABLE) | Red→Green for: the pure MBNet parser (well/partial/empty/malformed), `SourceEntry` (refresh success updates analytics, failure raises alert + keeps prior data, re-tap while refreshing is ignored), and `SourcesBLogic`/repo error mapping. Live network/disk code is validated via quickstart integration, not unit tests. | ✅ Pass |
| IV. DI via swift-dependencies | New `NetworkClient` is a struct-of-`@Sendable`-closures `DependencyKey` with `liveValue` (URLSession) + test override. `LocalStore`/`RemoteSourcesManager` keep their existing dependency shape; no collaborator constructed directly in reducers/views/repos. All concurrency-crossing types `Sendable`. | ✅ Pass |
| V. Declarative Views with Design Tokens | The refresh button's current inline literals (`"Refresh"`, `.blue`, `12`, `6`, radii) are moved to typed token extensions; label copy becomes `LocalizedStringKey` (`.refresh` / `.refreshing`); previews cover light/dark × {idle, refreshing, never-synced, error-alert}. | ✅ Pass |

**Deviations**: None. (An earlier draft flagged swift-testing vs the constitution's "XCTest" wording;
constitution v1.0.1 reconciled the Testing constraint to swift-testing, so no deviation remains.)

**Gate result**: PASS (no violations). Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-mbnet-source/
├── plan.md              # This file
├── research.md          # Phase 0 output — resolved decisions
├── data-model.md        # Phase 1 output — entities, persistence schema
├── quickstart.md        # Phase 1 output — end-to-end validation guide
├── contracts/           # Phase 1 output — MBNet file format + DI seam signatures
│   ├── mbnet-file-format.md
│   └── dependencies.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (from /speckit-specify)
└── tasks.md             # /speckit-tasks output (NOT created here)
```

### Source Code (repository root)

```text
lottoApp2/
├── App/
│   └── lottoApp2App.swift                         # unchanged (composes StartPage)
├── Scenes/StartPage/
│   ├── StartPage.swift                            # unchanged reducer (already forwards SourceEntry)
│   └── Widgets/
│       ├── SourceEntry.swift                      # + alert state, + refresh guard (FR-019/020/021)
│       └── SourceEntryView.swift                  # + "Refreshing…" label, tokens, .alert, previews (FR-018/019, Principle V)
├── Domain/
│   ├── Ents/Source.swift                          # unchanged
│   ├── Repos/SourcesRepo.swift                    # unchanged contract
│   └── BLogic/SourcesBLogic.swift                 # unchanged (delegates); error mapping reviewed
└── Data/
    ├── Repos/
    │   ├── SorcesRepoImp.swift                     # fix latest/oldest usage; wire real manager+store
    │   └── mbnetSourceModule.swift                 # static registry; fix "MBNet" → "MBNet Server"
    └── Sources/
        ├── RemoteSources.swift                     # DrawDTO extended (index/date/numbers, Codable, real latest/oldest);
        │                                           #   RemoteSource carries a fetch closure; RemoteSourcesManagerImp.live real
        ├── MBNetParser.swift                       # NEW — pure parser (unit-tested first)
        ├── NetworkClient.swift                     # NEW — injectable HTTP GET dependency (15s timeout)
        └── LocalStore.swift                        # real Codable-file persistence (draws + source meta, additive union)

lottoApp2Tests/
├── Reducers/
│   ├── SourceEntryTests.swift                     # + failure→alert, refresh-guard, success-updates-analytics
│   └── SourceBLogicMocks.swift                    # extend mocks (failure case)
├── MBNetParserTests.swift                          # NEW — parser unit tests (Red first)
└── LocalStoreTests.swift                           # NEW — additive-union merge unit tests (temp-dir FileManager)

lottoApp2 (project config):
└── Info.plist / build settings                     # NSAppTransportSecurity exception for www.mbnet.com.pl
```

**Structure Decision**: Single existing iOS target with the established Scenes/Domain/Data split. This feature
adds no module; it fills the three stubbed Data seams, adds two small Data files (`MBNetParser`,
`NetworkClient`), and augments the `SourceEntry` reducer/view. All new cross-boundary collaborators are
swift-dependencies seams so they are overridable in tests and previews.

## Complexity Tracking

No constitution violations to justify — the Constitution Check gate passes cleanly (the prior swift-testing
item was resolved by constitution v1.0.1, not carried as a deviation).
