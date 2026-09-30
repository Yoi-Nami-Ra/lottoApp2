//
//  LocalStoreDigestTests.swift
//  lottoApp2Tests
//
//  The content digest that lets results notice a sync that changed a source's draws (research R8).
//

import Foundation
import Testing

@testable import lottoApp2

struct LocalStoreDigestTests {

    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private let mbnet = RemoteSource(name: "mbnet", displayName: "MBNet Server") { .init(draws: [], skipped: 0) }
    private let asOf = Date(timeIntervalSince1970: 1_000_000)

    private func draw(_ index: Int, _ day: Int, _ numbers: [Int]) -> DrawDTO {
        DrawDTO(index: index, date: Date(timeIntervalSince1970: TimeInterval(day) * 86_400), numbers: numbers)
    }

    private func storedMeta(after saves: [[DrawDTO]]) async throws -> SourceMeta {
        let store = LocalStore.fileBacked(root: tempRoot())
        for draws in saves { try await store.save(draws, mbnet, asOf, 0) }
        return try #require(await store.listSourceMetaFor(["mbnet"])["mbnet"])
    }

    @Test
    func digest_ignoresTheOrderDrawsAndTheirNumbersArriveIn() async throws {
        let one = try await storedMeta(after: [[draw(1, 1, [1, 2, 3, 4, 5, 6]), draw(2, 2, [7, 8, 9, 10, 11, 12])]])
        let two = try await storedMeta(after: [[draw(2, 2, [12, 11, 10, 9, 8, 7]), draw(1, 1, [6, 5, 4, 3, 2, 1])]])
        #expect(!one.contentDigest.isEmpty)
        #expect(one.contentDigest == two.contentDigest)
    }

    @Test
    func digest_changesWhenADrawIsCorrectedInPlace() async throws {
        // Same index, same date, different numbers: count and latest date can't see this; the digest must.
        let before = try await storedMeta(after: [[draw(1, 1, [1, 2, 3, 4, 5, 6])]])
        let after = try await storedMeta(after: [[draw(1, 1, [1, 2, 3, 4, 5, 6])], [draw(1, 1, [1, 2, 3, 4, 5, 7])]])
        #expect(before.recordsCount == after.recordsCount)
        #expect(before.latestRecord == after.latestRecord)
        #expect(before.contentDigest != after.contentDigest)
    }

    @Test
    func digest_changesWhenADrawIsAdded() async throws {
        let before = try await storedMeta(after: [[draw(1, 1, [1, 2, 3, 4, 5, 6])]])
        let after = try await storedMeta(after: [[draw(1, 1, [1, 2, 3, 4, 5, 6])], [draw(2, 2, [7, 8, 9, 10, 11, 12])]])
        #expect(before.contentDigest != after.contentDigest)
    }

    @Test
    func metaWrittenBeforeTheDigestExisted_stillDecodes() async throws {
        let root = tempRoot()
        let dir = root.appendingPathComponent("sources/mbnet", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"name":"mbnet","lastSync":0,"recordsCount":0}"#.utf8)
            .write(to: dir.appendingPathComponent("meta.json"))

        let meta = try #require(await LocalStore.fileBacked(root: root).listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(meta.contentDigest == "")
        #expect(meta.recordsCount == 0)
    }
}
