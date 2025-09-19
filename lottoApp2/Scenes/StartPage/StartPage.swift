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
            case .sources(_):
                return .none
            }
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
