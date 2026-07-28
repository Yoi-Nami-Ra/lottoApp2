//
//  SourcesBLogic.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 07/07/2025.
//

import Dependencies
import Foundation

nonisolated struct SourcesBLogic: Sendable {
    enum Error: Swift.Error {
        case somethingWentWrong
    }

    var knownSources: @Sendable () async -> [Source]
    var fetchFrom: @Sendable (String) async -> Result<Source, Error>
}

extension SourcesBLogic: DependencyKey {
    static let liveValue = SourcesBLogic(
        knownSources: {
            @Dependency(\.sourcesRepo) var repo
            return await repo.listKnownSources()
        },
        fetchFrom: { source in
            @Dependency(\.sourcesRepo) var repo
            return await repo.fetchAndSaveDataFrom(source).mapError { _ in .somethingWentWrong } //TODO: re-implement
        }
    )
}

extension DependencyValues {
  nonisolated var blSources: SourcesBLogic {
    get { self[SourcesBLogic.self] }
    set { self[SourcesBLogic.self] = newValue }
  }
}

extension Array where Element == Source {
    fileprivate func updated(with list: [Source]) -> [Source] {
        map { element in list.first { $0.name == element.name } ?? element }
    }
}

extension Source {
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
}
