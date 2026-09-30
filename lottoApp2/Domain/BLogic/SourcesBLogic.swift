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
    /// The source's draws for a run, with the data state they were read at (spec 003 contracts §3).
    var gameFor: @Sendable (String) async -> Result<SourceSnapshot, Error>
    /// The source's current data state; `nil` means the source is unavailable.
    var dataStateFor: @Sendable (String) async -> SourceDataState?
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
        },
        gameFor: { source in
            @Dependency(\.sourcesRepo) var repo
            return await repo.gameFor(source).mapError { _ in .somethingWentWrong }
        },
        dataStateFor: { source in
            @Dependency(\.sourcesRepo) var repo
            return await repo.dataStateFor(source)
        }
    )
}

extension DependencyValues {
  nonisolated var blSources: SourcesBLogic {
    get { self[SourcesBLogic.self] }
    set { self[SourcesBLogic.self] = newValue }
  }
}
