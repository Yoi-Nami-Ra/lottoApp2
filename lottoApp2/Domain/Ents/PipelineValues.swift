//
//  PipelineValues.swift
//  lottoApp2
//
//  The three kinds of data that flow between blocks (spec 003 FR-003/FR-004, research R2).
//

import Foundation

/// The kind of a block's input or output.
nonisolated enum ValueKind: String, Hashable, Codable, Sendable, CaseIterable {
    case draws
    case counts
    case number
}

/// Direction of every sort (FR-009).
nonisolated enum SortDirection: String, Hashable, Codable, Sendable, CaseIterable {
    case ascending
    case descending
}

/// What a count result counts. Ordered within a case: elements ascending, combinations and
/// sub-combinations element by element (FR-008).
nonisolated enum CountItem: Hashable, Codable, Sendable, Comparable {
    case element(Element)
    case combination(Combination)
    case subCombination(SubCombination)
}

/// A unique item and how many times it occurs. Invariant: count ≥ 1 (FR-004).
nonisolated struct UniqueCount: Hashable, Codable, Sendable {
    let item: CountItem
    let count: Int

    init(item: CountItem, count: Int) throws(DomainError) {
        guard count >= 1 else { throw .invalidCount(count) }
        self.item = item
        self.count = count
    }
}

/// (item, count) pairs, each item once. Unsorted it has no order of its own and is stored item-ascending, so
/// equal results compare equal and display is fixed (FR-025); after sort by count it is an ordered list.
nonisolated struct CountResult: Hashable, Codable, Sendable {
    nonisolated enum Ordering: Hashable, Codable, Sendable {
        case unordered
        case byCount(SortDirection)
    }

    let counts: [UniqueCount]
    let ordering: Ordering

    /// A result with no ranking, stored in its canonical item-ascending form.
    init(unordered counts: [UniqueCount]) {
        self.counts = counts.sorted { $0.item < $1.item }
        self.ordering = .unordered
    }

    /// A result kept exactly in the given order — a ranking, or a filtered slice of one.
    init(counts: [UniqueCount], ordering: Ordering) {
        self.counts = counts
        self.ordering = ordering
    }
}

/// A value flowing between blocks.
nonisolated enum BlockValue: Hashable, Codable, Sendable {
    case draws(Game)
    case counts(CountResult)
    case number(Int)

    var kind: ValueKind {
        switch self {
        case .draws: .draws
        case .counts: .counts
        case .number: .number
        }
    }
}
