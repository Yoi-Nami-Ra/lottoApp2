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

        try await store.save([draw(1, 1), draw(2, 2), draw(3, 3)], mbnet, fixed, 0)
        // second save overlaps index 3 and adds 4 — index 1 & 2 must survive (additive union).
        try await store.save([draw(3, 3), draw(4, 4)], mbnet, fixed, 0)

        let stored = await store.listDrawsFor("mbnet")
        #expect(stored.map(\.index) == [1, 2, 3, 4])
    }

    @Test
    func metaIsDerivedFromMergedSet() async throws {
        let store = LocalStore.fileBacked(root: tempRoot())
        let fixed = Date(timeIntervalSince1970: 1_000_000)

        try await store.save([draw(1, 5), draw(2, 1), draw(3, 9)], mbnet, fixed, 0)

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

        try await store.save([], mbnet, fixed, 0)

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

        try await store.save([draw(1, 1, numbers)], mbnet, Date(timeIntervalSince1970: 1), 0)

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
                group.addTask { try await store.save(batch, mbnet, fixed, 0) }
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

        let elapsed = try await withTaskExecutorPreference(DedicatedQueueExecutor()) {
            try await Self.timeParseAndSave(body, into: store, source: mbnet)
        }

        #expect(await store.listDrawsFor("mbnet").count == 7380)
        #expect(elapsed < .seconds(1), "parse + persist took \(elapsed)")
    }

    /// Times parse + persist on the preferred task executor only. In a parallel run, a live `TestStore` reroutes
    /// every global-executor job onto the main thread, so timing on main — or on the global pool — would count
    /// seconds of queueing behind other suites, not the work under test. Under a task-executor preference the
    /// parse and `FileStore`'s actor job both run on a dedicated queue, and the clock reads bracket only them.
    @concurrent
    private nonisolated static func timeParseAndSave(
        _ body: String, into store: LocalStore, source: RemoteSource
    ) async throws -> Duration {
        let start = ContinuousClock.now
        let draws = MBNetParser.parse(body).draws
        try await store.save(draws, source, Date(timeIntervalSince1970: 1), 0)
        return ContinuousClock.now - start
    }

    /// A task executor that runs its jobs on its own serial queue, out of reach of TCA's main-serial executor.
    private nonisolated final class DedicatedQueueExecutor: TaskExecutor {
        private let queue = DispatchQueue(label: "LocalStore_Tests.budget", qos: .userInitiated)

        func enqueue(_ job: consuming ExecutorJob) {
            let job = UnownedJob(job)
            queue.async { job.runSynchronously(on: self.asUnownedTaskExecutor()) }
        }
    }

    // MARK: - Last sync's skipped count (spec 005)

    @Test(arguments: [false, true])
    func savePersistsTheSkippedCount_andTheNextSaveReplacesIt(inMemory: Bool) async throws {
        // FR-004/FR-005: the count is stored with the meta, and a later successful sync — even one with 0 —
        // replaces it rather than adding to it.
        let store = inMemory ? LocalStore.inMemory() : LocalStore.fileBacked(root: tempRoot())
        let fixed = Date(timeIntervalSince1970: 1_000_000)

        try await store.save([draw(1, 1)], mbnet, fixed, 3)
        #expect(await store.listSourceMetaFor(["mbnet"])["mbnet"]?.lastSyncSkipped == 3)

        try await store.save([draw(2, 2)], mbnet, fixed, 0)
        #expect(await store.listSourceMetaFor(["mbnet"])["mbnet"]?.lastSyncSkipped == 0)
    }

    @Test
    func theSkippedCountSurvivesANewStoreOnTheSameRoot() async throws {
        // FR-004 / US2-AS1: a relaunch builds a fresh store over the same directory.
        let root = tempRoot()
        try await LocalStore.fileBacked(root: root).save([draw(1, 1)], mbnet, Date(timeIntervalSince1970: 1), 3)

        let reopened = LocalStore.fileBacked(root: root)
        #expect(await reopened.listSourceMetaFor(["mbnet"])["mbnet"]?.lastSyncSkipped == 3)
    }

    @Test
    func metaWrittenBeforeTheSkippedCountExisted_readsAsZero() async throws {
        // FR-013: a `meta.json` from an earlier build has no `lastSyncSkipped` key and must still load.
        let root = tempRoot()
        let dir = root.appendingPathComponent("sources/mbnet", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"name":"mbnet","lastSync":0,"recordsCount":1,"contentDigest":""}"#.utf8)
            .write(to: dir.appendingPathComponent("meta.json"))

        let meta = try #require(await LocalStore.fileBacked(root: root).listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(meta.recordsCount == 1)
        #expect(meta.lastSyncSkipped == 0)
    }

    // MARK: - Draw cadence (spec 009 contracts §2)

    /// Tuesday / Thursday / Saturday draws from 3 to 30 Sep 2026, plus the latest on Wednesday 30 Sep: the
    /// window [Mon 14 Sep, Mon 28 Sep) holds 6 of them.
    private var threeAWeek: [DrawDTO] {
        ["03", "05", "08", "10", "12", "15", "17", "19", "22", "24", "26", "29", "30"].enumerated().map { i, day in
            DrawDTO(index: i + 1, date: MBNetParser.parseDate("\(day).09.2026")!, numbers: [1, 2, 3, 4, 5, 6])
        }
    }

    @Test(arguments: [false, true])
    func saveStoresTheCadenceOfTheMergedSet(inMemory: Bool) async throws {
        // FR-003: measured over everything stored, not just this fetch — here split across two saves.
        let store = inMemory ? LocalStore.inMemory() : LocalStore.fileBacked(root: tempRoot())
        let draws = threeAWeek

        try await store.save(Array(draws.prefix(7)), mbnet, Date(timeIntervalSince1970: 1), 0)
        try await store.save(Array(draws.dropFirst(7)), mbnet, Date(timeIntervalSince1970: 2), 0)

        #expect(await store.listSourceMetaFor(["mbnet"])["mbnet"]?.drawsInWindow == 6)
    }

    @Test
    func theCadenceSurvivesANewStoreOnTheSameRoot() async throws {
        // Clarification 1: persisted with the metadata, so a relaunch lists it without re-reading the draws.
        let root = tempRoot()
        try await LocalStore.fileBacked(root: root).save(threeAWeek, mbnet, Date(timeIntervalSince1970: 1), 0)

        #expect(await LocalStore.fileBacked(root: root).listSourceMetaFor(["mbnet"])["mbnet"]?.drawsInWindow == 6)
    }

    @Test
    func aHistoryTooShortForTheWindow_storesNoCadence() async throws {
        // FR-002: only the last week and a half — the history doesn't reach back to Monday 14 Sep.
        let store = LocalStore.fileBacked(root: tempRoot())
        try await store.save(Array(threeAWeek.suffix(5)), mbnet, Date(timeIntervalSince1970: 1), 0)

        let meta = try #require(await store.listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(meta.drawsInWindow == nil)
    }

    @Test
    func metaWrittenBeforeTheCadenceExisted_readsAsNone() async throws {
        // FR-003: a `meta.json` from an earlier build has no `drawsInWindow` and must still load.
        let root = tempRoot()
        let dir = root.appendingPathComponent("sources/mbnet", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"name":"mbnet","lastSync":0,"recordsCount":1,"contentDigest":"","lastSyncSkipped":2}"#.utf8)
            .write(to: dir.appendingPathComponent("meta.json"))

        let meta = try #require(await LocalStore.fileBacked(root: root).listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(meta.lastSyncSkipped == 2)
        #expect(meta.drawsInWindow == nil)
    }

    @Test
    func inMemoryStoreMirrorsFileBackedSemantics() async throws {
        // The preview value must behave like the real thing, or previews lie about the UI's states.
        let store = LocalStore.inMemory()
        let fixed = Date(timeIntervalSince1970: 1_000_000)

        try await store.save([draw(1, 1), draw(2, 2)], mbnet, fixed, 0)
        try await store.save([draw(2, 2), draw(3, 3)], mbnet, fixed, 0)

        #expect(await store.listDrawsFor("mbnet").map(\.index) == [1, 2, 3])
        let meta = try #require(await store.listSourceMetaFor(["mbnet"])["mbnet"])
        #expect(meta.recordsCount == 3)
        #expect(meta.lastSync == fixed)
    }
}
