//
//  SorcesRepo.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/09/2025.
//

import Dependencies

nonisolated struct SourcesRepoImpl: Sendable {
    nonisolated static let live = SourcesRepo(
        listKnownSources: { @Sendable in
            @Dependency(\.remoteSourcesManager) var remote
            @Dependency(\.localStore) var local
            let sources = await remote.listAllSources()
            let displayNames = await remote.listDisplayNamesFor(sources)
            let metaList = await local.listSourceMetaFor(sources)

            return sources
                .map { source in
                    if let source = metaList[source]?.toSource {
                        return source
                    }
                    if let displayName = displayNames[source] {
                        return Source(name: source, displayName: displayName)
                    }
                    return Source(name: source, displayName: source)
                }
        },
        fetchAndSaveDataFrom: { sourceId in
            @Dependency(\.remoteSourcesManager) var remotes
            @Dependency(\.localStore) var store

            do {
                // - fetch from the selected source
                let source = await remotes.sourceFor(sourceId)
                let data = try await source.fetchData()
                // - save (additive-union merge) into the local store
                let syncDate = try await store.save(data, source)

                // Build the returned Source from the *persisted, merged* metadata so the card reflects the
                // full stored set (FR-005/SC-002), not just this fetch's draws.
                if let meta = await store.listSourceMetaFor([source.name])[source.name] {
                    return .success(meta.toSource)
                }
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
