# Quickstart: Fetch Button on Never-Synced Sources

## Prerequisites

- Branch `008-fetch-never-synced`. Build with `-skipMacroValidation` if the macros aren't approved.
- If the simulators are wedged, run the tests on `platform=macOS,arch=arm64`.

## Automated checks

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=macOS,arch=arm64' -only-testing:lottoApp2Tests -skipMacroValidation
```

Expected: every suite passes. The new cases are in `SourceEntryTests` and `StartPageTests` (see [contracts/ui-contracts.md](contracts/ui-contracts.md) §1–§3):

1. A never-synced `Source` maps to `syncAction == .fetch`; a synced one maps to `.refresh`.
2. `apply` with a first successful sync turns `.fetch` into `.refresh`.
3. `StartPage`: on a never-synced source, a fetch that succeeds ends in `.refresh`.
4. `StartPage`: a fetch that fails with `.unknown` keeps `.fetch`, and its alert reads "Couldn't fetch MBNet Server. Try again."
5. The per-failure alert messages are the same for both kinds; the refresh fallback still reads "Couldn't refresh …".

## Visual checks (previews)

Open `SourceEntryView.swift` and `CompactSourceEntryView.swift` and check the never-synced previews against [contracts/ui-contracts.md](contracts/ui-contracts.md) §4:

- idle: download glyph, with "Fetch" on the full card
- fetching: spinning arrows, dimmed, with "Fetching…" on the full card
- light and dark: same colours as the Refresh button
- largest accessibility size: "Fetch" / "Fetching…" on one line, not truncated

## Manual run

Delete the app's data (or install fresh), launch, and confirm the card shows "Not synced" with a Fetch button. Tap Fetch: it spins, then the card shows a last-sync time and a Refresh button.

## Design note

`design/final/source-cards.html` only draws Refresh. Fetch keeps that button's design apart from its label and idle glyph (research R5).
