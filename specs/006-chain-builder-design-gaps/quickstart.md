# Quickstart: Chain-Builder Design Gaps

## Prerequisites

- Xcode 27 Beta, and a booted simulator (see `xcrun simctl list devices available`). If the simulators are
  wedged, use the My Mac destination.

## Automated validation

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests
```

Expected: all suites pass, including the new cases in `AddBlockTests` (hints, preview, z bound),
`ChainEditorTests` (context, draw size) and `BlocksPageTests` (rename flow, empty-state gate).

## Manual validation (against design/final/)

1. **Chain list** ([chain-list.html](../../design/final/chain-list.html))
   - Fresh install, Sources → Next. "No chains yet" and its explanation sit above New chain.
   - Create two chains. Swipe one right, tap Rename, and it shows the name ready to edit. Swipe left and Delete
     asks first. Long-press shows Rename and Delete.
   - With VoiceOver, a row reads "<name>, <N> blocks", and the actions rotor lists Rename and Delete.
2. **Add-block sheet** ([add-block-sheet.html](../../design/final/add-block-sheet.html))
   - Run a chain, then tap "+" on the source and pick Prefix. It reads "Of 7,012 draws. A larger x keeps them
     all." (the synced count).
   - Edit a Suffix block. It reads "Was 100. Saving marks this block's results out of date."
   - Add Sort by Count. "Most frequent first." shows, and Ascending switches it to "Least frequent first."
   - Add Count Unique Sub-combinations on a 6-of-49 source. At z = 5 the "+" is disabled, and typing 6 shows
     "Enter a whole number from 2 to 5." with Add disabled.
   - With VoiceOver, a disabled row reads "<block>, unavailable, <reason>". Swiping up or down on the stepper
     changes x.
   - At AX5, the field and stepper stack.
3. **Chain editor** ([chain-builder.html](../../design/final/chain-builder.html))
   - With VoiceOver, a row reads "Suffix, last 100, level 1, 100 draws", and "+" reads "Add block under
     Suffix".
   - At AX5 the summary wraps under the title, and the indent is visibly narrower (12 pt).
4. **Previews**: open `BlocksPageView` and `BlockParametersView`. The new previews (empty list, hints, z bound)
   render in light and dark.
