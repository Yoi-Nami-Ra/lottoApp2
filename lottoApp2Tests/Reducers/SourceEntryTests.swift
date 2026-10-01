//
//  SourceEntryTests.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/09/2025.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import lottoApp2

struct SourceEntry_Tests {

    @MainActor
    @Test
    func action_refreshButtonTapped_emitsDelegate() async throws {
        // The child owns no fetch: a tap forwards the intent to the parent as a delegate action.
        let store = TestStore(
            initialState: SourceEntry.State(
                id: "mbnet",
                name: "MBNet Server",
                lastSync: .fixedNow,
                lastSyncSeverity: .low,
                firstRecordDate: .fixedNow,
                lastRecordDate: .fixedNow,
                recordsCount: 1
            )
        ) {
            SourceEntry()
        }

        await store.send(.refreshButtonTapped)
        await store.receive(\.delegate.refreshRequested)
        // Exhaustive by construction: a second delegate here (e.g. a selection intent) would fail this
        // test, which is what keeps FR-012 — Refresh never changes which source is chosen.
    }

    @MainActor
    @Test
    func action_cardTapped_emitsSelectionDelegate() async throws {
        // FR-011: the child owns no decision. Whether the tap may change the choice is a list-level
        // question, so the intent goes to the parent and the child mutates nothing.
        let store = TestStore(
            initialState: SourceEntry.State(
                id: "mbnet",
                name: "MBNet Server",
                lastSync: .fixedNow,
                lastSyncSeverity: .low,
                firstRecordDate: .fixedNow,
                lastRecordDate: .fixedNow,
                recordsCount: 1
            )
        ) {
            SourceEntry()
        }

        await store.send(.cardTapped)
        await store.receive(\.delegate.selectionRequested)
    }

    @MainActor
    @Test
    func action_cardTapped_isNotGuardedWhileRefreshing() async throws {
        // FR-017 / FR-019: unlike Refresh, choosing has no re-entrancy hazard and no data prerequisite,
        // so a syncing source stays choosable.
        let store = TestStore(
            initialState: SourceEntry.State(
                id: "mbnet",
                name: "MBNet Server",
                lastSync: nil,
                lastSyncSeverity: .notSynced,
                firstRecordDate: nil,
                lastRecordDate: nil,
                recordsCount: nil,
                isRefreshing: true
            )
        ) {
            SourceEntry()
        }

        await store.send(.cardTapped)
        await store.receive(\.delegate.selectionRequested)
    }

    @MainActor
    @Test
    func action_refreshButtonTapped_guardedWhileRefreshing() async throws {
        // FR-020: a tap while already refreshing forwards nothing (no delegate, no state change).
        let store = TestStore(
            initialState: SourceEntry.State(id: "mbnet", name: "MBNet Server", isRefreshing: true)
        ) {
            SourceEntry()
        }

        await store.send(.refreshButtonTapped)
    }

