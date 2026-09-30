//
//  ChainRules.swift
//  lottoApp2
//
//  Pure rules for building and editing a chain (spec 003 FR-010, FR-015, FR-016; research R5). Every rule
//  returns a new chain or throws, so a refused edit leaves the chain unchanged by construction.
//

import Foundation
import IdentifiedCollections

nonisolated extension Chain {

    // MARK: - Kinds

    /// The kind `nodeID` outputs; `nil` is the chain's input, which always outputs draws.
    func outputKind(of nodeID: ChainNode.ID?) throws(ChainError) -> ValueKind {
        guard let nodeID else { return .draws }
        guard let node = nodes[id: nodeID] else { throw .unknownNode }
        return node.block.output(given: try outputKind(of: node.parentID))
    }

    // MARK: - Edits

    /// Adds `block` under `parentID` as node `id`. The caller supplies the id (from `@Dependency(\.uuid)`),
    /// so the rule stays deterministic.
    func attaching(_ block: Block, under parentID: ChainNode.ID?, id: ChainNode.ID) throws(ChainError) -> (Chain, ChainNode.ID) {
        try block.validateParameters()
        let parentOutput = try outputKind(of: parentID)
        guard block.accepts.contains(parentOutput) else {
            throw .inputMismatch(needs: block.accepts, got: parentOutput)
        }
        var chain = self
        chain.nodes.append(ChainNode(id: id, parentID: parentID, block: block))
        chain.revision += 1
        return (chain, id)
    }

    /// Replaces a node's block. Refused when the new block can't take its parent's output, or when a child
    /// can't take the new block's output.
    func updating(_ nodeID: ChainNode.ID, to block: Block) throws(ChainError) -> Chain {
        guard let node = nodes[id: nodeID] else { throw .unknownNode }
        try block.validateParameters()
        let parentOutput = try outputKind(of: node.parentID)
        guard block.accepts.contains(parentOutput) else {
            throw .inputMismatch(needs: block.accepts, got: parentOutput)
        }
        let output = block.output(given: parentOutput)
        for child in children(of: nodeID) where !child.block.accepts.contains(output) {
            throw .inputMismatch(needs: child.block.accepts, got: output)
        }
        var chain = self
        chain.nodes[id: nodeID]?.block = block
        chain.revision += 1
        return chain
    }

    /// Removes a node and its whole subtree; `removed` counts every node that went.
    func removingSubtree(_ nodeID: ChainNode.ID) throws(ChainError) -> (Chain, removed: Int) {
        guard nodes[id: nodeID] != nil else { throw .unknownNode }
        var doomed: Set<ChainNode.ID> = [nodeID]
        var frontier = [nodeID]
        while let next = frontier.popLast() {
            for child in children(of: next) where doomed.insert(child.id).inserted {
                frontier.append(child.id)
            }
        }
        var chain = self
        chain.nodes.removeAll { doomed.contains($0.id) }
        chain.revision += 1
        return (chain, doomed.count)
    }

    /// Renames the chain. A rename doesn't change what the chain computes, so the revision stays.
    func renamed(_ name: String) -> Chain {
        var chain = self
        chain.name = name
        return chain
    }

    // MARK: - Queries

    /// The nodes directly under `nodeID` (`nil` = the input), in insertion order.
    func children(of nodeID: ChainNode.ID?) -> [ChainNode] {
        nodes.filter { $0.parentID == nodeID }
    }

    /// The blocks from the root down to `nodeID`, inclusive.
    func path(to nodeID: ChainNode.ID) -> [Block] {
        var blocks: [Block] = []
        var current = nodes[id: nodeID]
        while let node = current {
            blocks.append(node.block)
            current = node.parentID.flatMap { nodes[id: $0] }
        }
        return blocks.reversed()
    }

    /// The nodes without children — one result per leaf.
    var leaves: [ChainNode] {
        let parents = Set(nodes.compactMap(\.parentID))
        return nodes.filter { !parents.contains($0.id) }
    }

    /// Every node reachable from the input, each after its parent (breadth first, siblings in insertion
    /// order). Doesn't rely on the stored order, which a decoded chain need not keep parents-first.
    var evaluationOrder: [ChainNode] {
        var order: [ChainNode] = []
        var level = children(of: nil)
        while !level.isEmpty {
            order.append(contentsOf: level)
            level = level.flatMap { children(of: $0.id) }
        }
        return order
    }
}

nonisolated extension Block {
    /// The parameter bounds that don't depend on a source. z < x waits for a run, because a chain isn't tied
    /// to a source (FR-011, research R5).
    func validateParameters() throws(ChainError) {
        if case let .countUniqueSubCombinations(z) = self, z < 2 { throw .invalidParameter("z") }
    }
}
