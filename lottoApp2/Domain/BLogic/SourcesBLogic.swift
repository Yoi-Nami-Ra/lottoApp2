//
//  SourcesBLogic.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 07/07/2025.
//

import Dependencies
import Foundation

nonisolated struct SourcesBLogic: Sendable {
    var knownSources: @Sendable () async -> [Source]
    var fetchFrom: @Sendable (String) async -> Result<Source, SyncFailure>
    /// The source's draws for a run, with the data state they were read at (spec 003 contracts §3).
    var gameFor: @Sendable (String) async -> Result<SourceSnapshot, SourceReadFailure>
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
            // Pass-through: the failure kind must reach the card unchanged (spec 004 FR-002).
            return await repo.fetchAndSaveDataFrom(source)
        },
        gameFor: { source in
            @Dependency(\.sourcesRepo) var repo
            return await repo.gameFor(source)
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
