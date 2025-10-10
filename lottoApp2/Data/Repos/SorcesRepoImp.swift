//
//  SorcesRepo.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/09/2025.
//

import Dependencies

extension SorcesRepo: DependencyKey {
    static let liveValue = SorcesRepo(
        fetchAndSaveDataFrom: { sourceName in
            @Dependency(\.remoteSourcesManager) var remotes
            @Dependency(\.localStore) var store

            // - fetch them from selected source
            do {
                let source = await remotes.sourceFor(sourceName)
                let data = try await source.fetchData()
                let syncDate = store.save(data, source)

                return .success(
                    Source(
                        name: source.name,
                        displayName: source.displayName,
                        lastSync: syncDate,
                        recordCount: data.count,
                        latestRecord: data.latest!.date,
                        firstRecrd: data.oldest!.date
                    )
                )
            } catch {
                return .failure(.failedToFetchData)
            }

            // - save them into the database
        }
    )
}
