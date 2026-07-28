//
//  SorcesRepo.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/09/2025.
//

import Dependencies

nonisolated struct SourcesRepoImpl: Sendable {
    static let live = SourcesRepo(
        listKnownSources: { @Sendable in
            @Dependency(\.remoteSourcesManager) var remote
            @Dependency(\.localStore) var local
            let sources = await remote.listAllSources()
            let displayNames = await remote.listDisplayNamesFor(sources)
            let metaList = await local.listSourceMetaFor(sources)

            return sources
                .map { source in
                    if let source =  metaList[source]?.toSource {
                        return source
                    }
                    if let displayName = displayNames[source] {
                        return Source(name: source, displayName: displayName)
                    }
                    return Source(name: source, displayName: source)
                }
        }, // TODO Implement
        fetchAndSaveDataFrom: { sourceId in
            @Dependency(\.remoteSourcesManager) var remotes
            @Dependency(\.localStore) var store

            // - fetch them from selected source
            do {
                let source = await remotes.sourceFor(sourceId)
                let data = try await source.fetchData()
                let syncDate = store.save(data, source)

                return .success(
                    Source(
                        name: source.name,
                        displayName: source.displayName,
                        lastSync: syncDate,
                        recordsCount: data.count,
                        latestRecord: data.latest?.date,
                        firstRecord: data.oldest?.date
                    )
                )
            } catch {
                return .failure(.failedToFetchData)
            }

            // - save them into the database
        }
    )
}

nonisolated extension SourceMeta {
    var toSource: Source {
        Source(
            name: name,
            displayName: displayName,
            lastSync: lastSync,
            recordsCount: recordsCount,
            latestRecord: latestRecord,
            firstRecord: firstRecrd
        )
    }
}

nonisolated struct RemoteSourcesManager {
    var listAllSources: @Sendable () async -> [String]
    var listDisplayNamesFor: @Sendable ([String]) async -> [String: String]
    var sourceFor: @Sendable (String) async -> RemoteSource
}

extension RemoteSourcesManager: DependencyKey {
    static let liveValue = RemoteSourcesManagerImp.live
}

nonisolated struct RemoteSourcesManagerImp {
    static let live: RemoteSourcesManager = .init(
        listAllSources: { [] },
        listDisplayNamesFor: { _ in [:] },
        sourceFor: { _ in RemoteSource(name: "a", displayName: "b") }
    )
}

extension DependencyValues {
  nonisolated var remoteSourcesManager: RemoteSourcesManager {
    get { self[RemoteSourcesManager.self] }
    set { self[RemoteSourcesManager.self] = newValue }
  }
}
