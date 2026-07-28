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
        case weFailed
        case failedToFetchData /// general fail to fetch current data from given server
    }

    var listKnownSources: @Sendable () async -> [Source]
    var fetchAndSaveDataFrom: @Sendable (String) async -> Result<Source, Error>
}

extension SourcesRepo: DependencyKey {
    static let liveValue = SourcesRepoImpl.live
}

extension DependencyValues {
  nonisolated var sourcesRepo: SourcesRepo {
    get { self[SourcesRepo.self] }
    set { self[SourcesRepo.self] = newValue }
  }
}
