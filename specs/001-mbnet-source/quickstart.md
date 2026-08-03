# Quickstart: Validate the Real MBNet Server Source

End-to-end validation that the feature works. Run after implementation. References
[data-model.md](./data-model.md) and [contracts/](./contracts/) instead of restating them.

## Prerequisites

- Xcode 27 Beta toolchain; scheme `lottoApp2`; an installed iOS simulator (e.g. iPhone 16).
- Network access to `http://www.mbnet.com.pl/dl.txt` for the live-path check.
- **App Transport Security exception** for `www.mbnet.com.pl` present (plain-HTTP host) — without it the live
  fetch fails and the app shows the failure alert.

## 1. Unit tests (hermetic — no network/disk)

```bash
# All feature unit tests
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:lottoApp2Tests

# Focused runs
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:lottoApp2Tests/MBNetParserTests
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:lottoApp2Tests/SourceEntry_Tests
```

**Expected**: all pass. Per Principle III these were written **before** their implementations (Red→Green).
Coverage to confirm present:
- Parser: well-formed line → `DrawDTO` with 6 numbers; malformed line → `skipped` incremented, others kept;
  empty body → `draws == []`; number-range rejection. (contracts/mbnet-file-format.md)
- LocalStore: two saves with overlapping indices → union has no duplicates and no losses; `SourceMeta`
  count/first/latest derived from the merged set. (FR-008, data-model.md)
- SourceEntry: `.refresh` → `isRefreshing=true`; `.refreshResponse(.success)` → analytics replaced,
  `isRefreshing=false`; `.refreshResponse(.failure)` → alert presented, analytics unchanged; second `.refresh`
  while refreshing → no additional received action (FR-020).

## 2. Live end-to-end (real fetch)

1. Launch the app in the simulator.
2. **US1 / FR-001**: On first launch (fresh install), confirm **"MBNet Server"** is listed with the
   never-synced card state (no count, no dates, "Not synced").
3. **US2 / FR-018/019**: Tap the card's **Refresh** button. Confirm the button switches to **"Refreshing…"**
   with a continuously **rotating** icon and is not tappable again while spinning.
4. **FR-017 / SC-008**: When it completes, the button returns to **"Refresh"** and the card's analytics update
   live (record count ≈ 7,400 and climbing over time; earliest ≈ `27.01.1957`; latest = most recent draw) —
   without relaunching.
5. **FR-011**: Force-quit and relaunch. Confirm the MBNet card shows the last-known analytics immediately
   (loaded from `meta.json`, no re-fetch).
6. **FR-008 / SC-005**: Tap Refresh again. Confirm the count does not double and no records disappear.

## 3. Failure path (FR-006 / FR-021 / SC-004, SC-010)

Simulate no connectivity (turn off the host's network / use a broken URL build config, or run offline):
1. Tap **Refresh**.
2. **Expected**: after the 15s timeout (or immediate transport error), an **alert dialog** appears reporting
   the sync failed; the button returns to idle; the card's previously displayed analytics are **unchanged**.
3. Dismiss the alert → card idle, data intact.

## 4. Performance spot-check (SC-006)

- With the parser/store in place, the parse+persist of the full history should complete in ≤1s on a typical
  device (network transfer excluded). Sanity-check via a signpost/log around
  `MBNetParser.parse` + `LocalStore.save`, or a timed unit test feeding the full fixture body.

## 5. Visual / previews (Principle V)

- Open `SourceEntryView` previews: confirm coverage for **light + dark** across **idle**, **refreshing**,
  **never-synced**, and **error-alert** states, with no inline color/spacing/copy literals remaining in the
  refresh button (all via tokens; label copy via `LocalizedStringKey`).

## Done = all of §1 green, §2 steps observed, §3 alert + data-intact confirmed, §4 within budget, §5 previews present.