    @MainActor
    @Test
    func action_alertDismiss_clearsAlert() async throws {
        // SC-010: dismissing the failure alert clears it (the parent sets it; the child presents it).
        var initialState = SourceEntry.State(
            id: "mbnet",
            name: "MBNet Server",
            lastSync: .fixedNow,
            lastSyncSeverity: .low,
            firstRecordDate: .fixedNow,
            lastRecordDate: .fixedNow,
            recordsCount: 100
        )
        initialState.alert = .syncFailed(.serverUnreachable, sourceName: "MBNet Server", action: .refresh)

        let store = TestStore(initialState: initialState) {
            SourceEntry()
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    @MainActor
    @Test
    func apply_refreshesAnalyticsAndClearsAlert() async throws {
        // The in-place update keeps the entry's identity (so `IdentifiedArray` can't trap) while refreshing
        // every displayed field and dismissing a stale failure alert.
        var state = SourceEntry.State(id: "mbnet", name: "Old Name", recordsCount: 1)
        state.alert = .syncFailed(.serverUnreachable, sourceName: "MBNet Server", action: .refresh)

        state.apply(.refreshedMbnetMock, now: .fixedNow)

        #expect(state.id == "mbnet")
        #expect(state.name == "MBNet Server")
        #expect(state.recordsCount == 7380)
        #expect(state.lastSync == Source.refreshedMbnetMock.lastSync)
        #expect(state.firstRecordDate == Source.refreshedMbnetMock.firstRecord)
        #expect(state.lastRecordDate == Source.refreshedMbnetMock.latestRecord)
        #expect(state.lastSyncSeverity == .low)
        #expect(state.alert == nil)
    }

    // MARK: - Skipped-records note (spec 005 contracts §3)

    private static func source(skipped: Int?) -> Source {
        Source(name: "mbnet", displayName: "MBNet Server", lastSync: .fixedNow, recordsCount: 7380, lastSyncSkipped: skipped)
    }

    @Test(arguments: [
        (Int?.none, Int?.none),
        (0, nil),
        (1, 1),
        (1204, 1204),
    ])
    func sourceEntryState_showsTheNoteOnlyForAPositiveCount(_ skipped: Int?, _ expected: Int?) {
        let state = Self.source(skipped: skipped).sourceEntryState(now: .fixedNow)

        #expect(state.skippedInLastSync == expected)
    }

    @Test
    func apply_setsTheNote_andAZeroCountClearsIt() {
        // FR-005: each successful sync replaces the note; one that skipped nothing removes it.
        var state = Self.source(skipped: nil).sourceEntryState(now: .fixedNow)

        state.apply(Self.source(skipped: 3), now: .fixedNow)
        #expect(state.skippedInLastSync == 3)

        state.apply(Self.source(skipped: 0), now: .fixedNow)
        #expect(state.skippedInLastSync == nil)
    }

    // MARK: - Fetch or Refresh (spec 008 contracts §1)

    @Test
    func sourceEntryState_neverSynced_offersFetch() {
        // FR-001: a source with no successful sync offers to fetch its data.
        #expect(Source.neverSyncedMock.sourceEntryState(now: .fixedNow).syncAction == .fetch)
    }

    @Test
    func sourceEntryState_synced_offersRefresh() {
        #expect(Self.source(skipped: nil).sourceEntryState(now: .fixedNow).syncAction == .refresh)
    }

    @Test
    func apply_firstSuccessfulSync_turnsFetchIntoRefresh() {
        // FR-002: the first successful sync flips the button in place, with no reload or relaunch.
        var state = Source.neverSyncedMock.sourceEntryState(now: .fixedNow)

        state.apply(.refreshedMbnetMock, now: .fixedNow)

        #expect(state.syncAction == .refresh)
    }

    @Test
    func apply_firstSyncWithNoDraws_stillTurnsIntoRefresh() {
        // Edge case: the kind follows whether a sync succeeded, not how many records it stored.
        var state = Source.neverSyncedMock.sourceEntryState(now: .fixedNow)
        let emptySync = Source(name: "eurojackpot", displayName: "EuroJackpot Server", lastSync: .fixedNow, recordsCount: 0)

        state.apply(emptySync, now: .fixedNow)

        #expect(state.syncAction == .refresh)
    }

    // MARK: - Missing records estimate (spec 009 contracts §3)

    /// Six draws a fortnight: ⌊6/14 × days⌋ missing — 1 at 2.5 days, 2 at 5, 3 at 7, 5 at 12.
    private static func source(
        lastSync: Date? = .fixedNow,
        latestDaysAgo: Double? = nil,
        cadence: DrawCadence? = DrawCadence(drawsInWindow: 6)
    ) -> Source {
        Source(
            name: "mbnet", displayName: "MBNet Server", lastSync: lastSync, recordsCount: 7380,
            latestRecord: latestDaysAgo.map { Date.fixedNow.addingTimeInterval(-$0 * 86_400) },
            cadence: cadence
        )
    }

    @Test(arguments: [
        (1.0, 0, SourceEntry.SyncSeverity.low),
        (2.5, 1, .medium),
        (5.0, 2, .high),
        (12.0, 5, .high),
    ])
    func theEstimateDecidesTheSeverity(_ latestDaysAgo: Double, _ missing: Int, _ severity: SourceEntry.SyncSeverity) {
        // FR-005: 0 → green, 1 → yellow, 2+ → red — here with a sync seconds ago, which the day rule calls green.
        let state = Self.source(latestDaysAgo: latestDaysAgo).sourceEntryState(now: .fixedNow)

        #expect(state.missingEstimate == missing)
        #expect(state.lastSyncSeverity == severity)
    }

    @Test
    func noMissingDraws_isGreenHoweverOldTheSync() {
        // US2-AS1: a source synced 10 days ago whose latest draw was yesterday is complete.
        let state = Self.source(lastSync: .fixedNow.addingTimeInterval(-10 * 86_400), latestDaysAgo: 1)
            .sourceEntryState(now: .fixedNow)

        #expect(state.missingEstimate == 0)
        #expect(state.lastSyncSeverity == .low)
    }

    @Test(arguments: [
        (0.0, SourceEntry.SyncSeverity.low),
        (2.0, .medium),
        (4.0, .high),
    ])
    func withoutACadence_theDayRuleStillApplies(_ syncDaysAgo: Double, _ severity: SourceEntry.SyncSeverity) {
        // FR-006 / SC-003: no estimate, no change — the old thresholds, to the second.
        let state = Self.source(
            lastSync: .fixedNow.addingTimeInterval(-syncDaysAgo * 86_400), latestDaysAgo: 30, cadence: nil
        ).sourceEntryState(now: .fixedNow)

        #expect(state.missingEstimate == nil)
        #expect(state.lastSyncSeverity == severity)
    }

    @Test
    func aCadenceWithoutALatestRecord_fallsBackToTheDayRule() {
        let state = Self.source(lastSync: .fixedNow.addingTimeInterval(-5 * 86_400))
            .sourceEntryState(now: .fixedNow)

        #expect(state.missingEstimate == nil)
        #expect(state.lastSyncSeverity == .high)
    }

    @Test
    func aNeverSyncedSource_staysNotSynced() {
        let state = Self.source(lastSync: nil, latestDaysAgo: 30).sourceEntryState(now: .fixedNow)

        #expect(state.missingEstimate == nil)
        #expect(state.lastSyncSeverity == .notSynced)
    }

    @Test
    func apply_recomputesTheEstimateAndTheSeverity() {
        // FR-009 / US2-AS6: a sync that brings the missing draws in turns the card green again.
        var state = Self.source(latestDaysAgo: 7).sourceEntryState(now: .fixedNow)
        #expect(state.missingEstimate == 3)
        #expect(state.lastSyncSeverity == .high)

        state.apply(Self.source(latestDaysAgo: 0.5), now: .fixedNow)

        #expect(state.missingEstimate == 0)
        #expect(state.lastSyncSeverity == .low)
    }

    // MARK: - Compact card details (spec 007 contracts §1)

    @MainActor
    @Test
    func action_disclosureButtonTapped_togglesExpanded() async throws {
        // FR-007: the chevron only shows or hides the details. Exhaustive by construction: a delegate here
        // (a selection or a refresh) would fail the test, which is what keeps US2-AS4.
        let store = TestStore(initialState: Self.source(skipped: nil).sourceEntryState(now: .fixedNow)) {
            SourceEntry()
        }

        await store.send(.disclosureButtonTapped) {
            $0.isExpanded = true
        }
        await store.send(.disclosureButtonTapped) {
            $0.isExpanded = false
        }
    }

    @Test
    func sourceEntryState_startsCollapsed() {
        // FR-010: every card starts collapsed, which is also what a relaunch gives, since nothing stores it.
        #expect(Source.mbnetMock.sourceEntryState(now: .fixedNow).isExpanded == false)
    }

    @Test
    func apply_keepsExpanded() {
        // FR-010: a finished sync refreshes the analytics in place without folding the card away.
        var state = Self.source(skipped: nil).sourceEntryState(now: .fixedNow)
        state.isExpanded = true

        state.apply(.refreshedMbnetMock, now: .fixedNow)

        #expect(state.isExpanded)
    }
}

// MARK: - Failure messages (spec 004)

extension SourceEntry_Tests {
    /// Every kind the card can show: the 7 sync failure kinds, with the server error split by range (FR-004).
    nonisolated static let shownFailures: [SyncFailure] = [
        .offline, .serverUnreachable, .serverError(status: 503), .serverError(status: 404),
        .unreadableData, .sourceUnavailable, .storageFailure, .unknown,
    ]

    @Test
    func everyShownFailure_hasItsOwnMessage_underTheSameTitle() {
        // SC-001 / FR-003: 8 distinct messages; the title stays "Sync failed" for all of them.
        let alerts = Self.shownFailures.map { AlertState.syncFailed($0, sourceName: "MBNet Server", action: .refresh) }

        for (i, a) in alerts.enumerated() {
            for b in alerts[(i + 1)...] {
                #expect(a.message != b.message, "\(String(describing: a.message)) is shared")
            }
            #expect(a.title == alerts[0].title)
            #expect(a.message != nil)
        }
    }

    @Test
    func syncFailedFallback_isWordedForTheAction() {
        // Spec 008 FR-007: only the general-purpose fallback names the kind of sync that failed.
        let fetch = AlertState.syncFailed(.unknown, sourceName: "MBNet Server", action: .fetch)
        let refresh = AlertState.syncFailed(.unknown, sourceName: "MBNet Server", action: .refresh)

        #expect(fetch.message == TextState("Couldn't fetch MBNet Server. Try again."))
        #expect(refresh.message == TextState("Couldn't refresh MBNet Server. Try again."))
    }

    @Test
    func everyOtherFailure_readsTheSameForFetchAndRefresh() {
        // Spec 008 FR-007: the per-failure messages (spec 004) don't depend on the kind of sync.
        for failure in Self.shownFailures where failure != .unknown {
            let fetch = AlertState.syncFailed(failure, sourceName: "MBNet Server", action: .fetch)
            let refresh = AlertState.syncFailed(failure, sourceName: "MBNet Server", action: .refresh)
            #expect(fetch.message == refresh.message, "\(failure) should not depend on the sync kind")
        }
    }

    @Test
    func messagesThatReferToTheSource_nameIt() {
        // FR-005: the sentence names the source where it refers to it — and only there.
        // Offline and storage failures are about this device, not the source.
        let aboutTheDevice: [SyncFailure] = [.offline, .storageFailure]

        for failure in Self.shownFailures {
            let a = AlertState.syncFailed(failure, sourceName: "Source A", action: .refresh).message
            let b = AlertState.syncFailed(failure, sourceName: "Source B", action: .refresh).message
            if !aboutTheDevice.contains(failure) {
                #expect(a != b, "\(failure) should name the source")
            } else {
                #expect(a == b, "\(failure) should not depend on the source")
            }
        }
    }
}
