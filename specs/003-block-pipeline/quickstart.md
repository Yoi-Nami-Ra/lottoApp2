# Quickstart: Processing Block Pipeline

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contracts**: [contracts/domain-contracts.md](./contracts/domain-contracts.md)

How to prove the feature works. Test names are indicative; `tasks.md` fixes the exact suites.

## Prerequisites

- Xcode 27 Beta toolchain, an installed iOS 18.6+ simulator (`xcrun simctl list devices available`).
- MBNet synced at least once in the simulator (start page → Refresh) for the manual checks.

## 1. Unit and reducer tests

```bash
xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests
```

Expected: all green. The suites that cover this spec (fixtures from `Domain/ReferenceDraws.swift`):

| Suite (lottoApp2Tests/) | Proves |
|---|---|
| `Domain/CombinationTests` | FR-001, FR-002 invariants and order-independent equality |
| `Domain/PipelineValuesTests` | FR-003, FR-004; unordered counts stored item-ascending (FR-025) |
| `Domain/BlockEvaluatorTests` | every block against a hand-computed reference set, including ties, empty input and clamped x (SC-001) |
| `Domain/ChainRulesTests` | every (parent kind × block) pair — exactly the FR-010 table accepted (SC-002); subtree removal; revision bumps |
| `Domain/ChainRunnerTests` | one evaluation per shared node (SC-004), leaf-local failure (FR-023), over-budget (FR-022), cancellation (FR-020) |
| `Domain/FreshnessTests` | out-of-date rules for shown and saved results, each judged against its own source (FR-021, FR-030, SC-007) |
| `Domain/ResultSummaryTests` | the summary of every value kind, including repeats and empty (FR-024) |
| `Data/ChainsRepoImplTests` | save/list/delete chains, results, drafts in a temp directory; cascade delete |
| `Data/LocalStoreDigestTests` | digest stable across reorders of the same draws, changes when a draw changes |
| `Reducers/BlocksPageTests` | chain list, new/rename/delete with the saved-result count and draft in the warning; dismissing the editor mid-run cancels the run |
| `Reducers/ChainEditorTests` | add/edit/remove, run → events → results, opening any node's result, stale after edit, new run cancels old, save and open saved results, back-warning, background draft, restore/decline |
| `Reducers/ResultPageTests` | display order, ranking, empty state, grouped combinations, freshness banner |
| `Reducers/AddBlockTests` | availability per parent kind with reasons, parameter validation, delegates |

## 2. Manual end-to-end (simulator)

Run the app (`xcodebuild build …` then launch, or Xcode ▶).

1. **Top 10 (US1–US3, SC-006)**: choose MBNet → Next → New chain → + on the input → Suffix 100 →
   + → Count Unique Elements → + → Sort by Count, descending → + → Prefix 10 → Run.
   Expect: progress while running; the leaf summary shows 10 elements; opening it lists 10 numbers,
   highest count first, ties by number ascending. The intermediate Count Unique Elements row also has a
   summary and opens its full list. Time the whole build-and-run from an empty chain (SC-006: under 1 minute).
2. **Branches (US4)**: + on the input → Suffix 50 → + → Count Unique Elements → Run. Expect: both
   branches' leaves show results from one run.
3. **Attach rule (US5)**: + on the input → Sort by Count is shown disabled with "Needs counts".
4. **Stale (US6)**: change Suffix 100 to 50 → every result reads out of date; Run → marks clear.
5. **Save and reuse (US8)**: save the Count Unique Elements result and the leaf result; relaunch; open
   the chain → both saved results listed; leaves read "not run".
6. **Out of date after sync (SC-007)**: Refresh MBNet on the start page after new draws exist →
   reopen the chain → saved MBNet results read out of date.
7. **Leave warning (FR-032)**: Run, then tap Back without saving → Save / Discard / Cancel.
8. **Draft (FR-031)**: Run, press Home, swipe the app away, relaunch, reopen the chain → "Restore unsaved
   results?"; Restore shows them, Decline leaves "not run".
9. **Delete cascade (FR-017, FR-032)**: delete the chain from the chain list → the warning names the
   number of saved results, and also mentions unsaved results if step 8 left a draft.
10. **Other source (US8 AS1, SC-007)**: go back to the start page, choose another source, reopen the
   chain, Run → results name that source; the saved MBNet results keep their own freshness.

## 3. Light / dark and Dynamic Type

Every new view's `#Preview`s cover light and dark and the states in the LTA-21 / LTA-22 proposals
(`design/proposal/21-chain-builder.html`, `design/proposal/22-add-block-sheet.html`).
