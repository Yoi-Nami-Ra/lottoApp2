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
    /// How overdue a source's last sync is. `notSynced` (rather than `none`) so it never reads as
    /// `Optional.none` at a use site.
    enum SyncSeverity: Equatable {
        case low
        case medium
        case high
        case notSynced
    }

    @ObservableState
    struct State: Equatable, Identifiable {
        let id: String
        var name: String
        var lastSync: Date?
        /// Stored, not computed from the wall clock: the reducer derives it from `@Dependency(\.date)` so it
        /// is deterministic, assertable, and re-derived whenever the entry is refreshed.
        var lastSyncSeverity: SyncSeverity = .notSynced
        var firstRecordDate: Date?
        var lastRecordDate: Date?
        var recordsCount: Int?
        var isRefreshing: Bool = false
        /// Mirrors the parent's `selectedSourceID` so the card can draw itself. The parent is the only
        /// writer — see `StartPage.State.applySelectionRules()`; nothing in this reducer touches it.
        var isSelected: Bool = false
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action {
        case refreshButtonTapped
        case cardTapped
        case delegate(Delegate)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Delegate: Equatable {
            case refreshRequested
            case selectionRequested
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

            case .cardTapped:
                // No guard, deliberately: unlike a refresh there is nothing to be re-entrant about, and
                // FR-019 makes a source choosable whatever its data or sync state. Whether the choice may
                // move is a list-level question, so it belongs to the parent.
                return .send(.delegate(.selectionRequested))
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
            TextState(.syncFailedTitle)
        } message: {
            TextState(.syncFailedMessage)
        }
    }
}

extension SourceEntry.SyncSeverity {
    /// How stale `lastSync` is as of `now`. Thresholds are days since the last successful sync.
    init(lastSync: Date, now: Date) {
        let interval = abs(now.timeIntervalSince(lastSync))
        if interval < .lowSeverityLimit {
            self = .low
        } else if interval < .mediumSeverityLimit {
            self = .medium
        } else {
            self = .high
        }
    }
}

extension Source {
    /// Maps the Domain entity onto child state. `now` is injected rather than read from the clock so sync
    /// severity stays deterministic (Principle IV).
    func sourceEntryState(now: Date) -> SourceEntry.State {
        .init(
            id: name,
            name: displayName,
            lastSync: lastSync,
            lastSyncSeverity: lastSync.map { .init(lastSync: $0, now: now) } ?? .notSynced,
            firstRecordDate: firstRecord,
            lastRecordDate: latestRecord,
            recordsCount: recordsCount
        )
    }
}

extension SourceEntry.State {
    /// Refreshes the displayed analytics from a freshly fetched `Source` **in place**, so the entry keeps its
    /// identity. Assigning a whole new element through `IdentifiedArray`'s id-subscript would trap if the ids
    /// ever diverged ("Element identity must remain constant").
    mutating func apply(_ source: Source, now: Date) {
        name = source.displayName
        lastSync = source.lastSync
        lastSyncSeverity = source.lastSync.map { .init(lastSync: $0, now: now) } ?? .notSynced
        firstRecordDate = source.firstRecord
        lastRecordDate = source.latestRecord
        recordsCount = source.recordsCount
        alert = nil
    }
}

// MARK: - Resources
extension TimeInterval {
    fileprivate static let lowSeverityLimit: Self = 2.days
    fileprivate static let mediumSeverityLimit: Self = 4.days
}

extension LocalizedStringResource {
    fileprivate static let syncFailedTitle: Self = "Sync failed"
    fileprivate static let syncFailedMessage: Self =
        "Couldn't refresh this source. Check your connection and try again."
}
