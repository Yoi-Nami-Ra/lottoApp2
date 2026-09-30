//
//  RunResults.swift
//  lottoApp2
//
//  What a run produces and how its results are stamped (spec 003 FR-018–FR-024; research R8, R13–R16).
//

import Foundation

/// A source's stored data at a moment: what a result compares against to know it is out of date.
nonisolated struct SourceDataState: Hashable, Codable, Sendable {
    let recordsCount: Int
    let latestRecord: Date?
    /// Changes whenever the stored draws change, including in-place corrections (research R8).
    let contentDigest: String
}

/// A source's draws together with the data state they were read at — what `gameFor` returns (R16).
nonisolated struct SourceSnapshot: Equatable, Sendable {
    let game: Game
    let dataState: SourceDataState
}

/// Carried by every result: where it came from and which chain revision computed it (FR-021).
nonisolated struct RunStamp: Hashable, Codable, Sendable {
    /// The source id — the key for looking up its current data state.
    let sourceName: String
    /// What screens show; kept so a result still names a source that no longer exists (R15).
    let sourceDisplayName: String
    let dataState: SourceDataState
    let chainRevision: Int
}

/// Why one node produced no value (FR-011, FR-022, FR-023).
nonisolated enum BlockFailure: Error, Hashable, Codable, Sendable {
    case overBudget(limit: Int)
    case invalidParameter(name: String)
    case upstreamFailed
    case cancelled
}

/// One node's result as the editor holds it.
nonisolated enum NodeResult: Hashable, Codable, Sendable {
    case notRun
    case running
    case value(BlockValue, RunStamp)
    case failed(BlockFailure, RunStamp)
}

/// What `ChainRunner` streams: one `.nodeFinished` per node, parents first, then `.finished`.
nonisolated enum RunEvent: Equatable, Sendable {
    case nodeFinished(UUID, Result<BlockValue, BlockFailure>)
    case finished
}

/// Whether a result still describes its source's current data (FR-021, FR-030).
nonisolated enum ResultFreshness: Hashable, Sendable {
    case current
    case outOfDate
    case sourceUnavailable
}

/// The short summary a node that ran shows (FR-024, R14). Views map each case to copy.
nonisolated enum ValueSummary: Hashable, Sendable {
    case draws(count: Int)
    case elements(count: Int)
    case combinations(unique: Int, repeating: Int)
    case subCombinations(unique: Int, size: Int)
    case number(Int)
    case empty(ValueKind)
}

/// A kept copy of one block's output (FR-027, FR-028): the value, the blocks that produced it, and where and
/// when it came from.
nonisolated struct SavedResult: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let chainID: UUID
    let nodeID: UUID
    /// The blocks from the chain's input down to the saved block, as they were when it ran. Stays the
    /// description of what produced the value even after the chain is edited (FR-030).
    let path: [Block]
    let value: BlockValue
    let stamp: RunStamp
    let savedAt: Date
}

/// A chain's unsaved results, kept when the app goes to the background and offered back when the chain is
/// next opened (FR-031). At most one per chain; holds only `.value` and `.failed` results.
nonisolated struct ChainDraft: Hashable, Codable, Sendable {
    let chainID: UUID
    let results: [UUID: NodeResult]
    let createdAt: Date
}
