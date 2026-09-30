//
//  ChainsRepo.swift
//  lottoApp2
//
//  Contract for keeping chains across launches (spec 003 FR-017; contracts §4). The file-backed
//  implementation lives in the Data layer.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections

nonisolated struct ChainsRepo: Sendable {
    /// Every saved chain, by name (case-insensitive), id as tie-break.
    var listChains: @Sendable () async -> [Chain]
    /// Inserts or replaces the chain with this id.
    var saveChain: @Sendable (Chain) async throws -> Void
    /// Deletes the chain and everything kept with it — its saved results and draft (FR-017).
    var deleteChain: @Sendable (Chain.ID) async throws -> Void

    // Saved results (FR-027 – FR-030)
    /// A chain's saved results, newest first.
    var listResults: @Sendable (Chain.ID) async -> [SavedResult]
    var saveResult: @Sendable (SavedResult) async throws -> Void
    var deleteResult: @Sendable (SavedResult.ID) async throws -> Void

    // Drafts (FR-031)
    var draft: @Sendable (Chain.ID) async -> ChainDraft?
    /// Stores the chain's draft, replacing any earlier one.
    var putDraft: @Sendable (ChainDraft) async throws -> Void
    var deleteDraft: @Sendable (Chain.ID) async throws -> Void
}

nonisolated extension ChainsRepo {
    /// Orders chains the way `listChains` promises.
    static func listed(_ chains: some Sequence<Chain>) -> [Chain] {
        chains.sorted { lhs, rhs in
            switch lhs.name.localizedCaseInsensitiveCompare(rhs.name) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    /// Orders saved results the way `listResults` promises: newest first, id as tie-break.
    static func listed(_ results: some Sequence<SavedResult>) -> [SavedResult] {
        results.sorted { lhs, rhs in
            lhs.savedAt != rhs.savedAt ? lhs.savedAt > rhs.savedAt : lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Keeps everything in memory only — for `#Preview`s, which must never touch Application Support.
    static func inMemory(seed: [Chain] = [], results seedResults: [SavedResult] = []) -> ChainsRepo {
        let storage = LockIsolated(IdentifiedArray(uniqueElements: seed))
        let results = LockIsolated(IdentifiedArray(uniqueElements: seedResults))
        let drafts = LockIsolated<[Chain.ID: ChainDraft]>([:])
        return ChainsRepo(
            listChains: { listed(storage.value) },
            saveChain: { chain in storage.withValue { $0[id: chain.id] = chain } },
            deleteChain: { id in
                storage.withValue { _ = $0.remove(id: id) }
                results.withValue { $0.removeAll { $0.chainID == id } }
                drafts.withValue { $0[id] = nil }
            },
            listResults: { chainID in listed(results.value.filter { $0.chainID == chainID }) },
            saveResult: { result in results.withValue { $0[id: result.id] = result } },
            deleteResult: { id in results.withValue { _ = $0.remove(id: id) } },
            draft: { chainID in drafts.value[chainID] },
            putDraft: { draft in drafts.withValue { $0[draft.chainID] = draft } },
            deleteDraft: { chainID in drafts.withValue { $0[chainID] = nil } }
        )
    }
}

extension ChainsRepo: nonisolated DependencyKey {
    nonisolated static let liveValue = ChainsRepoImpl.live
    nonisolated static var previewValue: ChainsRepo { .inMemory() }
    nonisolated static let testValue = ChainsRepo(
        listChains: unimplemented("ChainsRepo.listChains", placeholder: []),
        saveChain: unimplemented("ChainsRepo.saveChain"),
        deleteChain: unimplemented("ChainsRepo.deleteChain"),
        listResults: unimplemented("ChainsRepo.listResults", placeholder: []),
        saveResult: unimplemented("ChainsRepo.saveResult"),
        deleteResult: unimplemented("ChainsRepo.deleteResult"),
        draft: unimplemented("ChainsRepo.draft", placeholder: nil),
        putDraft: unimplemented("ChainsRepo.putDraft"),
        deleteDraft: unimplemented("ChainsRepo.deleteDraft")
    )
}

extension DependencyValues {
    nonisolated var chainsRepo: ChainsRepo {
        get { self[ChainsRepo.self] }
        set { self[ChainsRepo.self] = newValue }
    }
}
