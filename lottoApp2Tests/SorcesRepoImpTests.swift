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
                save: { _, _, _, _ in },
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
            firstRecord: Date(timeIntervalSince1970: 18_223_210),
            contentDigest: ""
        )

        let sources = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManager(
                listAllSources: { ["mbnet"] },
                listDisplayNamesFor: { _ in ["mbnet": "MBNet Server"] },
                sourceFor: { name in RemoteSource(name: name, displayName: "MBNet Server") { .init(draws: [], skipped: 0) } }
            )
            $0.localStore = LocalStore(
                save: { _, _, _, _ in },
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
                firstRecord: meta.firstRecord,
                // A synced source always has a count; meta without one reads as 0 (spec 005 FR-013).
                lastSyncSkipped: 0
            )
        ])
    }

    @Test
    func listsTheStoredSkippedCount_andNoneForANeverSyncedSource() async throws {
        // Spec 005 contracts §2: the last sync's skipped count is lifted from the stored meta; a source that
        // never synced has no count at all (not 0).
        let meta = SourceMeta(
            name: "mbnet", lastSync: syncDate, recordsCount: 1, latestRecord: nil, firstRecord: nil,
            contentDigest: "", lastSyncSkipped: 4
        )
        let known: [String: SourceMeta] = ["mbnet": meta]

        let sources = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManager(
                listAllSources: { ["mbnet", "other"] },
                listDisplayNamesFor: { _ in ["mbnet": "MBNet Server", "other": "Other"] },
                sourceFor: { name in RemoteSource(name: name, displayName: name) { .init(draws: [], skipped: 0) } }
            )
            $0.localStore = LocalStore(
                save: { _, _, _, _ in },
                listSourceMetaFor: { names in known.filter { names.contains($0.key) } },
                listDrawsFor: { _ in [] }
            )
        } operation: {
            await SourcesRepoImpl.live.listKnownSources()
        }

        #expect(sources.map(\.lastSyncSkipped) == [4, nil])
    }

    @Test
    func displayNameComesFromTheRegistryNotFromDisk() async throws {
        // Regression: stored metadata used to carry the display name, so renaming a source in code was
        // shadowed forever once it had synced once.
        let meta = SourceMeta(
            name: "mbnet", lastSync: syncDate, recordsCount: 1, latestRecord: nil, firstRecord: nil, contentDigest: ""
        )

        let sources = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManager(
                listAllSources: { ["mbnet"] },
                listDisplayNamesFor: { _ in ["mbnet": "MBNet Server (renamed)"] },
                sourceFor: { name in RemoteSource(name: name, displayName: "MBNet Server (renamed)") { .init(draws: [], skipped: 0) } }
            )
            $0.localStore = LocalStore(
                save: { _, _, _, _ in },
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
        // FR-006: a non-2xx status surfaces as a server error carrying its code (spec 004 FR-004) and writes nothing.
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

        #expect(result == .failure(.serverError(status: 500)))
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

        #expect(result == .failure(.unreadableData))
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

        #expect(result == .failure(.serverError(status: 503)))
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
        #expect(source.lastSyncSkipped == 1)
    }

    // MARK: - Skipped records (spec 005)

    /// Syncs `body` through the live wiring into `store` and returns the synced source, recording an issue
    /// when the sync fails.
    private func syncedSource(_ body: String, into store: LocalStore) async -> Source? {
        let data = Data(body.utf8)
        let result = await syncMBNet(network: { _ in data }, store: store)
        guard case let .success(source) = result else {
            Issue.record("expected success, got \(result)")
            return nil
        }
        return source
    }

    private nonisolated static let valid1 = "1. 27.01.1957 8,12,31,39,43,45"
    private nonisolated static let valid3 = "3. 10.02.1957 18,19,20,26,45,49"
    private nonisolated static let repeated2 = "2. 03.02.1957 5,5,11,22,25,27"
    private nonisolated static let repeated4 = "4. 17.02.1957 1,9,9,20,30,40"

    @Test
    func unreadableRowsOnly_areCounted_andTheRestStored() async {
        let store = LocalStore.inMemory()
        let source = await syncedSource([Self.valid1, "garbage line", Self.valid3].joined(separator: "\n"), into: store)

        #expect(source?.lastSyncSkipped == 1)
        #expect(await store.listDrawsFor("mbnet").map(\.index) == [1, 3])
    }

    @Test
    func drawsThatBreakTheRules_areNotStored_andAreCounted() async {
        // FR-001/FR-002: a repeated number passes the MBNet parser but breaks the 6-of-49 rules.
        let store = LocalStore.inMemory()
        let source = await syncedSource([Self.valid1, Self.repeated2, Self.repeated4].joined(separator: "\n"), into: store)

        #expect(source?.lastSyncSkipped == 2)
        #expect(source?.recordsCount == 1)
        #expect(await store.listDrawsFor("mbnet").map(\.index) == [1])
    }

    @Test
    func bothKinds_makeOneCount() async {
        // FR-003: one count covers unreadable rows and rule-breaking draws.
        let store = LocalStore.inMemory()
        let body = ["garbage line", Self.repeated2, Self.repeated4, Self.valid3].joined(separator: "\n")
        let source = await syncedSource(body, into: store)

        #expect(source?.lastSyncSkipped == 3)
        #expect(await store.listDrawsFor("mbnet").map(\.index) == [3])
    }

    @Test
    func aCleanResponse_skipsNothing() async {
        let source = await syncedSource([Self.valid1, Self.valid3].joined(separator: "\n"), into: .inMemory())

        #expect(source?.lastSyncSkipped == 0)
    }

    @Test
    func rowsThatAllBreakTheRules_failAsAFormatChange_andStoreNothing() async {
        // FR-007: rows arrived but none survived — the same outcome as a body no row of which parses.
        let store = LocalStore.inMemory()
        let body = Data([Self.repeated2, Self.repeated4].joined(separator: "\n").utf8)

        let result = await syncMBNet(network: { _ in body }, store: store)

        #expect(result == .failure(.unreadableData))
        #expect(await store.listDrawsFor("mbnet").isEmpty)
        #expect(await store.listSourceMetaFor(["mbnet"]).isEmpty)
    }

    @Test
    func aRuleBreakingDraw_neverReplacesAStoredValidOne() async throws {
        // Spec Edge Cases: the additive merge must not let an invalid draw overwrite a valid one at its index.
        let store = LocalStore.inMemory()
        _ = await syncedSource(Self.valid1, into: store)
        let storedBefore = await store.listDrawsFor("mbnet")

        let source = await syncedSource(["1. 27.01.1957 8,8,31,39,43,45", Self.valid3].joined(separator: "\n"), into: store)

        #expect(source?.lastSyncSkipped == 1)
        let stored = await store.listDrawsFor("mbnet")
        #expect(stored.first == storedBefore.first)
        #expect(stored.map(\.index) == [1, 3])
    }

    @Test
    func anEmptyResponse_clearsTheCount_andKeepsTheDraws() async {
        // Spec Edge Cases → Empty response: a successful empty history has skipped nothing.
        let store = LocalStore.inMemory()
        _ = await syncedSource([Self.valid1, "garbage line"].joined(separator: "\n"), into: store)

        let source = await syncedSource("", into: store)

        #expect(source?.lastSyncSkipped == 0)
        #expect(await store.listDrawsFor("mbnet").map(\.index) == [1])
    }

    // MARK: - Lifetime of the skipped count (spec 005 US2)

    private nonisolated static let threeSkipped = ["garbage", Self.repeated2, Self.repeated4, Self.valid1].joined(separator: "\n")

    @Test
    func aFailedSync_keepsTheStoredSkippedCount() async throws {
        // FR-006 / US2-AS4.
        let store = LocalStore.fileBacked(root: tempRoot())
        _ = await syncedSource(Self.threeSkipped, into: store)

        let result = await syncMBNet(network: { _ in throw NetworkClient.Failure.badStatus(503) }, store: store)

        #expect(result == .failure(.serverError(status: 503)))
        #expect(await store.listSourceMetaFor(["mbnet"])["mbnet"]?.lastSyncSkipped == 3)
    }

    @Test
    func aCleanSync_replacesTheSkippedCountWithZero() async {
        // FR-005 / US2-AS3.
        let store = LocalStore.fileBacked(root: tempRoot())
        _ = await syncedSource(Self.threeSkipped, into: store)

        let source = await syncedSource(Self.valid3, into: store)

        #expect(source?.lastSyncSkipped == 0)
    }

    @Test
    func theSkippedCountIsListedAgainAfterARelaunch() async {
        // US2-AS1: a relaunch lists the sources from a fresh store over the same directory.
        let root = tempRoot()
        _ = await syncedSource(Self.threeSkipped, into: .fileBacked(root: root))

        let sources = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManagerImp.live
            $0.localStore = .fileBacked(root: root)
        } operation: {
            await SourcesRepoImpl.live.listKnownSources()
        }

        #expect(sources.first { $0.name == "mbnet" }?.lastSyncSkipped == 3)
    }

    // MARK: - Failure kinds (spec 004)

    private func syncMBNet(
        _ id: String = "mbnet",
        network: @escaping @Sendable (URL) async throws -> Data,
        store: LocalStore
    ) async -> Result<Source, SyncFailure> {
        await withDependencies {
            // Integration test: exercise the real `sourceFor` wiring, stubbing only network + disk.
            $0.remoteSourcesManager = RemoteSourcesManagerImp.live
            $0.networkClient.data = network
            $0.localStore = store
            $0.date = .constant(syncDate)
        } operation: {
            await SourcesRepoImpl.live.fetchAndSaveDataFrom(id)
        }
    }

    private nonisolated static let goodBody = Data("1. 27.01.1957 8,12,31,39,43,45".utf8)

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, SyncFailure.offline),
        (.timedOut, .serverUnreachable),
        (.cancelled, .cancelled),
    ])
    func aTransportFailure_isClassified_andPersistsNothing(_ code: URLError.Code, _ expected: SyncFailure) async {
        // US1-AS1/AS2, FR-007: the transport error keeps its kind up to the repo result.
        let store = LocalStore.inMemory()

        let result = await syncMBNet(network: { _ in throw URLError(code) }, store: store)

        #expect(result == .failure(expected))
        #expect(await store.listDrawsFor("mbnet").isEmpty)
        #expect(await store.listSourceMetaFor(["mbnet"]).isEmpty)
    }

    @Test
    func aBodyThatIsNotText_isUnreadableData_andPersistsNothing() async {
        // US1-AS5: bytes that aren't UTF-8 are a format change, not a connection problem.
        let store = LocalStore.inMemory()

        let result = await syncMBNet(network: { _ in Data([0xFF, 0xFE]) }, store: store)

        #expect(result == .failure(.unreadableData))
        #expect(await store.listDrawsFor("mbnet").isEmpty)
    }

    @Test
    func anUnregisteredSource_isUnavailable_andPersistsNothing() async {
        // US1-AS6: the registry no longer knows the id.
        let store = LocalStore.inMemory()

        let result = await syncMBNet("nope", network: { _ in Self.goodBody }, store: store)

        #expect(result == .failure(.sourceUnavailable))
        #expect(await store.listDrawsFor("nope").isEmpty)
    }

    @Test
    func aSaveThatThrows_isAStorageFailure_andPersistsNothing() async {
        // US1-AS7: the draws downloaded fine but couldn't be written on the device.
        let backing = LocalStore.inMemory()
        var store = backing
        store.save = { _, _, _, _ in throw CocoaError(.fileWriteOutOfSpace) }

        let result = await syncMBNet(network: { _ in Self.goodBody }, store: store)

        #expect(result == .failure(.storageFailure))
        #expect(await backing.listDrawsFor("mbnet").isEmpty)
        #expect(await backing.listSourceMetaFor(["mbnet"]).isEmpty)
    }

    @Test
    func savedDetailsThatCantBeReadBack_areAStorageFailure() async {
        // Spec 004 Edge Cases → Saved but not read back.
        var store = LocalStore.inMemory()
        store.listSourceMetaFor = { _ in [:] }

        let result = await syncMBNet(network: { _ in Self.goodBody }, store: store)

        #expect(result == .failure(.storageFailure))
    }

    // MARK: - gameFor / dataStateFor (LTA-6, LTA-30)

    private let mbnet = RemoteSource(name: "mbnet", displayName: "MBNet Server") { .init(draws: [], skipped: 0) }

    private func seededStore(_ draws: [DrawDTO]) async throws -> LocalStore {
        let store = LocalStore.inMemory()
        try await store.save(draws, mbnet, syncDate, 0)
        return store
    }

    @Test
    func gameFor_mapsTheStoredDrawsIntoAGameOfTheSourcesType() async throws {
        let draws = [
            DrawDTO(index: 2, date: Date(timeIntervalSince1970: 200), numbers: [45, 1, 2, 3, 4, 5]),
            DrawDTO(index: 1, date: Date(timeIntervalSince1970: 100), numbers: [8, 12, 31, 39, 43, 44]),
        ]
        let store = try await seededStore(draws)

        let result = await withDependencies {
            $0.localStore = store
        } operation: {
            await SourcesRepoImpl.live.gameFor("mbnet")
        }

        let snapshot = try result.get()
        #expect(snapshot.game.type == MBNetSource().gameType)
        #expect(snapshot.game.type.combinationType == (try CombinationType(pick: 6, pool: 49)))
        #expect(snapshot.game.entries.map(\.index) == [1, 2])  // index ascending (FR-013)
        #expect(snapshot.game.entries[1].date == Date(timeIntervalSince1970: 200))
        #expect(snapshot.game.entries[1].combination.elements == [1, 2, 3, 4, 5, 45])

        let meta = try #require(await store.listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(snapshot.dataState == SourceDataState(
            recordsCount: 2, latestRecord: Date(timeIntervalSince1970: 200), contentDigest: meta.contentDigest
        ))
    }

    @Test
    func gameFor_aNeverSyncedSource_isAnEmptyGame() async throws {
        let (result, state) = await withDependencies {
            $0.localStore = .inMemory()
        } operation: {
            (await SourcesRepoImpl.live.gameFor("mbnet"), await SourcesRepoImpl.live.dataStateFor("mbnet"))
        }

        let empty = SourceDataState(recordsCount: 0, latestRecord: nil, contentDigest: LocalStore.digest(of: []))
        let snapshot = try result.get()
        #expect(snapshot.game.entries.isEmpty)
        #expect(snapshot.dataState == empty)
        #expect(state == empty)
    }

    @Test
    func gameFor_anUnknownSource_fails_andHasNoDataState() async throws {
        let (result, state) = await withDependencies {
            $0.localStore = .inMemory()
        } operation: {
            (await SourcesRepoImpl.live.gameFor("nope"), await SourcesRepoImpl.live.dataStateFor("nope"))
        }

        #expect(result == .failure(.sourceUnavailable))
        #expect(state == nil)
    }

    @Test
    func gameFor_aStoredDrawThatBreaksTheShape_fails() async throws {
        let store = try await seededStore([DrawDTO(index: 1, date: Date(timeIntervalSince1970: 100), numbers: [1, 1, 2, 3, 4, 5])])

        let result = await withDependencies {
            $0.localStore = store
        } operation: {
            await SourcesRepoImpl.live.gameFor("mbnet")
        }

        #expect(result == .failure(.unreadableStoredDraws))
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
