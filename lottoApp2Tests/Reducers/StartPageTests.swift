//
//  StartPageTests.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 03/10/2025.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import lottoApp2

struct StartPage_Tests {

    /// A seeded entry for `mbnet` with recognisably "old" analytics.
    private func seededEntry(isRefreshing: Bool = false) -> SourceEntry.State {
        SourceEntry.State(
            id: "mbnet",
            name: "MBNet Server",
            lastSync: .fixedNow,
            lastSyncSeverity: .low,
            firstRecordDate: .fixedNow,
            lastRecordDate: .fixedNow,
            recordsCount: 100,
            isRefreshing: isRefreshing
        )
    }

    @MainActor
    @Test
    func action_task() async throws {
        let store = TestStore(initialState: StartPage.State()) {
            StartPage()
                .dependency(\.blSources, .mock)
                .dependency(\.date, .constant(.fixedNow))
        }
        await store.send(.task)
        await store.receive(\.sourcesResponse)
        {
            $0.sources = [
                Source.mbnetMock.sourceEntryState(now: .fixedNow),
                Source.lottoMock.sourceEntryState(now: .fixedNow),
            ]
            // Two sources: the first result marks the screen loaded but chooses nothing (FR-010).
            $0.hasLoaded = true
        }
        #expect(store.state.selectedSourceID == nil)
    }

    @MainActor
    @Test
    func refresh_success_drivesRefreshingAndReplacesEntry() async throws {
        // A child refresh tap forwards a delegate; the parent owns the fetch, drives `isRefreshing`,
        // and updates the entry with the fetched analytics.
        let store = TestStore(initialState: StartPage.State(sources: [seededEntry()])) {
            StartPage()
                .dependency(\.blSources, .mock)
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            $0.sources[id: "mbnet"]?.apply(.refreshedMbnetMock, now: .fixedNow)
        }
        #expect(store.state.sources[id: "mbnet"]?.recordsCount == 7380)
    }

    @MainActor
    @Test
    func refresh_failure_presentsAlertAndKeepsAnalytics() async throws {
        // FR-021 / SC-004: a failed fetch raises the entry's alert and leaves prior analytics intact.
        let store = TestStore(initialState: StartPage.State(sources: [seededEntry()])) {
            StartPage()
                .dependency(\.blSources, .failureMock)
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            $0.sources[id: "mbnet"]?.alert = .syncFailed(.unknown, sourceName: "MBNet Server", action: .refresh)
        }
        #expect(store.state.sources[id: "mbnet"]?.recordsCount == 100)
    }

    @MainActor
    @Test(arguments: SourceEntry_Tests.shownFailures)
    func refresh_failure_showsTheMessageForItsKind(_ failure: SyncFailure) async throws {
        // Spec 004 US1 / FR-002–FR-003: the card's alert is the one for this kind, and analytics stay put.
        let store = TestStore(initialState: StartPage.State(sources: [seededEntry()])) {
            StartPage()
                .dependency(\.blSources, .failing(sync: failure))
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            $0.sources[id: "mbnet"]?.alert = .syncFailed(failure, sourceName: "MBNet Server", action: .refresh)
        }
        #expect(store.state.sources[id: "mbnet"]?.recordsCount == 100)
    }

    @MainActor
    @Test
    func refresh_cancelled_clearsRefreshingWithoutAnAlert() async throws {
        // Spec 004 FR-007: a cancelled sync isn't a failure — the spinner stops and nothing is shown.
        let store = TestStore(initialState: StartPage.State(sources: [seededEntry()])) {
            StartPage()
                .dependency(\.blSources, .failing(sync: .cancelled))
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
        }
    }

