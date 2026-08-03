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

    @Test
    func listsMBNetWithEmptyMetadataWhenNeverSynced() async throws {
        // US1 / FR-001: MBNet is present in a never-synced state (no stored meta).
        let sources = await withDependencies {
            $0.remoteSourcesManager = RemoteSourcesManager(
                listAllSources: { ["mbnet"] },
                listDisplayNamesFor: { _ in ["mbnet": "MBNet Server"] },
                sourceFor: { name in RemoteSource(name: name, displayName: "MBNet Server") { [] } }
            )
            $0.localStore = LocalStore(
                save: { _, _ in Date(timeIntervalSince1970: 0) },
                listSourceMetaFor: { _ in [:] },
                listDrawsFor: { _ in [] }
            )
        } operation: {
            await SourcesRepoImpl.live.listKnownSources()
        }

        #expect(sources == [Source(name: "mbnet", displayName: "MBNet Server")])
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
            $0.date = .constant(Date(timeIntervalSince1970: 1_000_000))
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
        #expect(source.firstRecrd == MBNetParser.parseDate("27.01.1957"))
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
            $0.date = .constant(Date(timeIntervalSince1970: 1_000_000))
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
}
