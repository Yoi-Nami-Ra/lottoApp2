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
    func action_refresh() async throws {
        let store = TestStore(
            initialState: SourceEntry.State(
                id: "a",
                name: "b",
                lastSync: .now,
                firstRecordDate: .now,
                lastRecordDate: .now,
                recordsCount: 1
            )
        ) {
            SourceEntry()
                .dependency(\.blSources, .mock)
        }

        await store.send(.refresh) {
            $0.isRefreshing = true
        }
        await store.receive(\.refreshResponse) { state in
            state.id = Source.mbnetMock.name
            state.name = Source.mbnetMock.displayName
            state.lastSync = Source.mbnetMock.lastSync
            state.firstRecordDate = Source.mbnetMock.firstRecrd
            state.lastRecordDate = Source.mbnetMock.latestRecord
            state.recordsCount = Source.mbnetMock.recordCount
            state.isRefreshing = false
        }
    }
}
