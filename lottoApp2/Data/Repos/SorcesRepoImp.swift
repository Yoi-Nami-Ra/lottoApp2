//
//  SorcesRepo.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/09/2025.
//

import Dependencies
import OSLog

nonisolated struct SourcesRepoImpl: Sendable {
    nonisolated static let live = SourcesRepo(
        listKnownSources: { @Sendable in
            @Dependency(\.remoteSourcesManager) var remote
            @Dependency(\.localStore) var local
            let names = await remote.listAllSources()
            let displayNames = await remote.listDisplayNamesFor(names)
            let metaList = await local.listSourceMetaFor(names)

            return names.map { name in
                // The registry always owns the display name; stored metadata only supplies the analytics.
                let displayName = displayNames[name] ?? name
                guard let meta = metaList[name] else {
                    return Source(name: name, displayName: displayName)
                }
                return meta.source(displayName: displayName)
            }
        },
        fetchAndSaveDataFrom: { sourceId in
            @Dependency(\.remoteSourcesManager) var remotes
            @Dependency(\.localStore) var store
            @Dependency(\.date) var date

            do {
                // - fetch from the selected source
                let source = await remotes.sourceFor(sourceId)
                let fetched = try await source.fetchData()

                // FR-007 / US3-AS2: malformed rows don't fail the sync, but they must not pass silently.
                if fetched.skipped > 0 {
                    Logger.sources.warning(
                        """
                        \(source.name, privacy: .public): kept \(fetched.draws.count, privacy: .public) \
                        draw(s), skipped \(fetched.skipped, privacy: .public) malformed row(s)
                        """
                    )
                }

                // - save (additive-union merge) into the local store
                try await store.save(fetched.draws, source, date.now)

                // Report the *persisted, merged* metadata so the card reflects the full stored set
                // (FR-005/SC-002), not just this fetch's draws.
                guard let meta = await store.listSourceMetaFor([source.name])[source.name] else {
                    return .failure(.failedToFetchData)
                }
                return .success(meta.source(displayName: source.displayName))
            } catch {
                Logger.sources.error("\(sourceId, privacy: .public): sync failed — \(error)")
                return .failure(.failedToFetchData)
            }
        },
        gameFor: { sourceId in
            @Dependency(\.localStore) var store
            guard let module = SourceRegistry.module(for: sourceId) else { return .failure(.unknownSource) }

            let draws = await store.listDrawsFor(module.name).sorted { $0.index < $1.index }
            let meta = await store.listSourceMetaFor([module.name])[module.name]
            do {
                let entries = try draws.map { draw in
                    GameEntry(
                        index: draw.index,
                        date: draw.date,
                        combination: try Combination(
                            type: module.gameType.combinationType,
                            // A negative number can't be an element; dropping it fails the count check below.
                            elements: draw.numbers.compactMap(Element.init(exactly:))
                        )
                    )
                }
                let game = try Game(type: module.gameType, entries: entries)
                return .success(SourceSnapshot(game: game, dataState: .of(meta)))
            } catch {
                Logger.sources.error("\(sourceId, privacy: .public): a stored draw breaks the game shape — \(error)")
                return .failure(.invalidStoredDraw)
            }
        },
        dataStateFor: { sourceId in
            @Dependency(\.localStore) var store
            guard let module = SourceRegistry.module(for: sourceId) else { return nil }
            return .of(await store.listSourceMetaFor([module.name])[module.name])
        }
    )
}

nonisolated extension SourceDataState {
    /// The data state recorded in `meta`; a never-synced source (no meta) has an empty history.
    fileprivate static func of(_ meta: SourceMeta?) -> SourceDataState {
        guard let meta else {
            return SourceDataState(recordsCount: 0, latestRecord: nil, contentDigest: LocalStore.digest(of: []))
        }
        return SourceDataState(recordsCount: meta.recordsCount, latestRecord: meta.latestRecord, contentDigest: meta.contentDigest)
    }
}

nonisolated extension SourceMeta {
    /// Lifts persisted analytics into the Domain entity. The display name is supplied by the caller from the
    /// registry, so renaming a source in code takes effect immediately rather than being shadowed on disk.
    func source(displayName: String) -> Source {
        Source(
            name: name,
            displayName: displayName,
            lastSync: lastSync,
            recordsCount: recordsCount,
            latestRecord: latestRecord,
            firstRecord: firstRecord
        )
    }
}

extension Logger {
    fileprivate nonisolated static let sources = Logger(subsystem: "com.yois.lottoApp2", category: "sources")
}
