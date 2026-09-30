//
//  Chain.swift
//  lottoApp2
//
//  A tree of blocks rooted at an implicit input (spec 003 FR-013/FR-014, research R4). The input always
//  outputs the draws of whichever source a run uses, so a chain is not tied to a source.
//

import Foundation
import IdentifiedCollections

nonisolated struct ChainNode: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    /// `nil` means directly under the chain's input.
    let parentID: UUID?
    var block: Block
}

/// A named, saved tree of blocks. `revision` grows by one on every structural or parameter edit — not on a
/// rename — which is how a shown result knows the chain changed since it ran (FR-021).
nonisolated struct Chain: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var revision: Int
    var nodes: IdentifiedArrayOf<ChainNode>

    static func empty(id: UUID, name: String) -> Chain {
        Chain(id: id, name: name, revision: 0, nodes: [])
    }
}

nonisolated enum ChainError: Error, Hashable, Sendable {
    /// The block can't take its parent's output: it needs one of `needs`, the parent gives `got` (FR-015).
    case inputMismatch(needs: Set<ValueKind>, got: ValueKind)
    case unknownNode
    case invalidParameter(String)
}