    @MainActor
    @Test
    func sourcesResponse_preservesInFlightRefreshAndAlert() async throws {
        // FR-020 regression: a reload landing mid-sync must not clear `isRefreshing` (which would drop the
        // child's re-entrancy guard and let a second concurrent sync start) or dismiss an unseen alert.
        var refreshing = seededEntry(isRefreshing: true)
        refreshing.alert = .syncFailed(.serverError(status: 503), sourceName: "MBNet Server", action: .refresh)

        let store = TestStore(initialState: StartPage.State(sources: [refreshing])) {
            StartPage()
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sourcesResponse([.mbnetMock])) {
            $0.sources[id: "mbnet"]?.apply(.mbnetMock, now: .fixedNow)
            $0.sources[id: "mbnet"]?.isRefreshing = true
            $0.sources[id: "mbnet"]?.alert = .syncFailed(.serverError(status: 503), sourceName: "MBNet Server", action: .refresh)
            // New state this response also settles: sole source → chosen, screen → loaded.
            $0.sources[id: "mbnet"]?.isSelected = true
            $0.selectedSourceID = "mbnet"
            $0.hasLoaded = true
        }
    }

    // MARK: - Fetch or Refresh (spec 008)

    /// A never-synced `mbnet` entry, so a sync answered by the `mbnet` mocks is its first one.
    private func neverSyncedEntry(isRefreshing: Bool = false) -> SourceEntry.State {
        SourceEntry.State(id: "mbnet", name: "MBNet Server", isRefreshing: isRefreshing)
    }

