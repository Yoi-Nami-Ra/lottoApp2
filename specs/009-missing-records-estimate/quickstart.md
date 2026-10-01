# Quickstart: Missing Records Estimate

## Prerequisites

- Xcode 27 Beta toolchain, scheme `lottoApp2`. Add `-skipMacroValidation` while the macros await approval in
  Xcode.
- If simulators won't boot, use `-destination 'platform=macOS,arch=arm64'`.

## 1. Unit tests

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=macOS,arch=arm64' -only-testing:lottoApp2Tests -skipMacroValidation
```

| Scenario | Where | Proves |
| --- | --- | --- |
| Window, edges, not enough history, estimate 0/1/many, negative interval | `Domain/DrawCadenceTests` (new) | FR-001, FR-002, FR-004, contracts §1 |
| Save writes the cadence, survives a reload, legacy meta → nil | `LocalStoreTests` | FR-003, contracts §2 |
| Severity from the estimate, day-based fallback, never synced, `missingEstimate` mapping | `SourceEntryTests` | FR-005, FR-006, contracts §3 |
| Refresh recomputes the estimate and severity | `StartPageTests` | FR-009 |

## 2. Visual check (canvas)

The previews in `SourceEntryView.swift` and `CompactSourceEntryView.swift` (expanded), in light and dark:
- each severity with an estimate (0 → no line, 1, many);
- a source with no estimate;
- AX5 with the line.

## 3. Run the app

Sync MBNet and expand its card. With a recent draw there is no "~N missing" and the badge is green. Moving
the device clock forward a week shows "~N missing" and a red badge.
