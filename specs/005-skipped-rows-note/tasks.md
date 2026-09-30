---

description: "Task list for spec 005 — Skipped Rows Note (LTA-2)"
---

# Tasks: Skipped Rows Note

**Input**: Design documents from `/specs/005-skipped-rows-note/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/domain-contracts.md, quickstart.md

**Tests**: Constitution Principle III (Test-First, NON-NEGOTIABLE) applies. Every reducer, Domain and repository
change has a test task *before* its implementation task. The test must be seen failing (Red) before the
implementation is written. This is not possible for guard tests of behaviour an earlier phase already
delivered, so each of those names a mutation to apply briefly, to prove the test can fail.

**Organization**: Tasks are grouped by user story, so each story can be implemented and tested on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1 / US2 / US3 from spec.md

Test command used throughout (see quickstart.md; fall back to `-destination 'platform=macOS,arch=arm64'` if simulators won't boot):
`xcodebuild test -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:lottoApp2Tests`

---

## Phase 1: Setup

**Purpose**: Confirm a green baseline, so every later failure is caused by this feature.

- [X] T001 Run the full `lottoApp2Tests` suite on `main` and record that it passes (no production change) *(Green on the iPhone 17 Pro simulator. Later runs used `platform=macOS,arch=arm64`, because the simulator shut down mid-session.)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Persist the skipped count and lift it into the Domain `Source`. Every story reads it from here.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete.

- [X] T002 Update every `LocalStore.save` call and `save:` closure in the tests to the new arity `(draws, source, asOf, skipped)`. Pass `0` where the count is irrelevant. Files: `lottoApp2Tests/LocalStoreTests.swift`, `lottoApp2Tests/Data/LocalStoreDigestTests.swift`, `lottoApp2Tests/SorcesRepoImpTests.swift` (`save: { _, _, _, _ in }`, `store.save = { _, _, _, _ in throw … }`, `store.save(draws, mbnet, syncDate, 0)`)
- [X] T003 [P] Write failing tests in `lottoApp2Tests/LocalStoreTests.swift`:
  - (a) `save(draws, mbnet, asOf, 3)` then `listSourceMetaFor(["mbnet"])["mbnet"]?.lastSyncSkipped == 3`, for both `.fileBacked` and `.inMemory()`;
  - (b) a second `save(…, 0)` replaces it with `0`;
  - (c) a meta JSON **without** the `lastSyncSkipped` key (write `{"name":"mbnet","lastSync":0,"recordsCount":1,"contentDigest":""}` to `<root>/sources/mbnet/meta.json`) decodes with `lastSyncSkipped == 0` (FR-013);
  - (d) a fresh `LocalStore.fileBacked(root:)` on the same root reads the stored count back (FR-004).
- [X] T004 [P] Write a failing test in `lottoApp2Tests/SorcesRepoImpTests.swift`: `listKnownSources` with stored `SourceMeta(…, lastSyncSkipped: 4)` returns `Source(…, lastSyncSkipped: 4)`, and a never-synced source still has `lastSyncSkipped == nil` (contracts §2)
- [X] T005 Implement the store side in `lottoApp2/Data/Sources/LocalStore.swift`:
  - add `var lastSyncSkipped: Int = 0` to `SourceMeta` ("new, default `0`");
  - add `lastSyncSkipped` to `CodingKeys`, decoded with `decodeIfPresent(Int.self, forKey: .lastSyncSkipped) ?? 0`;
  - change `save` to `@Sendable ([DrawDTO], RemoteSource, _ asOf: Date, _ skipped: Int) async throws -> Void`, threaded through `fileBacked`, `inMemory`, `FileStore.save`, `MemoryStore.save` and `LocalStore.meta(name:draws:asOf:skipped:)`;
  - leave `testValue` as `unimplemented`.

  Makes T003 pass.
- [X] T006 Implement the Domain lift:
  - add `let lastSyncSkipped: Int?` (init default `nil`, "`nil` until the first one") to `Source` in `lottoApp2/Domain/Ents/Source.swift`;
  - pass `lastSyncSkipped: lastSyncSkipped` in `SourceMeta.source(displayName:)` in `lottoApp2/Data/Repos/SorcesRepoImp.swift`;
  - in the same file, call `store.save(fetched.draws, source, date.now, fetched.skipped)` for now (T013 switches this to `skippedTotal`).

  Makes T004 pass.

**Checkpoint**: The suite is green, and the count round-trips store → `Source`.

---

## Phase 3: User Story 1 — See that the last sync skipped records (Priority: P1) 🎯 MVP

**Goal**: A sync drops the draws that break the rules. It counts them together with the unreadable rows, and
the card shows "N record(s) skipped in last sync".

**Independent Test**: Serve a body with unreadable rows and rule-breaking draws, then refresh. Only the valid
draws are stored, and the card state and note show the total.

### Tests for User Story 1 (write first, see them fail) ⚠️

- [X] T007 [P] [US1] Create `lottoApp2Tests/Data/FetchedDrawsValidationTests.swift` (swift-testing, `@testable import lottoApp2`). Use the MBNet game type `try CombinationType(pick: 6, pool: 49)` in a `GameType`. Write failing tests for `FetchedDraws.validated(against:)`:
  - (a) all-valid input is returned unchanged with `invalid == 0`;
  - (b) a draw with a repeated number, one with 5 numbers, one with `50`, and one with a negative number are each dropped and counted in `invalid`, while `skipped` is preserved;
  - (c) `skippedTotal == skipped + invalid`;
  - (d) input with `skipped > 0` or invalid draws but no valid draw throws `RemoteSourceError.unparseableBody(skipped: skippedTotal)`;
  - (e) an empty input (`draws: [], skipped: 0`) does not throw;
  - (f) it is idempotent: `try x.validated(against: t).validated(against: t) == x.validated(against: t)`.
- [X] T008 [P] [US1] Add failing repo integration tests to `lottoApp2Tests/SorcesRepoImpTests.swift`, all using `remoteSourcesManager = RemoteSourcesManagerImp.live`, a stubbed `networkClient.data`, a temp `.fileBacked` store and `date = .constant(syncDate)`:
  - (a) parser skips only: 1 garbage line plus 2 valid rows → success, 2 stored, `source.lastSyncSkipped == 1`;
  - (b) Domain skips only: 3 rows, 2 with a repeated number (e.g. `2. 03.02.1957 5,5,11,22,25,27`) → success, 1 stored, `lastSyncSkipped == 2`, and the stored draw indices exclude the invalid ones;
  - (c) both: 1 garbage plus 2 repeated-number plus 1 valid → `lastSyncSkipped == 3`;
  - (d) none: all valid → `lastSyncSkipped == 0`;
  - (e) rows present, all repeated-number → `.failure(.unreadableData)`, nothing stored, no meta (FR-007);
  - (f) a stored valid draw at index 1, then a sync whose index-1 row has a repeated number → the stored index-1 draw is unchanged, and the count includes it;
  - (g) a sync with 1 garbage line, then a sync with an empty body (`""`) → success, `source.lastSyncSkipped == 0`, and the stored draws are unchanged (spec Edge Cases → Empty response).

  Also update `partialBodyStillSucceedsAndSurfacesTheSkippedCount` to assert `source.lastSyncSkipped == 1`.
- [X] T009 [P] [US1] Add failing tests to `lottoApp2Tests/Reducers/SourceEntryTests.swift` (contracts §3):
  - `Source(…, lastSyncSkipped: nil / 0 / 1 / 1204).sourceEntryState(now:)` gives `skippedInLastSync` `nil / nil / 1 / 1204`;
  - `State.apply(_:now:)` sets it from a source with `3`, then clears it to `nil` from a source with `0`.

### Implementation for User Story 1

- [X] T010 [US1] In `lottoApp2/Data/Sources/RemoteSources.swift`:
  - add `var invalid: Int = 0` ("Parsed draws dropped because they break the game rules") and a computed `skippedTotal: Int { skipped + invalid }` to `FetchedDraws`, and document `skipped` as "rows the parser could not read";
  - add `nonisolated func validated(against gameType: GameType) throws(RemoteSourceError) -> FetchedDraws` per data-model.md. It keeps a draw iff `Combination(type: gameType.combinationType, elements: draw.numbers.compactMap(Element.init(exactly:)))` does not throw, and it throws `.unparseableBody(skipped: skippedTotal)` when the result has no draws and `skippedTotal > 0`;
  - in `RemoteSourcesManagerImp.live.sourceFor`, make the registered module's fetch `try await module.fetchDraws().validated(against: module.gameType)`.

  Makes T007 pass.
- [X] T011 [US1] In `lottoApp2/Data/Repos/mbnetSourceModule.swift`, remove the `parsed.draws.isEmpty && parsed.skipped > 0` guard from `MBNetSource.fetchDraws()`, which is now owned by `validated(against:)` (research R2). Update its doc comment and the `SourceModule.fetchDraws` doc to say that the shared fetch step rejects a body with rows but no usable draw.
- [X] T012 [US1] Keep `schemaDriftFailsTheSyncAndPersistsNothing` in `lottoApp2Tests/SorcesRepoImpTests.swift` green after T011. It must still return `.failure(.unreadableData)` through the live wiring. No test edit is expected; if one is needed, record why. *(Done: it passed unchanged. `listsStoredAnalyticsWhenPreviouslySynced` did need `lastSyncSkipped: 0` in its expected `Source`, because a synced source now always carries a count (contracts §2).)*
- [X] T013 [US1] In `lottoApp2/Data/Repos/SorcesRepoImp.swift` `fetchAndSaveDataFrom`:
  - log the warning when `fetched.skipped > 0 || fetched.invalid > 0`, naming both counts separately ("skipped N unreadable row(s), M draw(s) that break the game rules") (FR-012);
  - call `store.save(fetched.draws, source, date.now, fetched.skippedTotal)`.

  Makes T008 pass.
- [X] T014 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntry.swift`:
  - add `var skippedInLastSync: Int?` to `SourceEntry.State`, documented as "the count shown in the note. `nil` means no note. It is never `0`";
  - add a `fileprivate` helper on `Source` that maps `lastSyncSkipped` to `nil` when it is `nil` or `0`;
  - use the helper in both `sourceEntryState(now:)` and `apply(_:now:)`.

  Makes T009 pass.
