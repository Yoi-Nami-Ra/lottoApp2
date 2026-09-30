//
//  ResultSummary.swift
//  lottoApp2
//
//  The short summary a node that ran shows (spec 003 FR-024, research R14). Data, not copy: views map each
//  `ValueSummary` case to a token.
//

import Foundation

nonisolated enum ResultSummary {
    static func summary(of value: BlockValue) -> ValueSummary {
        switch value {
        case .draws(let game):
            game.entries.isEmpty ? .empty(.draws) : .draws(count: game.entries.count)
        case .counts(let result):
            summary(of: result)
        case .number(let total):
            .number(total)
        }
    }

    /// A count result is one kind of item throughout, so its first item says what it counts.
    private static func summary(of result: CountResult) -> ValueSummary {
        switch result.counts.first?.item {
        case nil: .empty(.counts)
        case .element: .elements(count: result.counts.count)
        case .combination: .combinations(unique: result.counts.count, repeating: result.counts.count(where: { $0.count >= 2 }))
        case .subCombination(let sub): .subCombinations(unique: result.counts.count, size: sub.elements.count)
        }
    }
}
