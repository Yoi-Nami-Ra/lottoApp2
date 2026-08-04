//
//  StartPage.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/07/2025.
//


import ComposableArchitecture
import Dependencies
import SwiftUI

@Reducer
struct StartPage {
    @ObservableState
    struct State: Equatable {
        var sources: IdentifiedArrayOf<SourceEntry.State> = []
    }

    enum Action {
        case task
        case sourcesResponse([Source])
        case refreshResponse(id: SourceEntry.State.ID, Result<Source, SourcesBLogic.Error>)
        case sources(IdentifiedActionOf<SourceEntry>)
    }

    private enum CancelID: nonisolated Hashable, Sendable {
        case load
        case refresh(SourceEntry.State.ID)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            @Dependency(\.blSources) var blSources
            @Dependency(\.date) var date

            switch action {
            case .task:
                return .run { send in
                    let sources = await blSources.knownSources()
                    await send(.sourcesResponse(sources))
                }
                .cancellable(id: CancelID.load, cancelInFlight: true)

            case .sourcesResponse(let sources):
                let now = date.now
                state.sources = IdentifiedArrayOf(
                    uniqueElements: sources.map { source in
                        var entry = source.sourceEntryState(now: now)
                        // Carry over transient UI state: a reload must not clear an in-flight refresh (which
                        // would drop the child's FR-020 guard and allow a second concurrent sync) or dismiss
                        // a failure alert the user hasn't seen yet.
                        if let existing = state.sources[id: entry.id] {
                            entry.isRefreshing = existing.isRefreshing
                            entry.alert = existing.alert
                        }
                        return entry
                    }
                )
                return .none

            case let .sources(.element(id: id, action: .delegate(.refreshRequested))):
                // FR-020: the child guards against re-entrancy; here we own the fetch and drive `isRefreshing`.
                state.sources[id: id]?.isRefreshing = true
                return .run { send in
                    await send(.refreshResponse(id: id, blSources.fetchFrom(id)))
                }
                .cancellable(id: CancelID.refresh(id), cancelInFlight: true)

            case let .refreshResponse(id: id, response):
                // The entry can be gone if the list reloaded mid-flight. Bail out rather than writing through
                // the id-subscript, which would append a ghost row and silently swallow the alert.
                guard state.sources[id: id] != nil else { return .none }
                state.sources[id: id]?.isRefreshing = false
                switch response {
                case .failure:
                    // FR-021: surface a failure alert; leave prior analytics unchanged.
                    state.sources[id: id]?.alert = .syncFailed
                case .success(let result):
                    state.sources[id: id]?.apply(result, now: date.now)
                }
                return .none

            case .sources:
                return .none
            }
        }
        .forEach(\.sources, action: \.sources) {
            SourceEntry()
        }
    }
}

extension Int {
    var days: TimeInterval {
        TimeInterval(self) * 24.hours
    }
    var hours: TimeInterval {
        TimeInterval(self) * 60.minutes
    }
    var minutes: TimeInterval {
        TimeInterval(self) * 60.seconds
    }
    var seconds: TimeInterval { .init(self) }
}
