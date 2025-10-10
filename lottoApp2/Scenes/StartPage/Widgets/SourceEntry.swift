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
        let lastSync: Date
        var lastSyncSeverity: SyncSeverity { lastSync.toSeverity }
        let firstRecordDate: Date
        let lastRecordDate: Date
        let recordsCount: Int
        var isRefreshing: Bool = false
    }

    enum Action {
        case refresh
        case refreshResponse(Result<Source, SourcesBLogic.Error>)
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
                switch response {
                case .failure:
                    break // TODO: implement unhappy path
                case .success(let result):
                    state = result.sourceEntryState
                }
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
            lastSync: lastSync, //.formatted(date: .abbreviated, time: .shortened),
            firstRecordDate: firstRecrd, //.formatted(date: .abbreviated, time: .omitted),
            lastRecordDate: latestRecord, //.formatted(date: .abbreviated, time: .omitted),
            recordsCount: recordCount
        )
    }
}

extension Date {
    var toSeverity: SourceEntry.SyncSeverity {
        let interval = abs(self.timeIntervalSinceNow)
        if interval < 2.days  {
            return .low
        } else if interval < 4.days {
            return .medium
        }
        return .high
    }
}
