//
//  StartPageFeature.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/07/2025.
//


import ComposableArchitecture
import Dependencies
import SwiftUI

@Reducer
struct StartPageFeature {
    @ObservableState
    struct State: Equatable {
        var sources: [SourceEntry.DisplayData] = []
    }

    enum Action {
        case task
        case sourcesResponse([Source])
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
                state.sources = sources.map(\.displayData)
                return .none
            }
        }
    }
}

extension Source {
    var displayData: SourceEntry.DisplayData {
        .init(
            name: displayName,
            lastSync: lastSync.formatted(date: .abbreviated, time: .shortened),
            lastSyncSeverity: lastSync.toSeverity,
            firstRecordDate: firstRecrd.formatted(date: .abbreviated, time: .omitted),
            lastRecordDate: latestRecord.formatted(date: .abbreviated, time: .omitted),
            recordsCount: String(recordCount)
        )
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
