//
//  ChainsRepoImplTests.swift
//  lottoApp2Tests
//

import Dependencies
import Foundation
import IdentifiedCollections
import Testing

@testable import lottoApp2

struct ChainsRepoImplTests {

    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func chain(_ id: Int, _ name: String, nodes: Int = 0) -> Chain {
        Chain(
            id: UUID(id), name: name, revision: nodes,
            nodes: IdentifiedArray(uniqueElements: (0..<nodes).map {
                ChainNode(id: UUID(100 + $0), parentID: nil, block: .countUniqueElements)
            })
        )
    }

    @Test
    func savedChains_areListedBack() async throws {
        let repo = ChainsRepoImpl.fileBacked(root: tempRoot())
        let saved = chain(1, "Top 10", nodes: 2)

        try await repo.saveChain(saved)

        #expect(await repo.listChains() == [saved])
    }

    @Test
    func savingTheSameID_replacesTheChain() async throws {
        let repo = ChainsRepoImpl.fileBacked(root: tempRoot())
        try await repo.saveChain(chain(1, "Draft"))
        try await repo.saveChain(chain(1, "Final", nodes: 1))

        #expect(await repo.listChains() == [chain(1, "Final", nodes: 1)])
    }

    @Test
    func chains_areListedByNameCaseInsensitively_thenByID() async throws {
        let repo = ChainsRepoImpl.fileBacked(root: tempRoot())
        for saved in [chain(3, "beta"), chain(2, "Alpha"), chain(1, "beta")] { try await repo.saveChain(saved) }

        #expect(await repo.listChains().map(\.id) == [UUID(2), UUID(1), UUID(3)])
    }

    @Test
    func deletingAChain_removesItsDirectory() async throws {
        let root = tempRoot()
        let repo = ChainsRepoImpl.fileBacked(root: root)
        try await repo.saveChain(chain(1, "Gone"))

        try await repo.deleteChain(UUID(1))

        #expect(await repo.listChains().isEmpty)
        let dir = root.appendingPathComponent("chains/\(UUID(1).uuidString)", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test
    func anUnreadableChainFile_isSkipped() async throws {
        let root = tempRoot()
        let repo = ChainsRepoImpl.fileBacked(root: root)
        try await repo.saveChain(chain(1, "Good"))
        let broken = root.appendingPathComponent("chains/\(UUID(2).uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: broken.appendingPathComponent("chain.json"))

        #expect(await repo.listChains().map(\.id) == [UUID(1)])
    }

    // MARK: - Saved results and drafts (FR-027 – FR-031)

    private func savedResult(_ id: Int, chain: Int, value: BlockValue, savedAt: TimeInterval = 0) -> SavedResult {
        SavedResult(
            id: UUID(id), chainID: UUID(chain), nodeID: UUID(100), path: [.suffix(100), .countUniqueElements], value: value,
            stamp: RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 2),
            savedAt: Date(timeIntervalSince1970: savedAt)
        )
    }

    @Test
    func savedResults_ofEveryKind_areListedBack_newestFirst() async throws {
        let repo = ChainsRepoImpl.fileBacked(root: tempRoot())
        try await repo.saveChain(chain(1, "Chain"))
        let counts = try BlockEvaluator.evaluate(.countUniqueCombinations, on: .draws(ReferenceDraws.lotto))
        let results = [
            savedResult(10, chain: 1, value: .draws(ReferenceDraws.threeOfFive), savedAt: 1),
            savedResult(11, chain: 1, value: counts, savedAt: 3),
            savedResult(12, chain: 1, value: .number(72), savedAt: 2),
        ]
        for result in results { try await repo.saveResult(result) }

        #expect(await repo.listResults(UUID(1)) == [results[1], results[2], results[0]])
        #expect(await repo.listResults(UUID(2)).isEmpty)
    }

    @Test
    func deletingAResult_removesOnlyThatOne() async throws {
        let repo = ChainsRepoImpl.fileBacked(root: tempRoot())
        try await repo.saveResult(savedResult(10, chain: 1, value: .number(1)))
        try await repo.saveResult(savedResult(11, chain: 1, value: .number(2)))

        try await repo.deleteResult(UUID(10))

        #expect(await repo.listResults(UUID(1)).map(\.id) == [UUID(11)])
    }

    @Test
    func aDraft_isReplacedByANewerOne_andCanBeDeleted() async throws {
        let repo = ChainsRepoImpl.fileBacked(root: tempRoot())
        let stamp = RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 1)
        let first = ChainDraft(chainID: UUID(1), results: [UUID(100): .value(.number(1), stamp)], createdAt: Date(timeIntervalSince1970: 1))
        let second = ChainDraft(
            chainID: UUID(1), results: [UUID(100): .failed(.overBudget(limit: 5_000_000), stamp)], createdAt: Date(timeIntervalSince1970: 2)
        )

        try await repo.putDraft(first)
        try await repo.putDraft(second)
        #expect(await repo.draft(UUID(1)) == second)

        try await repo.deleteDraft(UUID(1))
        #expect(await repo.draft(UUID(1)) == nil)
    }

    @Test
    func deletingAChain_alsoDeletesItsResultsAndDraft() async throws {
        // FR-017 cascade.
        let repo = ChainsRepoImpl.fileBacked(root: tempRoot())
        try await repo.saveChain(chain(1, "Gone"))
        try await repo.saveResult(savedResult(10, chain: 1, value: .number(1)))
        try await repo.putDraft(ChainDraft(chainID: UUID(1), results: [:], createdAt: Date(timeIntervalSince1970: 0)))

        try await repo.deleteChain(UUID(1))

        #expect(await repo.listResults(UUID(1)).isEmpty)
        #expect(await repo.draft(UUID(1)) == nil)
    }
}