    @MainActor
    @Test
    func firstFetch_success_turnsFetchIntoRefresh() async throws {
        // US1-AS3/AS4: Fetch runs the same sync as Refresh and, once it succeeds, the card offers Refresh.
        let store = TestStore(initialState: StartPage.State(sources: [neverSyncedEntry()])) {
            StartPage()
                .dependency(\.blSources, .mock)
                .dependency(\.date, .constant(.fixedNow))
        }
        #expect(store.state.sources[id: "mbnet"]?.syncAction == .fetch)

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            $0.sources[id: "mbnet"]?.apply(.refreshedMbnetMock, now: .fixedNow)
        }
        #expect(store.state.sources[id: "mbnet"]?.syncAction == .refresh)
    }

    @MainActor
    @Test
    func firstFetch_failure_keepsFetch_andUsesFetchWording() async throws {
        // FR-006/FR-007: a failed first fetch leaves the source without data, so it still offers Fetch, and the
        // general-purpose message says what was attempted.
        let store = TestStore(initialState: StartPage.State(sources: [neverSyncedEntry()])) {
            StartPage()
                .dependency(\.blSources, .failureMock)
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            $0.sources[id: "mbnet"]?.alert = .syncFailed(.unknown, sourceName: "MBNet Server", action: .fetch)
        }
        #expect(store.state.sources[id: "mbnet"]?.syncAction == .fetch)
    }

    @MainActor
    @Test
    func firstFetch_cancelled_keepsFetch() async throws {
        let store = TestStore(initialState: StartPage.State(sources: [neverSyncedEntry()])) {
            StartPage()
                .dependency(\.blSources, .failing(sync: .cancelled))
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
        }
        #expect(store.state.sources[id: "mbnet"]?.syncAction == .fetch)
    }

    @MainActor
    @Test
    func sourcesResponse_midFetch_rederivesTheKind_andKeepsInProgress() async throws {
        // Edge case: a reload landing mid-fetch follows the reloaded sync state and keeps the spinner
        // (as `sourcesResponse_preservesInFlightRefreshAndAlert` does for a refresh).
        let store = TestStore(initialState: StartPage.State(sources: [neverSyncedEntry(isRefreshing: true)])) {
            StartPage()
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sourcesResponse([.mbnetMock])) {
            $0.sources[id: "mbnet"]?.apply(.mbnetMock, now: .fixedNow)
            $0.sources[id: "mbnet"]?.isRefreshing = true
            $0.sources[id: "mbnet"]?.isSelected = true
            $0.selectedSourceID = "mbnet"
            $0.hasLoaded = true
        }
        #expect(store.state.sources[id: "mbnet"]?.syncAction == .refresh)
        #expect(store.state.sources[id: "mbnet"]?.isRefreshing == true)
    }

    // MARK: - Compact card details (spec 007)

    private func expandedEntry(_ source: Source) -> SourceEntry.State {
        var entry = source.sourceEntryState(now: .fixedNow)
        entry.isExpanded = true
        return entry
    }

    @MainActor
    @Test
    func sourcesResponse_keepsExpandedForSurvivors() async throws {
        // US2-AS8 / contracts §2: returning from the blocks page reloads the list, which must not fold the
        // open cards away. A source the reload drops takes its flag with it; a new one starts collapsed.
        let initial = StartPage.State(
            sources: [expandedEntry(.mbnetMock), expandedEntry(.neverSyncedMock)],
            hasLoaded: true
        )
        let store = store(initial)

        await store.send(.sourcesResponse([.mbnetMock, .lottoMock])) {
            $0.sources = [expandedEntry(.mbnetMock), Source.lottoMock.sourceEntryState(now: .fixedNow)]
        }
    }

    @MainActor
    @Test
    func expand_twoEntries_bothStayExpanded() async throws {
        // US2-AS3: each card's details are its own; opening one never closes another.
        let store = store(severalSources)

        await store.send(.sources(.element(id: Source.mbnetMock.name, action: .disclosureButtonTapped))) {
            $0.sources[id: Source.mbnetMock.name]?.isExpanded = true
        }
        await store.send(.sources(.element(id: Source.lottoMock.name, action: .disclosureButtonTapped))) {
            $0.sources[id: Source.lottoMock.name]?.isExpanded = true
        }
        await store.send(.sources(.element(id: Source.mbnetMock.name, action: .disclosureButtonTapped))) {
            $0.sources[id: Source.mbnetMock.name]?.isExpanded = false
        }
    }

    @MainActor
    @Test
    func refresh_success_keepsExpanded() async throws {
        // US2-AS8: a finished sync updates the open card's details in place.
        var entry = seededEntry()
        entry.isExpanded = true
        let store = TestStore(initialState: StartPage.State(sources: [entry])) {
            StartPage()
                .dependency(\.blSources, .mock)
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            $0.sources[id: "mbnet"]?.apply(.refreshedMbnetMock, now: .fixedNow)
        }
        #expect(store.state.sources[id: "mbnet"]?.isExpanded == true)
    }

    @MainActor
    @Test
    func refresh_failure_keepsExpanded() async throws {
        // US2-AS8 / US1-AS5: a failed sync raises its alert and leaves the open card open.
        var entry = seededEntry()
        entry.isExpanded = true
        let store = TestStore(initialState: StartPage.State(sources: [entry])) {
            StartPage()
                .dependency(\.blSources, .failureMock)
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            $0.sources[id: "mbnet"]?.alert = .syncFailed(.unknown, sourceName: "MBNet Server", action: .refresh)
        }
        #expect(store.state.sources[id: "mbnet"]?.isExpanded == true)
    }

    @MainActor
    @Test
    func refreshResponse_forRemovedEntry_isIgnored() async throws {
        // Regression: writing through `IdentifiedArray`'s id-subscript would append a ghost row for an entry
        // the list no longer holds (and traps outright if the fetched id differed).
        let store = TestStore(initialState: StartPage.State(sources: [])) {
            StartPage()
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.refreshResponse(id: "mbnet", .success(.refreshedMbnetMock)))
        await store.send(.refreshResponse(id: "mbnet", .failure(.unknown)))
        #expect(store.state.sources.isEmpty)
    }

    @MainActor
    @Test
    func sourcesResponse_derivesSyncSeverityFromInjectedClock() async throws {
        // FR-019-adjacent: severity comes from `@Dependency(\.date)`, not the wall clock, so each threshold
        // is assertable. Boundaries are 2 days (low → medium) and 4 days (medium → high).
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cases: [(TimeInterval, SourceEntry.SyncSeverity)] = [
            (0, .low),
            (2.days - 1, .low),
            (2.days, .medium),
            (4.days - 1, .medium),
            (4.days, .high),
            (30.days, .high),
        ]

        for (age, expected) in cases {
            let source = Source(
                name: "mbnet",
                displayName: "MBNet Server",
                lastSync: now.addingTimeInterval(-age),
                recordsCount: 1
            )
            let store = TestStore(initialState: StartPage.State()) {
                StartPage().dependency(\.date, .constant(now))
            }
            await store.send(.sourcesResponse([source])) {
                // A lone source is chosen automatically; severity is what this test is actually about.
                $0.sources = [source.sourceEntryState(now: now).chosen]
                $0.selectedSourceID = source.name
                $0.hasLoaded = true
            }
            #expect(
                store.state.sources[id: "mbnet"]?.lastSyncSeverity == expected,
                "age \(age)s should map to \(expected)"
            )
        }
    }

    @MainActor
    @Test
    func sourcesResponse_withoutSync_isNotSynced() async throws {
        let store = TestStore(initialState: StartPage.State()) {
            StartPage().dependency(\.date, .constant(.fixedNow))
        }
        await store.send(.sourcesResponse([.neverSyncedMock])) {
            $0.sources = [Source.neverSyncedMock.sourceEntryState(now: .fixedNow).chosen]
            $0.hasLoaded = true
            $0.selectedSourceID = Source.neverSyncedMock.name
        }
        #expect(store.state.sources.first?.lastSyncSeverity == .notSynced)
    }

    // MARK: - Selection rules
    //
    // The rules live in one private helper (`applySelectionRules`) and are exercised through
    // `.sourcesResponse`, which is the only action that changes the list. See data-model.md I2–I5.

    /// The three mocks as entries, none chosen — the starting point for the multi-source cases.
    private var threeEntries: IdentifiedArrayOf<SourceEntry.State> {
        IdentifiedArrayOf(
            uniqueElements: [Source.mbnetMock, .lottoMock, .neverSyncedMock]
                .map { $0.sourceEntryState(now: .fixedNow) }
        )
    }

    private func store(_ state: StartPage.State) -> TestStore<StartPage.State, StartPage.Action> {
        TestStore(initialState: state) {
            StartPage().dependency(\.date, .constant(.fixedNow))
        }
    }

    @MainActor
    @Test
    func sourcesResponse_singleSource_isChosenAutomatically() async throws {
        // FR-009 / I4: the sole source is chosen without the person acting.
        let store = store(StartPage.State())

        await store.send(.sourcesResponse([.mbnetMock])) {
            $0.sources = [Source.mbnetMock.sourceEntryState(now: .fixedNow).chosen]
            $0.hasLoaded = true
            $0.selectedSourceID = Source.mbnetMock.name
        }
        #expect(store.state.isNextEnabled)
    }

    @MainActor
    @Test
    func sourcesResponse_severalSources_choosesNothing() async throws {
        // FR-010 / I5: with a real choice to make, the app never makes it on the person's behalf.
        let store = store(StartPage.State())

        await store.send(.sourcesResponse([.mbnetMock, .lottoMock, .neverSyncedMock])) {
            $0.sources = self.threeEntries
            $0.hasLoaded = true
        }
        #expect(store.state.selectedSourceID == nil)
        #expect(store.state.isNextEnabled == false)
        #expect(store.state.sources.allSatisfy { $0.isSelected == false })
    }

    @MainActor
    @Test
    func sourcesResponse_reload_keepsAChoiceThatIsStillPresent() async throws {
        // FR-016 / FR-029: a reload that still holds the chosen source leaves it chosen.
        var initial = StartPage.State(sources: threeEntries, hasLoaded: true)
        initial.sources[id: Source.lottoMock.name]?.isSelected = true
        initial.selectedSourceID = Source.lottoMock.name
        let store = store(initial)

        await store.send(.sourcesResponse([.mbnetMock, .lottoMock, .neverSyncedMock]))
        #expect(store.state.selectedSourceID == Source.lottoMock.name)
        #expect(store.state.sources[id: Source.lottoMock.name]?.isSelected == true)
    }

    @MainActor
    @Test
    func sourcesResponse_reload_dropsAChoiceThatVanished() async throws {
        // FR-016 / I2: a stale id must not survive, or `Next` would carry a source that is gone.
        var initial = StartPage.State(sources: threeEntries, hasLoaded: true)
        initial.sources[id: Source.lottoMock.name]?.isSelected = true
        initial.selectedSourceID = Source.lottoMock.name
        let store = store(initial)

        await store.send(.sourcesResponse([.mbnetMock, .neverSyncedMock])) {
            $0.sources = IdentifiedArrayOf(
                uniqueElements: [Source.mbnetMock, .neverSyncedMock]
                    .map { $0.sourceEntryState(now: .fixedNow) }
            )
            $0.selectedSourceID = nil
        }
        #expect(store.state.isNextEnabled == false)
    }

    @MainActor
    @Test
    func sourcesResponse_listShrinkingToOne_choosesTheSurvivor() async throws {
        // Research R8: the single-source rule is continuous, so a list that becomes one source
        // chooses it rather than leaving the person with an unexplained disabled `Next`.
        let store = store(StartPage.State(sources: threeEntries, hasLoaded: true))

        await store.send(.sourcesResponse([.lottoMock])) {
            $0.sources = [Source.lottoMock.sourceEntryState(now: .fixedNow).chosen]
            $0.selectedSourceID = Source.lottoMock.name
        }
        #expect(store.state.isNextEnabled)
    }

    @MainActor
    @Test
    func sourcesResponse_neverSyncedSoleSource_isStillChosen() async throws {
        // FR-019 / I6: choosability never depends on records or sync history.
        let store = store(StartPage.State())

        await store.send(.sourcesResponse([.neverSyncedMock])) {
            $0.sources = [Source.neverSyncedMock.sourceEntryState(now: .fixedNow).chosen]
            $0.hasLoaded = true
            $0.selectedSourceID = Source.neverSyncedMock.name
        }
        #expect(store.state.sources.first?.recordsCount == nil)
        #expect(store.state.sources.first?.lastSync == nil)
        #expect(store.state.isNextEnabled)
    }

    // MARK: - Choosing by tapping a card (US2)

    /// Three sources, none chosen — the state the person actually has to make a choice from.
    private var severalSources: StartPage.State {
        StartPage.State(sources: threeEntries, hasLoaded: true)
    }

    @MainActor
    @Test
    func selectionRequested_choosesThatSource() async throws {
        // FR-011: the delegate is the only route into the choice, and `Next` follows from it.
        let store = store(severalSources)

        await store.send(.sources(.element(id: Source.lottoMock.name, action: .cardTapped)))
        await store.receive(\.sources[id: Source.lottoMock.name].delegate.selectionRequested) {
            $0.selectedSourceID = Source.lottoMock.name
            $0.sources[id: Source.lottoMock.name]?.isSelected = true
        }
        #expect(store.state.isNextEnabled)
    }

    @MainActor
    @Test
    func selectionRequested_forADifferentCard_movesTheChoice() async throws {
        // FR-014 / I1: the previous card's mirror is cleared in the same step, so two cards are never
        // highlighted at once.
        var initial = severalSources
        initial.sources[id: Source.lottoMock.name]?.isSelected = true
        initial.selectedSourceID = Source.lottoMock.name
        let store = store(initial)

        await store.send(.sources(.element(id: Source.mbnetMock.name, action: .cardTapped)))
        await store.receive(\.sources[id: Source.mbnetMock.name].delegate.selectionRequested) {
            $0.selectedSourceID = Source.mbnetMock.name
            $0.sources[id: Source.mbnetMock.name]?.isSelected = true
            $0.sources[id: Source.lottoMock.name]?.isSelected = false
        }
        #expect(store.state.sources.filter(\.isSelected).count == 1)
    }

    @MainActor
    @Test
    func selectionRequested_forTheChosenCard_keepsItChosen() async throws {
        // FR-013: re-tapping does not clear the choice — nobody can strand themselves with a disabled
        // `Next` by tapping the card they already picked.
        var initial = severalSources
        initial.sources[id: Source.lottoMock.name]?.isSelected = true
        initial.selectedSourceID = Source.lottoMock.name
        let store = store(initial)

        await store.send(.sources(.element(id: Source.lottoMock.name, action: .cardTapped)))
        await store.receive(\.sources[id: Source.lottoMock.name].delegate.selectionRequested)
        #expect(store.state.selectedSourceID == Source.lottoMock.name)
        #expect(store.state.isNextEnabled)
    }

    @MainActor
    @Test
    func selection_fromExpandedEntry_unchanged() async throws {
        // Spec 007 US1/US2-AS4: the compact card's chevron never chooses, and choosing an expanded card
        // keeps it expanded — the two are independent, whichever variant sends them.
        let store = store(severalSources)

        await store.send(.sources(.element(id: Source.lottoMock.name, action: .disclosureButtonTapped))) {
            $0.sources[id: Source.lottoMock.name]?.isExpanded = true
        }
        #expect(store.state.selectedSourceID == nil)

        await store.send(.sources(.element(id: Source.lottoMock.name, action: .cardTapped)))
        await store.receive(\.sources[id: Source.lottoMock.name].delegate.selectionRequested) {
            $0.selectedSourceID = Source.lottoMock.name
            $0.sources[id: Source.lottoMock.name]?.isSelected = true
        }
        #expect(store.state.sources[id: Source.lottoMock.name]?.isExpanded == true)
    }

    @MainActor
    @Test
    func refreshing_doesNotMoveTheChoice() async throws {
        // FR-017 / I8: refreshing any source — successfully or not — leaves the choice where it was.
        var initial = severalSources
        initial.sources[id: Source.lottoMock.name]?.isSelected = true
        initial.selectedSourceID = Source.lottoMock.name

        let succeeding = TestStore(initialState: initial) {
            StartPage()
                .dependency(\.blSources, .mock)
                .dependency(\.date, .constant(.fixedNow))
        }
        await succeeding.send(.sources(.element(id: Source.mbnetMock.name, action: .refreshButtonTapped)))
        await succeeding.receive(\.sources[id: Source.mbnetMock.name].delegate.refreshRequested) {
            $0.sources[id: Source.mbnetMock.name]?.isRefreshing = true
        }
        await succeeding.receive(\.refreshResponse) {
            $0.sources[id: Source.mbnetMock.name]?.isRefreshing = false
            $0.sources[id: Source.mbnetMock.name]?.apply(.refreshedMbnetMock, now: .fixedNow)
        }
        #expect(succeeding.state.selectedSourceID == Source.lottoMock.name)
        #expect(succeeding.state.sources[id: Source.lottoMock.name]?.isSelected == true)

        let failing = TestStore(initialState: initial) {
            StartPage()
                .dependency(\.blSources, .failureMock)
                .dependency(\.date, .constant(.fixedNow))
        }
        await failing.send(.sources(.element(id: Source.mbnetMock.name, action: .refreshButtonTapped)))
        await failing.receive(\.sources[id: Source.mbnetMock.name].delegate.refreshRequested) {
            $0.sources[id: Source.mbnetMock.name]?.isRefreshing = true
        }
        await failing.receive(\.refreshResponse) {
            $0.sources[id: Source.mbnetMock.name]?.isRefreshing = false
            $0.sources[id: Source.mbnetMock.name]?.alert = .syncFailed(.unknown, sourceName: Source.mbnetMock.displayName, action: .refresh)
        }
        #expect(failing.state.selectedSourceID == Source.lottoMock.name)
    }

    // MARK: - Load states (US1)

    @MainActor
    @Test
    func hasLoaded_isFalseUntilTheFirstResult_andNeverResets() async throws {
        // FR-006 / I7: the loading indication belongs to the period before the first result only, so a
        // later reload must not send the screen back to it.
        let store = store(StartPage.State())
        #expect(store.state.hasLoaded == false)

        await store.send(.sourcesResponse([.mbnetMock, .lottoMock])) {
            $0.sources = IdentifiedArrayOf(
                uniqueElements: [Source.mbnetMock, .lottoMock].map { $0.sourceEntryState(now: .fixedNow) }
            )
            $0.hasLoaded = true
        }
        // A second response changes nothing about the flag — no closure means no state change asserted.
        await store.send(.sourcesResponse([.mbnetMock, .lottoMock]))
        #expect(store.state.hasLoaded)
    }

    @MainActor
    @Test
    func sourcesResponse_empty_marksLoadedWithNoChoice() async throws {
        // FR-005 / FR-008: the no-sources message is reachable only after a result has arrived, and it
        // never comes with a chosen source.
        let store = store(StartPage.State())

        await store.send(.sourcesResponse([])) {
            $0.hasLoaded = true
        }
        #expect(store.state.sources.isEmpty)
        #expect(store.state.selectedSourceID == nil)
        #expect(store.state.isNextEnabled == false)
    }

    // MARK: - Moving forward (US1)

    @MainActor
    @Test
    func nextButtonTapped_withoutAChoice_doesNothing() async throws {
        // FR-021 / SC-004: the flow never moves forward without a chosen source, even if the action
        // arrives while the button is disabled.
        let store = store(StartPage.State(sources: threeEntries, hasLoaded: true))

        await store.send(.nextButtonTapped)
        #expect(store.state.blocks == nil)
    }

    @MainActor
    @Test
    func nextButtonTapped_withAChoice_pushesTheBlocksPageCarryingThatSource() async throws {
        // FR-022 / FR-024: the chosen source travels with the push, by id and by display name.
        var initial = StartPage.State(sources: threeEntries, hasLoaded: true)
        initial.sources[id: Source.lottoMock.name]?.isSelected = true
        initial.selectedSourceID = Source.lottoMock.name
        let store = store(initial)

        await store.send(.nextButtonTapped) {
            $0.blocks = BlocksPage.State(
                sourceID: Source.lottoMock.name,
                sourceName: Source.lottoMock.displayName
            )
        }
    }

    @MainActor
    @Test
    func nextButtonTapped_twiceInQuickSuccession_pushesExactlyOnce() async throws {
        // FR-023: with tree-based navigation the second assignment replaces the same optional, so a
        // double tap cannot stack two destinations. This test is what keeps that property if the
        // navigation mechanism is ever changed.
        var initial = StartPage.State(sources: threeEntries, hasLoaded: true)
        initial.sources[id: Source.mbnetMock.name]?.isSelected = true
        initial.selectedSourceID = Source.mbnetMock.name
        let store = store(initial)

        let expected = BlocksPage.State(
            sourceID: Source.mbnetMock.name,
            sourceName: Source.mbnetMock.displayName
        )
        await store.send(.nextButtonTapped) { $0.blocks = expected }
        await store.send(.nextButtonTapped)
        #expect(store.state.blocks == expected)
    }

    // MARK: - Returning from the blocks page (US4)

    /// Three sources with `lotto` chosen — the state a person is in when they move forward.
    private var chosenLotto: StartPage.State {
        var state = StartPage.State(sources: threeEntries, hasLoaded: true)
        state.sources[id: Source.lottoMock.name]?.isSelected = true
        state.selectedSourceID = Source.lottoMock.name
        return state
    }

    @MainActor
    @Test
    func dismissingTheBlocksPage_keepsTheChoiceAndTheLoadedList() async throws {
        // FR-029 / FR-031: coming back must not cost the person their choice, or they would re-pick
        // every time they looked at the next step.
        let store = store(chosenLotto)
        let expected = BlocksPage.State(
            sourceID: Source.lottoMock.name,
            sourceName: Source.lottoMock.displayName
        )

        await store.send(.nextButtonTapped) { $0.blocks = expected }
        await store.send(.blocks(.dismiss)) { $0.blocks = nil }

        #expect(store.state.selectedSourceID == Source.lottoMock.name)
        #expect(store.state.sources[id: Source.lottoMock.name]?.isSelected == true)
        #expect(store.state.sources.count == 3)
        #expect(store.state.hasLoaded)

        // FR-031: and it is reachable again, with the same source.
        await store.send(.nextButtonTapped) { $0.blocks = expected }
    }

    @MainActor
    @Test
    func fivePushDismissCycles_endWhereASinglePushWouldHave() async throws {
        // SC-007: repetition must not accumulate anything — no stacked destinations, no drift in the
        // choice, no reset of the list.
        let store = store(chosenLotto)
        let expected = BlocksPage.State(
            sourceID: Source.lottoMock.name,
            sourceName: Source.lottoMock.displayName
        )
        let before = store.state.sources

        for _ in 1...5 {
            await store.send(.nextButtonTapped) { $0.blocks = expected }
            await store.send(.blocks(.dismiss)) { $0.blocks = nil }
        }
        await store.send(.nextButtonTapped) { $0.blocks = expected }

        #expect(store.state.blocks == expected)
        #expect(store.state.selectedSourceID == Source.lottoMock.name)
        #expect(store.state.sources == before)
        #expect(store.state.hasLoaded)
    }

    @MainActor
    @Test
    func reloadAfterReturning_staysLoadedAndKeepsTheChoice() async throws {
        // FR-030 / I7: the reload that follows a return must leave the populated list on screen, which
        // is what `hasLoaded` staying true expresses. If this flips, the view falls back to the loading
        // branch and the person watches their list disappear.
        var initial = chosenLotto
        initial.blocks = nil
        let store = TestStore(initialState: initial) {
            StartPage()
                .dependency(\.blSources, .mock)
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.task)
        await store.receive(\.sourcesResponse) {
            // `.mock` yields mbnet + lotto: the list shrinks, and `lotto` is still present so it stays chosen.
            $0.sources = IdentifiedArrayOf(
                uniqueElements: [Source.mbnetMock, .lottoMock].map { $0.sourceEntryState(now: .fixedNow) }
            )
            $0.sources[id: Source.lottoMock.name]?.isSelected = true
        }
        #expect(store.state.hasLoaded)
        #expect(store.state.selectedSourceID == Source.lottoMock.name)
        #expect(store.state.isNextEnabled)
    }
}

