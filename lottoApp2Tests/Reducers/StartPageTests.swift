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

    @MainActor
    @Test
    func action_task() async throws {
        let store = TestStore(initialState: StartPage.State()) {
            StartPage()
                .dependency(\.blSources, .mock)
        }
        await store.send(.task)
        await store.receive(\.sourcesResponse)
        {
            $0.sources = [
                SourceEntry.State(
                    id: Source.mbnetMock.name,
                    name: Source.mbnetMock.displayName,
                    lastSync: Source.mbnetMock.lastSync,
                    firstRecordDate: Source.mbnetMock.firstRecrd,
                    lastRecordDate: Source.mbnetMock.latestRecord,
                    recordsCount: Source.mbnetMock.recordsCount,
                ),
                SourceEntry.State(
                    id: Source.lottoMock.name,
                    name: Source.lottoMock.displayName,
                    lastSync: Source.lottoMock.lastSync,
                    firstRecordDate: Source.lottoMock.firstRecrd,
                    lastRecordDate: Source.lottoMock.latestRecord,
                    recordsCount: Source.lottoMock.recordsCount,
                ),
            ]
        }
    }

    @MainActor
    @Test
    func refresh_success_drivesRefreshingAndReplacesEntry() async throws {
        // A child refresh tap forwards a delegate; the parent owns the fetch, drives `isRefreshing`,
        // and replaces the entry with the fetched analytics.
        let store = TestStore(
            initialState: StartPage.State(sources: [
                SourceEntry.State(
                    id: "mbnet",
                    name: "MBNet Server",
                    lastSync: .now,
                    firstRecordDate: .now,
                    lastRecordDate: .now,
                    recordsCount: 100
                )
            ])
        ) {
            StartPage()
                .dependency(\.blSources, .mock)
        }

        await store.send(.sources(.element(id: "mbnet", action: .refreshButtonTapped)))
        await store.receive(\.sources[id: "mbnet"].delegate.refreshRequested) {
            $0.sources[id: "mbnet"]?.isRefreshing = true
        }
        await store.receive(\.refreshResponse) {
            $0.sources[id: "mbnet"] = Source.mbnetMock.sourceEntryState
        }
    }

    @MainActor
    @Test
    func refresh_failure_presentsAlertAndKeepsAnalytics() async throws {
        // FR-021 / SC-004: a failed fetch raises the entry's alert and leaves prior analytics intact.
        let store = TestStore(
            initialState: StartPage.State(sources: [
                SourceEntry.State(
                    id: "mbnet",
                    name: "MBNet Server",
                    lastSync: .now,
                    firstRecordDate: .now,
                    lastRecordDate: .now,
                    recordsCount: 100
                )
            ])
        ) {
            StartPage()
                .dependency(\.blSources, .failureMock)
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
}
