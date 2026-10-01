# Quickstart: Compact and Wide Source Cards

## Prerequisites

- Xcode 27 Beta toolchain, scheme `lottoApp2`.
- An available simulator (`xcrun simctl list devices available`). If simulators won't boot, use
  `-destination 'platform=macOS,arch=arm64'`.
- Google Chrome, to render the design snapshot.

## 1. Unit tests

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests
```

Expected: the whole suite is green, including the tests this feature adds:

| Scenario | Where | Proves |
| --- | --- | --- |
| Toggle collapsed → expanded → collapsed, nothing received | `SourceEntryTests` | FR-007, US2-AS1/AS2/AS4, contracts §1 |
| `sourceEntryState` starts collapsed; `apply` keeps `isExpanded` | `SourceEntryTests` | FR-010, data model transitions |
| Two entries expanded at once | `StartPageTests` | US2-AS3 |
| Reload keeps survivors' flags and starts new sources collapsed | `StartPageTests` | US2-AS8, contracts §2 |
| Refresh success and failure keep the flag | `StartPageTests` | US2-AS8 |
| Expanding leaves `selectedSourceID` unchanged | `StartPageTests` | US2-AS4 |
| Existing selection and refresh suites still green | `SourceEntryTests`, `StartPageTests` | FR-016, SC-003 |

## 2. Visual check (canvas)

Open these files and check each preview in light and dark:

- `CompactSourceEntryView.swift`: collapsed, expanded, selected, refreshing, never synced, expanded with the
  skipped note, AX5 collapsed, and AX5 expanded (the name wraps, the buttons keep their size, the details are
  one column).
- `StartPageView.swift`:
  - the compact-width list (four sources fit without scrolling, SC-001);
  - the regular-width grid at iPad landscape width (three columns, equal row heights, Next at the trailing
    edge with a fixed width, SC-005).
- `SourceEntryView.swift`: every existing preview looks as it did before (refactor check, R4).
- `BottomActionBar.swift`: compact and regular previews.

## 3. Run the app

1. iPhone 17 Pro simulator: compact rows appear. Tap a row and it is selected and Next is enabled. Tap a
   chevron and the details open while the selection stays. Tap inside the details and the source is selected.
   Tap refresh and the icon spins and the selection stays.
2. iPad simulator in landscape: full cards appear in a grid. Enter a narrow split view and the page switches to
   compact rows, keeping the selection and the expanded cards.
3. VoiceOver on the iPhone: the row reads its name and "Last synced: …", the buttons read
   "Refresh" and "Show details", and the dot is not announced.

## 4. Design promotion

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars --window-size=1640,1900 --screenshot=design/final/source-cards.png "file://$PWD/design/final/source-cards.html"
```

Expected: `design/final/source-cards.{html,png}` exist, `design/proposal/28-source-cards.*` are gone, LTA-28 is
`done` with `designs: [design/final/source-cards.html]`, and LTA-29 lists the same file and is unblocked.
