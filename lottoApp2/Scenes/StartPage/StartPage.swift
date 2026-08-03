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

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            @Dependency(\.blSources) var blSources

            switch action {
            case .task:
                return .run { send in
                    let sources = await blSources.knownSources()
                    await send(.sourcesResponse(sources))
                }
            case .sourcesResponse(let sources):
                state.sources = .init(uniqueElements: sources.map(\.sourceEntryState), id: \.id)
                return .none

            case let .sources(.element(id: id, action: .delegate(.refreshRequested))):
                // FR-020: the child guards against re-entrancy; here we own the fetch and drive `isRefreshing`.
                state.sources[id: id]?.isRefreshing = true
                return .run { send in
                    await send(.refreshResponse(id: id, blSources.fetchFrom(id)))
                }

            case let .refreshResponse(id: id, response):
                state.sources[id: id]?.isRefreshing = false
                switch response {
                case .failure:
                    // FR-021: surface a failure alert; leave prior analytics unchanged.
                    state.sources[id: id]?.alert = .syncFailed
                case .success(let result):
                    state.sources[id: id] = result.sourceEntryState
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
