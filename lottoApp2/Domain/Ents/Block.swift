//
//  Block.swift
//  lottoApp2
//
//  One processing step and its parameters (spec 003 FR-010, research R3). A value type, so it lives in
//  reducer state and is saved with a chain as-is.
//

import Foundation

nonisolated enum Block: Hashable, Codable, Sendable {
    // Filters (FR-005, FR-006): x is a whole number ≥ 0, clamped to the input's size.
    case dropFirst(UInt)
    case dropLast(UInt)
    case prefix(UInt)
    case suffix(UInt)
    // Sorts (FR-007, FR-009)
    case sortByDate(SortDirection)
    case sortByIndex(SortDirection)
    case sortByCount(SortDirection)
    // Counts (FR-010)
    case countUniqueElements
    case countUniqueCombinations
    /// z is at least 2 (checked when set) and below x of the run's source (checked when it runs) — FR-011.
    case countUniqueSubCombinations(z: Int)
    /// Ends a branch: its single number feeds nothing (FR-012).
    case countAllElements

    /// The kinds this block can take as input — the attach rule (FR-010, FR-015).
    var accepts: Set<ValueKind> {
        switch self {
        case .dropFirst, .dropLast, .prefix, .suffix: [.draws, .counts]
        case .sortByDate, .sortByIndex: [.draws]
        case .sortByCount: [.counts]
        case .countUniqueElements, .countUniqueCombinations, .countUniqueSubCombinations, .countAllElements: [.draws]
        }
    }

    /// The catalogue entry this block is a configured instance of.
    var kind: ProcessingBlockKind {
        switch self {
        case .dropFirst: .dropFirst
        case .dropLast: .dropLast
        case .prefix: .prefix
        case .suffix: .suffix
        case .sortByDate: .sortByDate
        case .sortByIndex: .sortByIndex
        case .sortByCount: .sortByCount
        case .countUniqueElements: .countUniqueElements
        case .countUniqueCombinations: .countUniqueCombinations
        case .countUniqueSubCombinations: .countUniqueSubCombinations
        case .countAllElements: .countAllElements
        }
    }

    /// The kind this block returns for `input`, which must be one it `accepts`.
    func output(given input: ValueKind) -> ValueKind {
        switch self {
        case .dropFirst, .dropLast, .prefix, .suffix: input
        case .sortByDate, .sortByIndex: .draws
        case .sortByCount: .counts
        case .countUniqueElements, .countUniqueCombinations, .countUniqueSubCombinations: .counts
        case .countAllElements: .number
        }
    }
}