- [X] T015 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift`:
  - add a `skippedNote` view between `headerRow` and `details`, rendered `if let count = store.skippedInLastSync`. It is a full-width `HStack(spacing: .skippedNoteIconSpacing)` of `Image(.skippedWarning)` (`.foregroundStyle(Color.skippedNoteIcon)`, `.accessibilityHidden(true)`) and `Text(.skippedInLastSync(count))` (`.font(.skippedNote)`, `.foregroundStyle(Color.skippedNoteText)`, no `lineLimit`), with `.frame(maxWidth: .infinity, alignment: .leading)`, padding `.skippedNoteHPadding`/`.skippedNoteVPadding`, background `Color.skippedNoteIcon.opacity(colorScheme == .light ? .lightOpacity : .darkOpacity)` and `.cornerRadius(.skippedNoteCorners)`;
  - add the tokens from contracts §4 under `// MARK: - Resources`: `ImageType.skippedWarning = .system("exclamationmark.triangle.fill")`, `Color.skippedNoteIcon = .warningYellow`, `Color.skippedNoteText = .textPrimary`, `Font.skippedNote = .caption`, `CGFloat` 8/4/8/4;
  - add `LocalizedStringKey.skippedInLastSync(_ count: Int)`, which returns "\(count.formatted()) record skipped in last sync" for 1 and "\(count.formatted()) records skipped in last sync" otherwise.
