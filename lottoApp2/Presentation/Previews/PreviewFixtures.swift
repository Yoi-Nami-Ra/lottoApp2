//
//  PreviewFixtures.swift
//  lottoApp2
//
//  Sample data for `#Preview`s (Principle V requires previews, and previews compile into the app target).
//  Kept here rather than in Domain so the inner layer carries no UI-support fixtures.
//

import Dependencies
import Foundation

extension SourcesBLogic {
    /// Business logic backed by in-memory sample data, for SwiftUI previews.
    static let previewMock = SourcesBLogic(
        knownSources: { Source.mocks },
        fetchFrom: { name in
            guard let source = Source.mocks.first(where: { $0.name == name })
            else { return .failure(.somethingWentWrong) }
            return .success(source)
        }
    )
}

nonisolated extension Source {
    static let mbnetMock: Source = .init(
        name: "mbnet",
        displayName: "MBNet Server",
        lastSync: .now.addingTimeInterval(-100_000),
        recordsCount: 120,
        latestRecord: .now.addingTimeInterval(-180_000),
        firstRecord: Date(timeIntervalSince1970: 18_223_210)
    )

    static let lottoMock: Source = .init(
        name: "lotto",
        displayName: "Lotto Server",
        lastSync: .now.addingTimeInterval(-432_000),
        recordsCount: 110,
        latestRecord: .now.addingTimeInterval(-600_000),
        firstRecord: Date(timeIntervalSince1970: 18_223_210)
    )

    static let neverSyncedMock: Source = .init(
        name: "eurojackpot",
        displayName: "EuroJackpot Server"
    )

    static let mocks: [Source] = [.mbnetMock, .lottoMock, .neverSyncedMock]
}
