//
//  LocalStoreTests.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 30/07/2026.
//

import Dependencies
import Foundation
import Testing

@testable import lottoApp2

struct LocalStore_Tests {

    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private let mbnet = RemoteSource(name: "mbnet", displayName: "MBNet Server") { .init(draws: [], skipped: 0) }

    private func draw(_ index: Int, _ day: Int, _ numbers: [Int] = [1, 2, 3, 4, 5, 6]) -> DrawDTO {
        DrawDTO(index: index, date: MBNetParser.parseDate("\(String(format: "%02d", day)).01.2000")!, numbers: numbers)
    }

    @Test
    func additiveUnionHasNoDuplicatesAndNoLosses() async throws {
        let store = LocalStore.fileBacked(root: tempRoot())
        let fixed = Date(timeIntervalSince1970: 1_000_000)

        try await store.save([draw(1, 1), draw(2, 2), draw(3, 3)], mbnet, fixed)
        // second save overlaps index 3 and adds 4 — index 1 & 2 must survive (additive union).
        try await store.save([draw(3, 3), draw(4, 4)], mbnet, fixed)

        let stored = await store.listDrawsFor("mbnet")
        #expect(stored.map(\.index) == [1, 2, 3, 4])
    }

    @Test
    func metaIsDerivedFromMergedSet() async throws {
        let store = LocalStore.fileBacked(root: tempRoot())
        let fixed = Date(timeIntervalSince1970: 1_000_000)

        try await store.save([draw(1, 5), draw(2, 1), draw(3, 9)], mbnet, fixed)

        let meta = try #require(await store.listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(meta.recordsCount == 3)
        #expect(meta.lastSync == fixed)
        #expect(meta.firstRecord == MBNetParser.parseDate("01.01.2000"))
        #expect(meta.latestRecord == MBNetParser.parseDate("09.01.2000"))
    }

    @Test
    func emptyHistoryYieldsZeroCountAndNilDates() async throws {
        // Spec Edge Cases → Empty history: a successful save of 0 draws is representable (no crash).
        let store = LocalStore.fileBacked(root: tempRoot())
        let fixed = Date(timeIntervalSince1970: 2_000_000)

        try await store.save([], mbnet, fixed)

        let meta = try #require(await store.listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(meta.recordsCount == 0)
        #expect(meta.firstRecord == nil)
        #expect(meta.latestRecord == nil)
        #expect(meta.lastSync == fixed)
    }

    @Test
    func roundTripsDrawNumbers() async throws {
        // US3 / FR-004 / SC-003: persisted draws keep their six numbers intact.
        let store = LocalStore.fileBacked(root: tempRoot())
        let numbers = [7, 9, 20, 31, 38, 43]

        try await store.save([draw(1, 1, numbers)], mbnet, Date(timeIntervalSince1970: 1))

        let stored = await store.listDrawsFor("mbnet")
        #expect(stored.first?.numbers == numbers)
    }

    @Test
    func concurrentSavesForOneSourceLoseNothing() async throws {
        // FR-008 regression: `save` is a read-modify-write, so overlapping saves used to interleave and drop
        // draws. Serialized access must make the union of every batch survive.
        let store = LocalStore.fileBacked(root: tempRoot())
        let fixed = Date(timeIntervalSince1970: 1_000_000)
        let batches = (0..<8).map { batch in (1...5).map { draw(batch * 5 + $0, 1) } }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for batch in batches {
                group.addTask { try await store.save(batch, mbnet, fixed) }
            }
            try await group.waitForAll()
        }

        let stored = await store.listDrawsFor("mbnet")
        #expect(stored.map(\.index) == Array(1...40))
        #expect(await store.listSourceMetaFor(["mbnet"])["mbnet"]?.recordsCount == 40)
    }

    @Test
    func parseAndPersistFullHistoryWithinBudget() async throws {
        // SC-006: parse + persist of the full-history fixture completes in ≤1s.
        let store = LocalStore.fileBacked(root: tempRoot())
        let body = (1...7380).map { "\($0). 01.01.2000 1,2,3,4,5,6" }.joined(separator: "\n")

        let start = ContinuousClock.now
        let draws = MBNetParser.parse(body).draws
        try await store.save(draws, mbnet, Date(timeIntervalSince1970: 1))
        let elapsed = ContinuousClock.now - start

        #expect(await store.listDrawsFor("mbnet").count == 7380)
        #expect(elapsed < .seconds(1))
    }

    @Test
    func inMemoryStoreMirrorsFileBackedSemantics() async throws {
        // The preview value must behave like the real thing, or previews lie about the UI's states.
        let store = LocalStore.inMemory()
        let fixed = Date(timeIntervalSince1970: 1_000_000)

        try await store.save([draw(1, 1), draw(2, 2)], mbnet, fixed)
        try await store.save([draw(2, 2), draw(3, 3)], mbnet, fixed)

        #expect(await store.listDrawsFor("mbnet").map(\.index) == [1, 2, 3])
        let meta = try #require(await store.listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(meta.recordsCount == 3)
        #expect(meta.lastSync == fixed)
    }
}
