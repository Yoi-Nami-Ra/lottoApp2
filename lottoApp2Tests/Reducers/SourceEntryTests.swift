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
                id: "a",
                name: "b",
                lastSync: .now,
                firstRecordDate: .now,
                lastRecordDate: .now,
                recordsCount: 1
            )
        ) {
            SourceEntry()
        }

        await store.send(.refreshButtonTapped)
        await store.receive(\.delegate.refreshRequested)
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
            lastSync: .now,
            firstRecordDate: .now,
            lastRecordDate: .now,
            recordsCount: 100
        )
        initialState.alert = .syncFailed

        let store = TestStore(initialState: initialState) {
            SourceEntry()
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }
}
