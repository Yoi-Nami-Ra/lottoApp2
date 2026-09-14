//
//  ProcessingBlockKind.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//

import Foundation

/// One kind of processing the app can apply to a game's history.
///
/// This is a **catalogue identity only**: `allCases` is the list of blocks the app offers, and `rawValue`
/// is the stable id. It deliberately says nothing about what a block consumes or produces, how blocks
/// compose, or how a chain executes — those types are still to be specified, and guessing at them here
/// would fix the pipeline's shape before it has been designed.
///
/// The human-readable label lives in the Presentation layer, so no UI copy reaches the Domain.
nonisolated enum ProcessingBlockKind: String, CaseIterable, Equatable, Sendable {
    case countUniqueElements
}
