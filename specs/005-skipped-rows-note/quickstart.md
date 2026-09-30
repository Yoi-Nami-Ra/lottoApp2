# Quickstart: Skipped Rows Note

## Prerequisites

- Xcode 27 Beta toolchain, scheme `lottoApp2`.
- An available simulator (`xcrun simctl list devices available`). If simulators won't boot, use
  `-destination 'platform=macOS,arch=arm64'`.

## 1. Unit and integration tests

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests
```

Expected: the whole suite is green, including the tests this feature adds:

| Scenario | Where | Proves |
| --- | --- | --- |
| Unreadable rows only, rule-breaking draws only, both, none | `SorcesRepoImpTests` (live wiring, stubbed network, temp store) | FR-001–FR-003, contracts §1 rows 1–4 |
| Rows present, none valid → `.unreadableData`, nothing stored | `SorcesRepoImpTests` | FR-007 |
| Count survives a new `LocalStore.fileBacked` on the same root | `LocalStoreTests` | FR-004, US2-AS1 |
| Failed sync keeps the previous count | `SorcesRepoImpTests` | FR-006, US2-AS4 |
| 0 skipped replaces an earlier count | `SorcesRepoImpTests` | FR-005, US2-AS3 |
| Meta JSON without the field decodes as 0 | `LocalStoreTests` | FR-013 |
| `validated(against:)` keeps, drops, throws | `FetchedDrawsValidationTests` (new) | R1, R2 |
| `nil`/0/1/n → `skippedInLastSync` | `SourceEntryTests` | contracts §3 |
| Refresh success updates the note; failure keeps it | `StartPageTests` | US2-AS2/AS4 |

## 2. Visual check (canvas)

Open `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift` and check these previews:

- "Light/Dark Mode - skipped note": the warning row sits between the header and the record details, with an
  icon and "3 records skipped in last sync".
- "Light/Dark Mode - AX5 skipped note": the note wraps at word boundaries, and the header and details still
  reflow as before.
- The existing previews show no note.

## 3. Manual end-to-end (optional)

1. Run the app. Refresh MBNet: a clean response shows no note.
2. To force skips, temporarily point a debug build's `networkClient` at a local body that has one garbage line
   and one draw with a repeated number. Refresh: the note reads "2 records skipped in last sync".
3. Relaunch: the note is still there. Refresh with a clean body: the note disappears.
