//
//  SourceEntryView.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/09/2025.
//

import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct SourceEntry {
    enum SyncSeverity {
        case low
        case medium
        case high
    }

    @ObservableState
    struct State: Equatable, Identifiable {
        let id: String
        let name: String
        let lastSync: String
        let lastSyncSeverity: SyncSeverity
        let firstRecordDate: String
        let lastRecordDate: String
        let recordsCount: String
        var isRefreshing: Bool = false
    }

    enum Action {
        case refresh
        case refreshResponse(Source)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            @Dependency(\.blSources) var blSources

            switch action {
            case .refresh:
                state.isRefreshing = true
                return .run { [id = state.id] send in
                    await send(
                        .refreshResponse(blSources.fetchFrom(id))
                    )
                }
            case .refreshResponse(let response):
                state = response.sourceEntryState
                return .none
            }
        }
    }
}

extension Source {
    var sourceEntryState: SourceEntry.State {
        .init(
            id: name,
            name: displayName,
            lastSync: lastSync.formatted(date: .abbreviated, time: .shortened),
            lastSyncSeverity: lastSync.toSeverity,
            firstRecordDate: firstRecrd.formatted(date: .abbreviated, time: .omitted),
            lastRecordDate: latestRecord.formatted(date: .abbreviated, time: .omitted),
            recordsCount: String(recordCount)
        )
    }
}
