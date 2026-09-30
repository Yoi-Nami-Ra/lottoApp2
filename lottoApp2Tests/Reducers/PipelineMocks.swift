//
//  PipelineMocks.swift
//  lottoApp2Tests
//
//  Test doubles for the pipeline seams: an in-memory `ChainsRepo` whose contents a test can assert on, and
//  runners that replay a script or let the test drive the stream.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections

@testable import lottoApp2

nonisolated extension ChainsRepo {
    /// An in-memory repo over `storage`, so a test can seed it and assert on what was written.
    static func inMemory(
        _ storage: LockIsolated<IdentifiedArrayOf<Chain>>,
        results: LockIsolated<IdentifiedArrayOf<SavedResult>> = .init([]),
        drafts: LockIsolated<[Chain.ID: ChainDraft]> = .init([:])
    ) -> ChainsRepo {
        ChainsRepo(
            listChains: { Array(storage.value) },
            saveChain: { chain in storage.withValue { $0[id: chain.id] = chain } },
            deleteChain: { id in
                storage.withValue { _ = $0.remove(id: id) }
                results.withValue { $0.removeAll { $0.chainID == id } }
                drafts.withValue { $0[id] = nil }
            },
            listResults: { chainID in results.value.filter { $0.chainID == chainID } },
            saveResult: { result in results.withValue { $0[id: result.id] = result } },
            deleteResult: { id in results.withValue { _ = $0.remove(id: id) } },
            draft: { chainID in drafts.value[chainID] },
            putDraft: { draft in drafts.withValue { $0[draft.chainID] = draft } },
            deleteDraft: { chainID in drafts.withValue { $0[chainID] = nil } }
        )
    }
}

nonisolated extension ChainRunner {
    /// Replays `events` for every run, whatever the chain.
    static func scripted(_ events: [RunEvent]) -> ChainRunner {
        ChainRunner { _, _ in
            AsyncStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
    }

    /// A runner whose streams the test feeds by hand. Each `run` call appends a continuation, in call order.
    static func controlled() -> (ChainRunner, LockIsolated<[AsyncStream<RunEvent>.Continuation]>) {
        let continuations = LockIsolated<[AsyncStream<RunEvent>.Continuation]>([])
        let runner = ChainRunner { _, _ in
            let (stream, continuation) = AsyncStream<RunEvent>.makeStream()
            continuations.withValue { $0.append(continuation) }
            return stream
        }
        return (runner, continuations)
    }
}

extension LockIsolated where Value == [AsyncStream<RunEvent>.Continuation] {
    /// Waits until `count` runs have started streaming. A run's stream is created inside its effect, which
    /// can start after the action that returned it was received.
    func waitForRuns(_ count: Int) async {
        while value.count < count { await Task.yield() }
    }
}

nonisolated extension Chain {
    static let emptyMock = Chain.empty(id: UUID(0), name: "New chain")

    /// input → Count Unique Elements, at revision 1.
    static let countOnlyMock = Chain(
        id: UUID(0), name: "Counts", revision: 1,
        nodes: [ChainNode(id: UUID(10), parentID: nil, block: .countUniqueElements)]
    )
}

nonisolated extension SavedResult {
    /// A saved Count Unique Elements result of `Chain.countOnlyMock`'s node.
    static func mock(_ id: Int, source: String = "mbnet", state: SourceDataState = .mbnetMock) -> SavedResult {
        SavedResult(
            id: UUID(id), chainID: Chain.countOnlyMock.id, nodeID: UUID(10), path: [.countUniqueElements], value: .number(id),
            stamp: RunStamp(sourceName: source, sourceDisplayName: source, dataState: state, chainRevision: 1),
            savedAt: Date(timeIntervalSince1970: TimeInterval(id))
        )
    }
}

nonisolated extension ChainDraft {
    static let mock = ChainDraft(
        chainID: Chain.countOnlyMock.id,
        results: [UUID(10): .value(.number(7), RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 1))],
        createdAt: Date(timeIntervalSince1970: 50)
    )
}

nonisolated extension SourceDataState {
    static let mbnetMock = SourceDataState(recordsCount: 3, latestRecord: ReferenceDraws.day(3), contentDigest: "mbnet-1")
}
