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
        }
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
            $0.sources[id: "mbnet"]?.alert = .syncFailed
        }
        #expect(store.state.sources[id: "mbnet"]?.recordsCount == 100)
    }

    @MainActor
    @Test
    func sourcesResponse_preservesInFlightRefreshAndAlert() async throws {
        // FR-020 regression: a reload landing mid-sync must not clear `isRefreshing` (which would drop the
        // child's re-entrancy guard and let a second concurrent sync start) or dismiss an unseen alert.
        var refreshing = seededEntry(isRefreshing: true)
        refreshing.alert = .syncFailed

        let store = TestStore(initialState: StartPage.State(sources: [refreshing])) {
            StartPage()
                .dependency(\.date, .constant(.fixedNow))
        }

        await store.send(.sourcesResponse([.mbnetMock])) {
            $0.sources[id: "mbnet"]?.apply(.mbnetMock, now: .fixedNow)
            $0.sources[id: "mbnet"]?.isRefreshing = true
            $0.sources[id: "mbnet"]?.alert = .syncFailed
        }
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
        await store.send(.refreshResponse(id: "mbnet", .failure(.somethingWentWrong)))
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
                $0.sources = [source.sourceEntryState(now: now)]
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
            $0.sources = [Source.neverSyncedMock.sourceEntryState(now: .fixedNow)]
        }
        #expect(store.state.sources.first?.lastSyncSeverity == .notSynced)
    }
}
