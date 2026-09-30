# Quickstart: Specific Sync Errors

## Automated validation

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests
```

Expected: the whole suite passes, including:

- the classification test, with one argument per row of [research R3](./research.md#r3--the-classification-table-spec-q2-q3)
- the repo tests, one per `SyncFailure` kind plus the two `gameFor` read kinds, each asserting nothing was
  persisted
- the `StartPage` refresh tests, one per shown kind plus "cancelled shows no alert"
- the `ChainEditor` read-failure tests for both kinds
- the distinct-messages test (SC-001, SC-004)

## Manual validation (simulator)

1. Launch the app and let the source list load.
2. **Offline**: turn off the Mac's network (the simulator shares it) and tap Refresh on MBNet Server.
   The alert reads "Your device appears to be offline…". Dismiss it; the card's analytics are unchanged.
3. **Unreachable**: use Network Link Conditioner ("100% Loss") with the network on and tap Refresh. After
   the 15 s request timeout, the alert reads "Couldn't reach MBNet Server. Try again later."
4. **Success still works**: restore the network and tap Refresh. The card updates and no alert shows.
5. **Chain run**: open a chain on MBNet and tap Run. It runs normally. The two read failures can't be
   triggered from the UI without editing stored files; the reducer tests cover them.

Copy for every kind: [contracts §4](./contracts/domain-contracts.md#4-ui-contract-alert-copy).
