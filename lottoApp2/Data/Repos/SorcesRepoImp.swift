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

            // - fetch from the selected source. Each step maps its own failure (spec 004 contracts §2): the
            //   fetch step by the error's type, the store steps by the fact that they are the store steps.
            let source = await remotes.sourceFor(sourceId)
            let fetched: FetchedDraws
            do {
                fetched = try await source.fetchData()
            } catch {
                return .failure(SourcesRepoImpl.logged(SyncFailure(classifying: error), sourceId, error))
            }

            // FR-007 / US3-AS2: malformed rows don't fail the sync, but they must not pass silently. The user
            // sees one total (spec 005 FR-003); the log keeps the two kinds apart (FR-012).
            if fetched.skippedTotal > 0 {
                Logger.sources.warning(
                    """
                    \(source.name, privacy: .public): kept \(fetched.draws.count, privacy: .public) \
                    draw(s), skipped \(fetched.skipped, privacy: .public) unreadable row(s) and \
                    \(fetched.invalid, privacy: .public) draw(s) that break the game rules
                    """
                )
            }

            // - save (additive-union merge) into the local store
            do {
                try await store.save(fetched.draws, source, date.now, fetched.skippedTotal)
            } catch {
                return .failure(SourcesRepoImpl.logged(error is CancellationError ? .cancelled : .storageFailure, sourceId, error))
            }

            // Report the *persisted, merged* metadata so the card reflects the full stored set
            // (FR-005/SC-002), not just this fetch's draws. Saved but unreadable is still a storage failure.
            guard let meta = await store.listSourceMetaFor([source.name])[source.name] else {
                Logger.sources.error("\(sourceId, privacy: .public): sync failed (storageFailure) — saved meta not found")
                return .failure(.storageFailure)
            }
            return .success(meta.source(displayName: source.displayName))
        },
        gameFor: { sourceId in
            @Dependency(\.localStore) var store
            guard let module = SourceRegistry.module(for: sourceId) else { return .failure(.sourceUnavailable) }

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
                return .failure(.unreadableStoredDraws)
            }
        },
        dataStateFor: { sourceId in
            @Dependency(\.localStore) var store
            guard let module = SourceRegistry.module(for: sourceId) else { return nil }
            return .of(await store.listSourceMetaFor([module.name])[module.name])
        }
    )
}

extension SourcesRepoImpl {
    /// Logs the raw error next to the kind the user will be told about (spec 004 FR-009), then returns the kind.
    fileprivate nonisolated static func logged(_ failure: SyncFailure, _ sourceId: String, _ error: any Error) -> SyncFailure {
        Logger.sources.error("\(sourceId, privacy: .public): sync failed (\(String(describing: failure), privacy: .public)) — \(error)")
        return failure
    }
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
            firstRecord: firstRecord,
            lastSyncSkipped: lastSyncSkipped,
            cadence: drawsInWindow.flatMap { $0 > 0 ? DrawCadence(drawsInWindow: $0) : nil }
        )
    }
}

extension Logger {
    fileprivate nonisolated static let sources = Logger(subsystem: "com.yois.lottoApp2", category: "sources")
}
