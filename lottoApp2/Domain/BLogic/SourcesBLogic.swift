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

extension SourcesBLogic: nonisolated DependencyKey {
    nonisolated static let liveValue = SourcesBLogic(
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