// MARK: - Skipped-records note (spec 005 US2)

extension StartPage_Tests {
    /// `mbnet` as the last sync left it: three records skipped.
    private func entryShowingThreeSkipped() -> SourceEntry.State {
        var entry = seededEntry()
        entry.skippedInLastSync = 3
        return entry
    }

    private func blSources(syncing result: Result<Source, SyncFailure>) -> SourcesBLogic {
        var logic = SourcesBLogic.mock
        logic.fetchFrom = { _ in result }
        return logic
    }

    @MainActor
    @Test
    func task_showsTheStoredSkippedCount() async throws {
        // US2-AS1: after a relaunch the card shows the count the last successful sync stored.
        let skipped = Source(name: "mbnet", displayName: "MBNet Server", lastSync: .fixedNow, recordsCount: 10, lastSyncSkipped: 2)
        var logic = SourcesBLogic.mock
        logic.knownSources = { [skipped, .lottoMock] }
        let store = TestStore(initialState: StartPage.State()) {
            StartPage()
                .dependency(\.blSources, logic)
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.task)
        await store.receive(\.sourcesResponse) {
            $0.sources = [skipped.sourceEntryState(now: .fixedNow), Source.lottoMock.sourceEntryState(now: .fixedNow)]
            $0.hasLoaded = true
        }
        #expect(store.state.sources[id: "mbnet"]?.skippedInLastSync == 2)
    }

