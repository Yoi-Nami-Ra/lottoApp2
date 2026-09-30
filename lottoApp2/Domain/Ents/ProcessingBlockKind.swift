//
//  ProcessingBlockKind.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//

import Foundation

/// One kind of processing the app can apply to a game's history.
///
/// This is the **catalogue identity**: `allCases` is the list of blocks the app offers, and `rawValue` is the
/// stable id. What a block takes and returns, and its parameters, live in `Block`; `defaultBlock` is the
/// configured block a kind starts as when it is added to a chain.
///
/// The human-readable label lives in the Presentation layer, so no UI copy reaches the Domain.
nonisolated enum ProcessingBlockKind: String, CaseIterable, Equatable, Sendable {
    case dropFirst
    case dropLast
    case prefix
    case suffix
    case sortByDate
    case sortByIndex
    case sortByCount
    case countUniqueElements
    case countUniqueCombinations
    case countUniqueSubCombinations
    case countAllElements

    /// Defaults per LTA-22: x = 10 for filters; count descending, date and index ascending; z = 2 (pairs).
    var defaultBlock: Block {
        switch self {
        case .dropFirst: .dropFirst(10)
        case .dropLast: .dropLast(10)
        case .prefix: .prefix(10)
        case .suffix: .suffix(10)
        case .sortByDate: .sortByDate(.ascending)
        case .sortByIndex: .sortByIndex(.ascending)
        case .sortByCount: .sortByCount(.descending)
        case .countUniqueElements: .countUniqueElements
        case .countUniqueCombinations: .countUniqueCombinations
        case .countUniqueSubCombinations: .countUniqueSubCombinations(z: 2)
        case .countAllElements: .countAllElements
        }
    }
}
