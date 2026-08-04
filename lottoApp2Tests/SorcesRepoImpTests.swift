//
//  SorcesRepoImpTests.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 30/07/2026.
//

import Dependencies
import Foundation
import Testing

@testable import lottoApp2

struct SorcesRepoImp_Tests {

    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private let syncDate = Date(timeIntervalSince1970: 1_000_000)

    @Test
    func listsMBNetWithEmptyMetadataWhenNeverSynced() async throws {
        // US1 / FR-001: MBNet is present in a never-synced state (no stored meta).
        let sources = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManager(
                listAllSources: { ["mbnet"] },
                listDisplayNamesFor: { _ in ["mbnet": "MBNet Server"] },
                sourceFor: { name in RemoteSource(name: name, displayName: "MBNet Server") { .init(draws: [], skipped: 0) } }
            )
            $0.localStore = LocalStore(
                save: { _, _, _ in },
                listSourceMetaFor: { _ in [:] },
                listDrawsFor: { _ in [] }
            )
        } operation: {
            await SourcesRepoImpl.live.listKnownSources()
        }

        #expect(sources == [Source(name: "mbnet", displayName: "MBNet Server")])
    }

    @Test
    func listsStoredAnalyticsWhenPreviouslySynced() async throws {
        // US1 acceptance scenario 2: a previously synced source is listed with its stored sync metadata.
        let meta = SourceMeta(
            name: "mbnet",
            lastSync: syncDate,
            recordsCount: 7380,
            latestRecord: Date(timeIntervalSince1970: 1_700_000_000),
            firstRecord: Date(timeIntervalSince1970: 18_223_210)
        )

        let sources = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManager(
                listAllSources: { ["mbnet"] },
                listDisplayNamesFor: { _ in ["mbnet": "MBNet Server"] },
                sourceFor: { name in RemoteSource(name: name, displayName: "MBNet Server") { .init(draws: [], skipped: 0) } }
            )
            $0.localStore = LocalStore(
                save: { _, _, _ in },
                listSourceMetaFor: { _ in ["mbnet": meta] },
                listDrawsFor: { _ in [] }
            )
        } operation: {
            await SourcesRepoImpl.live.listKnownSources()
        }

        #expect(sources == [
            Source(
                name: "mbnet",
                displayName: "MBNet Server",
                lastSync: syncDate,
                recordsCount: 7380,
                latestRecord: meta.latestRecord,
                firstRecord: meta.firstRecord
            )
        ])
    }

    @Test
    func displayNameComesFromTheRegistryNotFromDisk() async throws {
        // Regression: stored metadata used to carry the display name, so renaming a source in code was
        // shadowed forever once it had synced once.
        let meta = SourceMeta(
            name: "mbnet", lastSync: syncDate, recordsCount: 1, latestRecord: nil, firstRecord: nil
        )

        let sources = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManager(
                listAllSources: { ["mbnet"] },
                listDisplayNamesFor: { _ in ["mbnet": "MBNet Server (renamed)"] },
                sourceFor: { name in RemoteSource(name: name, displayName: "MBNet Server (renamed)") { .init(draws: [], skipped: 0) } }
            )
            $0.localStore = LocalStore(
                save: { _, _, _ in },
                listSourceMetaFor: { _ in ["mbnet": meta] },
                listDrawsFor: { _ in [] }
            )
        } operation: {
            await SourcesRepoImpl.live.listKnownSources()
        }

        #expect(sources.first?.displayName == "MBNet Server (renamed)")
    }

    @Test
    func fetchAndSaveReturnsMetadataMatchingParsedDraws() async throws {
        // SC-002: after a successful fetch, the returned Source reflects the stored (merged) analytics.
        let body = """
        1. 27.01.1957 8,12,31,39,43,45
        2. 03.02.1957 5,10,11,22,25,27
        """
        let result = await withDependencies {
            // Integration test: exercise the real `sourceFor("mbnet")` wiring, stubbing only network + disk.
            $0.remoteSourcesManager = RemoteSourcesManagerImp.live
            $0.networkClient.data = { _ in Data(body.utf8) }
            $0.localStore = .fileBacked(root: tempRoot())
            $0.date = .constant(syncDate)
        } operation: {
            await SourcesRepoImpl.live.fetchAndSaveDataFrom("mbnet")
        }

        guard case let .success(source) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(source.name == "mbnet")
        #expect(source.displayName == "MBNet Server")
        #expect(source.recordsCount == 2)
        #expect(source.lastSync == syncDate)
        #expect(source.firstRecord == MBNetParser.parseDate("27.01.1957"))
        #expect(source.latestRecord == MBNetParser.parseDate("03.02.1957"))
    }

    @Test
    func fetchFailsOnNonSuccessStatusAndPersistsNothing() async throws {
        // FR-006: a non-2xx / transport error surfaces as a failure and writes nothing.
        let root = tempRoot()
        let store = LocalStore.fileBacked(root: root)

        let result = await withDependencies {
            // Integration test: exercise the real `sourceFor("mbnet")` wiring, stubbing only network + disk.
            $0.remoteSourcesManager = RemoteSourcesManagerImp.live
            $0.networkClient.data = { _ in throw NetworkClient.Failure.badStatus(500) }
            $0.localStore = store
            $0.date = .constant(syncDate)
        } operation: {
            await SourcesRepoImpl.live.fetchAndSaveDataFrom("mbnet")
        }

        guard case .failure = result else {
            Issue.record("expected failure, got \(result)")
            return
        }
        #expect(await store.listDrawsFor("mbnet").isEmpty)
        #expect(await store.listSourceMetaFor(["mbnet"]).isEmpty)
    }

    @Test
    func schemaDriftFailsTheSyncAndPersistsNothing() async throws {
        // FR-006 / spec Edge Cases → Schema drift: a 200 body whose every row is malformed must fail rather
        // than stamp a successful sync with a fresh `lastSync` and nothing stored.
        let root = tempRoot()
        let store = LocalStore.fileBacked(root: root)
        let body = """
        {"draws":[{"id":1,"date":"1957-01-27"}]}
        {"draws":[{"id":2,"date":"1957-02-03"}]}
        """

        let result = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManagerImp.live
            $0.networkClient.data = { _ in Data(body.utf8) }
            $0.localStore = store
            $0.date = .constant(syncDate)
        } operation: {
            await SourcesRepoImpl.live.fetchAndSaveDataFrom("mbnet")
        }

        guard case .failure = result else {
            Issue.record("expected failure, got \(result)")
            return
        }
        #expect(await store.listDrawsFor("mbnet").isEmpty)
        #expect(await store.listSourceMetaFor(["mbnet"]).isEmpty)
    }

    @Test
    func failedResyncLeavesPriorDataAndMetadataUntouched() async throws {
        // SC-004: 0% of previously stored records or metadata are altered by a failed sync.
        let store = LocalStore.fileBacked(root: tempRoot())
        let goodBody = "1. 27.01.1957 8,12,31,39,43,45"

        _ = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManagerImp.live
            $0.networkClient.data = { _ in Data(goodBody.utf8) }
            $0.localStore = store
            $0.date = .constant(syncDate)
        } operation: {
            await SourcesRepoImpl.live.fetchAndSaveDataFrom("mbnet")
        }

        let metaBefore = try #require(await store.listSourceMetaFor(["mbnet"])["mbnet"])

        let result = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManagerImp.live
            $0.networkClient.data = { _ in throw NetworkClient.Failure.badStatus(503) }
            $0.localStore = store
            $0.date = .constant(Date(timeIntervalSince1970: 2_000_000))
        } operation: {
            await SourcesRepoImpl.live.fetchAndSaveDataFrom("mbnet")
        }

        guard case .failure = result else {
            Issue.record("expected failure, got \(result)")
            return
        }
        #expect(await store.listSourceMetaFor(["mbnet"])["mbnet"] == metaBefore)
        #expect(await store.listDrawsFor("mbnet").count == 1)
    }

    @Test
    func partialBodyStillSucceedsAndSurfacesTheSkippedCount() async throws {
        // FR-007: malformed rows are skipped, the good ones are kept — and the count crosses the boundary
        // out of the parser (it used to be dropped at the fetch site) so the repo can report it.
        let body = """
        1. 27.01.1957 8,12,31,39,43,45
        garbage line
        3. 10.02.1957 18,19,20,26,45,49
        """
        let store = LocalStore.fileBacked(root: tempRoot())

        let fetched = try await withDependencies {
            $0.networkClient.data = { _ in Data(body.utf8) }
        } operation: {
            try await RemoteSourcesManagerImp.live.sourceFor("mbnet").fetchData()
        }

        #expect(fetched.skipped == 1)
        #expect(fetched.draws.map(\.index) == [1, 3])

        let result = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManagerImp.live
            $0.networkClient.data = { _ in Data(body.utf8) }
            $0.localStore = store
            $0.date = .constant(syncDate)
        } operation: {
            await SourcesRepoImpl.live.fetchAndSaveDataFrom("mbnet")
        }

        guard case let .success(source) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(source.recordsCount == 2)
    }

    @Test
    func unregisteredSourceFailsAsUnsupported() async throws {
        // FR-010: asking for a source the registry doesn't know fails cleanly instead of silently fetching.
        let source = await RemoteSourcesManagerImp.live.sourceFor("nope")

        #expect(source.name == "nope")
        await #expect(throws: RemoteSourceError.unsupportedSource("nope")) {
            try await source.fetchData()
        }
    }
}
