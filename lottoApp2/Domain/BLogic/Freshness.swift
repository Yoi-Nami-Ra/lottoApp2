//
//  Freshness.swift
//  lottoApp2
//
//  Whether a result still describes what produced it (spec 003 FR-021, FR-030; research R13). A result is
//  always judged against the current state of *its own* source, looked up by the stamp's source id.
//

import Foundation

nonisolated extension NodeResult {
    /// A shown result is out of date when the chain was edited since it ran, or its source's data changed.
    /// A source with no current state reads as unavailable, which takes precedence.
    func freshness(chainRevision: Int, dataStates: [String: SourceDataState?]) -> ResultFreshness {
        let stamp: RunStamp
        switch self {
        case .notRun, .running: return .current
        case .value(_, let ranWith), .failed(_, let ranWith): stamp = ranWith
        }
        guard let current = dataStates[stamp.sourceName] ?? nil else { return .sourceUnavailable }
        return stamp.chainRevision == chainRevision && stamp.dataState == current ? .current : .outOfDate
    }
}

nonisolated extension SavedResult {
    /// A saved result goes out of date only when its own source's data changes — editing the chain doesn't
    /// (FR-030). A source with no current state reads as unavailable.
    func freshness(dataStates: [String: SourceDataState?]) -> ResultFreshness {
        guard let current = dataStates[stamp.sourceName] ?? nil else { return .sourceUnavailable }
        return stamp.dataState == current ? .current : .outOfDate
    }

    /// Whether the chain was edited since this result ran — information only (FR-030).
    func chainChanged(since chain: Chain) -> Bool {
        stamp.chainRevision != chain.revision
    }
}
