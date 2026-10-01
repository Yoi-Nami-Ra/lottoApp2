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

    /// The kind of sync a card's button offers (spec 008): `fetch` ⇔ the source has never synced successfully
    /// (`lastSync == nil`), `refresh` once it has. Both kinds start the same sync.
    enum SyncAction: Equatable {
        case fetch
        case refresh
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
        /// The count shown in the skipped-records note. `nil` means no note; it is never `0` (spec 005 §3).
        var skippedInLastSync: Int?
        var isRefreshing: Bool = false
        /// Mirrors the parent's `selectedSourceID` so the card can draw itself. The parent is the only
        /// writer — see `StartPage.State.applySelectionRules()`; nothing in this reducer touches it.
        var isSelected: Bool = false
        /// Whether the compact card shows its details (spec 007). Screen state only: the full card ignores it,
        /// it is never persisted, and the parent carries it over a reload so a card doesn't fold away.
        var isExpanded: Bool = false
        @Presents var alert: AlertState<Action.Alert>?

        /// Derived rather than stored, so it can never drift from `lastSync`: the first successful sync
        /// recorded by `apply(_:now:)` turns Fetch into Refresh with no extra write (spec 008 FR-002).
        var syncAction: SyncAction { lastSync == nil ? .fetch : .refresh }
    }

    enum Action {
        case refreshButtonTapped
        case cardTapped
        case disclosureButtonTapped
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

            case .disclosureButtonTapped:
                // Only shows or hides the details: no delegate, so it can never select or refresh (FR-007).
                state.isExpanded.toggle()
                return .none

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension AlertState where Action == SourceEntry.Action.Alert {
    /// The failed-sync alert, worded for why it failed (spec 004 FR-003, contracts §4).
    static func syncFailed(_ failure: SyncFailure, sourceName: String) -> AlertState {
        AlertState {
            TextState(.syncFailedTitle)
        } message: {
            TextState(LocalizedStringResource.syncFailedMessage(failure, sourceName: sourceName))
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
            recordsCount: recordsCount,
            skippedInLastSync: skippedNoteCount
        )
    }

    /// A note only for a sync that actually skipped something: never synced and 0 both mean no note (FR-009).
    fileprivate var skippedNoteCount: Int? {
        guard let lastSyncSkipped, lastSyncSkipped > 0 else { return nil }
        return lastSyncSkipped
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
        skippedInLastSync = source.skippedNoteCount
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

    fileprivate static func syncFailedMessage(_ failure: SyncFailure, sourceName name: String) -> Self {
        switch failure {
        case .offline:
            "Your device appears to be offline. Check your connection and try again."
        case .serverUnreachable:
            "Couldn't reach \(name). Try again later."
        case .serverError(let status) where status >= .serverSideErrorStatus:
            "\(name) reported a problem (error \(status)). Try again later."
        case .serverError(let status):
            "\(name) answered with error \(status). Its address may have changed, so retrying won't help until the app is updated."
        case .unreadableData:
            "\(name) sent data in a format this app doesn't recognise. Retrying won't help until the app is updated."
        case .sourceUnavailable:
            "\(name) is no longer available."
        case .storageFailure:
            "The downloaded draws couldn't be saved on this device. Free up some space and try again."
        // `cancelled` never reaches an alert (StartPage drops it); the general wording is only a fallback.
        case .unknown, .cancelled:
            "Couldn't refresh \(name). Try again."
        }
    }
}

extension Int {
    /// 5xx: the server's own trouble, which retrying later can fix (spec 004 FR-004).
    fileprivate static let serverSideErrorStatus = 500
}