- [X] T016 [US1] In `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift`, add mocks `mock1skipped` (`mock1n` with `skippedInLastSync = 3`) and `mock1skippedOne` (`= 1`), and add `#Preview`s "Light Mode - skipped note", "Dark Mode - skipped note" and "Light Mode - one skipped record". In the Xcode canvas, check that the note row sits between the header and the details, and that "one skipped record" reads "1 record skipped in last sync" (US1-AS5). *(Previews added; the canvas check itself is still open — it can't be run from the CLI.)*

**Checkpoint**: US1 is complete. A partial or rule-breaking response stores only valid draws, and the card shows the total.

---

## Phase 4: User Story 2 — The note reflects the most recent successful sync (Priority: P2)

**Goal**: The count survives relaunch, is replaced by each successful sync, is cleared by a sync with no skips,
and is left as it was by a failed sync.

**Independent Test**: Sync with skips, list the sources from a fresh store on the same root, sync with no skips,
then fail a sync. The count reads 3 → 3 → 0 → 0 (and a failure after 3 keeps 3).

### Tests for User Story 2 (guards: behaviour delivered by Phase 2/US1) ⚠️

- [X] T017 [P] [US2] Add tests to `lottoApp2Tests/SorcesRepoImpTests.swift`:
  - (a) a sync with 3 skipped, then a sync whose network throws `NetworkClient.Failure.badStatus(503)` → the stored meta `lastSyncSkipped` is still `3` (FR-006, US2-AS4);
  - (b) a sync with 3 skipped, then a clean sync → `source.lastSyncSkipped == 0` (FR-005, US2-AS3);
  - (c) a sync with 3 skipped, then `listKnownSources` with a **new** `LocalStore.fileBacked(root:)` on the same root → `lastSyncSkipped == 3` (US2-AS1).

  Prove that (a) can fail by briefly making the failure path write meta, and (b) by briefly passing `max(skippedTotal, previous)`. Revert both.
- [X] T018 [P] [US2] Add tests to `lottoApp2Tests/Reducers/StartPageTests.swift` using the `blSources` mock pattern already in the file:
  - (a) `.task` listing a `Source` with `lastSyncSkipped: 2` gives an entry with `skippedInLastSync == 2`;
  - (b) a refresh `.success` with `lastSyncSkipped: 1` over an entry showing `3` sets it to `1`;
  - (c) a refresh `.failure(.serverUnreachable)` over an entry showing `3` keeps `3` and sets the alert (US2-AS4);
  - (d) a refresh `.failure(.cancelled)` keeps `3`.

  Prove that (c) can fail by briefly clearing the count in the failure branch, then revert.

### Implementation for User Story 2

- [X] T019 [US2] Make T017 and T018 pass. This should need no production change. If a test fails, fix the cause in `lottoApp2/Data/Sources/LocalStore.swift`, `lottoApp2/Data/Repos/SorcesRepoImp.swift` or `lottoApp2/Presentation/StartPage/StartPage.swift`, and record the fix here. *(Done: T017/T018 passed with no production change. Mutations were applied and reverted: clearing the count on a failed refresh failed T018(c); writing meta on the fetch-failure path failed T017(a); `max(total, previous)` failed T017(b).)*

**Checkpoint**: The note's lifetime matches spec US2.

---

## Phase 5: User Story 3 — The note is readable in every appearance (Priority: P3)

**Goal**: The note is legible in light and dark at AX5, wraps at word boundaries, and is announced by VoiceOver.

**Independent Test**: Render the AX5 previews with the note in light and dark. Both reflow, neither breaks mid-word,
and the text is a separate accessibility element.

- [X] T020 [US3] Add `#Preview`s "Light Mode - AX5 skipped note" (`mock1skipped`) and "Dark Mode - AX5 skipped note" (`mock1skipped` with `isSelected = true`), both with `.dynamicTypeSize(.largestAccessibility)`, in `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift`. In the Xcode canvas, check that no label in either preview breaks mid-word, and that the header and details reflow as in the existing AX5 previews (SC-005). *(Previews added; the canvas check itself is still open — it can't be run from the CLI.)*
- [X] T021 [US3] Check the accessibility of `skippedNote` in `lottoApp2/Presentation/StartPage/Widgets/SourceEntryView.swift`:
  - the icon is `accessibilityHidden(true)`;
  - the `Text` has no `lineLimit` or `minimumScaleFactor`;
  - the card keeps `.accessibilityElement(children: .contain)`, so VoiceOver reads the note on its own (FR-010, FR-011).

  Add a one-line comment giving the reason for each choice, matching the file's existing comment style.

**Checkpoint**: All three stories are complete.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T022 Build the app target (`xcodebuild build -scheme lottoApp2 -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`) with no new warnings in the touched files
- [X] T023 Run the full `lottoApp2Tests` suite and confirm it is green (quickstart.md §1)
- [X] T024 [P] Update `CLAUDE.md` (Domain model & block pipeline → a short "Sync validation" note): parsed draws are validated against the source's `GameType` in `RemoteSourcesManagerImp.sourceFor`, and the last successful sync's skipped total is persisted as `SourceMeta.lastSyncSkipped` and shown on the source card
- [X] T025 [P] Mark spec 001 FR-007's "surface that some records were skipped" as delivered by spec 005, with a one-line pointer under `specs/001-mbnet-source/spec.md` FR-007

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2**: T001 before anything else.
- **Phase 2**: T002 first, because it makes the existing tests compile against the new arity. It is paired with T005, since the tests compile only after both. T003 and T004 [P] come next, then T005, then T006.
- **US1 (Phase 3)**: Depends on Phase 2. T007, T008 and T009 [P] come first (Red). Then T010 → T011 → T012 → T013 (Data), and T014 → T015 → T016 (Presentation). T014 depends only on T006 and T009, so the Data and Presentation chains can run in parallel.
- **US2 (Phase 4)**: Depends on Phase 2 and T013/T014. T017 and T018 [P], then T019.
- **US3 (Phase 5)**: Depends on T015/T016.
- **Polish**: Depends on all stories. T024 and T025 [P].

### Parallel examples

```text
Phase 2:  T003 (LocalStoreTests)  ∥  T004 (SorcesRepoImpTests)
US1 Red:  T007 (FetchedDrawsValidationTests)  ∥  T008 (SorcesRepoImpTests)  ∥  T009 (SourceEntryTests)
US1 Green: [T010 → T011 → T012 → T013]  ∥  [T014 → T015 → T016]
US2:      T017 (SorcesRepoImpTests)  ∥  T018 (StartPageTests)
Polish:   T024 (CLAUDE.md)  ∥  T025 (spec 001)
```

## Implementation Strategy

- **MVP**: Phases 1–3 (US1). The skip is surfaced, and invalid draws are no longer stored.
- **Increment 2**: US2 guards the lifetime rules that the Phase 2 design already gives.
- **Increment 3**: US3 accessibility previews and checks.
- The suite is green at every checkpoint.
