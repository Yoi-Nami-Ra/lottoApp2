//
//  SourcesRepo.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/09/2025.
//

import Foundation
import Dependencies

nonisolated struct SourcesRepo: Sendable {
    var listKnownSources: @Sendable () async -> [Source]
    /// Fetches the source and merges its draws into the store; a failure says which step failed and why.
    var fetchAndSaveDataFrom: @Sendable (String) async -> Result<Source, SyncFailure>
    /// The source's stored draws as a `Game`, index ascending, with the data state they were read at.
    var gameFor: @Sendable (String) async -> Result<SourceSnapshot, SourceReadFailure>
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