    @MainActor
    @Test
    func refresh_success_replacesTheSkippedCount() async throws {
        // US2-AS2: the next successful sync's count replaces the one shown.
        let synced = Source(name: "mbnet", displayName: "MBNet Server", lastSync: .fixedNow, recordsCount: 10, lastSyncSkipped: 1)
        let store = TestStore(initialState: StartPage.State(sources: [entryShowingThreeSkipped()])) {
            StartPage()
                .dependency(\.blSources, blSources(syncing: .success(synced)))
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            $0.sources[id: "mbnet"]?.apply(synced, now: .fixedNow)
        }
        #expect(store.state.sources[id: "mbnet"]?.skippedInLastSync == 1)
    }

    @MainActor
    @Test(arguments: [SyncFailure.serverUnreachable, .cancelled])
    func refresh_thatDoesNotSucceed_keepsTheSkippedCount(_ failure: SyncFailure) async throws {
        // US2-AS4 / FR-006: a failed or cancelled sync leaves the note as it was.
        let store = TestStore(initialState: StartPage.State(sources: [entryShowingThreeSkipped()])) {
            StartPage()
                .dependency(\.blSources, blSources(syncing: .failure(failure)))
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"]?.isRefreshing = false
            if failure != .cancelled {
                $0.sources[id: "mbnet"]?.alert = .syncFailed(failure, sourceName: "MBNet Server", action: .refresh)
            }
        }
        #expect(store.state.sources[id: "mbnet"]?.skippedInLastSync == 3)
    }
}

extension SourceEntry.State {
    /// The same entry with its selection mirror set, so expectations read as one expression.
    fileprivate var chosen: Self {
        var copy = self
        copy.isSelected = true
        return copy
    }
}
