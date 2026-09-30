//
//  SourcesRepo.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/09/2025.
//

import Foundation
import Dependencies

nonisolated struct SourcesRepo: Sendable {
    enum Error: Swift.Error {
        case failedToFetchData /// general fail to fetch current data from given server
        case unknownSource /// no registered source has this id
        case invalidStoredDraw /// a stored draw breaks the source's combination shape
    }

    var listKnownSources: @Sendable () async -> [Source]
    var fetchAndSaveDataFrom: @Sendable (String) async -> Result<Source, Error>
    /// The source's stored draws as a `Game`, index ascending, with the data state they were read at.
    var gameFor: @Sendable (String) async -> Result<SourceSnapshot, Error>
    /// The source's current data state; `nil` when no such source exists.
    var dataStateFor: @Sendable (String) async -> SourceDataState?
}

extension SourcesRepo: nonisolated DependencyKey {
    nonisolated static let liveValue = SourcesRepoImpl.live
}

extension DependencyValues {
  nonisolated var sourcesRepo: SourcesRepo {
    get { self[SourcesRepo.self] }
    set { self[SourcesRepo.self] = newValue }
  }
}
