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
        case none
    }

    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String
        var name: String
        var lastSync: Date?
        var lastSyncSeverity: SyncSeverity { lastSync?.toSeverity ?? .none }
        var firstRecordDate: Date?
        var lastRecordDate: Date?
        var recordsCount: Int?
        var isRefreshing: Bool = false
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action {
        case refreshButtonTapped
        case delegate(Delegate)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Delegate: Equatable {
            case refreshRequested
        }
        enum Alert: Equatable {}
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .refreshButtonTapped:
                // FR-020: ignore taps while a sync is already in progress (no second concurrent sync).
                // The parent (StartPage) owns the fetch; forward the intent and let it drive `isRefreshing`.
                guard state.isRefreshing == false else { return .none }
                return .send(.delegate(.refreshRequested))
            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == SourceEntry.Action.Alert {
    static var syncFailed: AlertState {
        AlertState {
            TextState("Sync failed")
        } message: {
            TextState("Couldn't refresh this source. Check your connection and try again.")
        }
    }
}

extension Source {
    var sourceEntryState: SourceEntry.State {
        .init(
            id: name,
            name: displayName,
            lastSync: lastSync,
            firstRecordDate: firstRecrd,
            lastRecordDate: latestRecord,
            recordsCount: recordsCount
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
