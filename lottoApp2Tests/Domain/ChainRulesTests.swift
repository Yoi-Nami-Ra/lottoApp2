//
//  ChainRulesTests.swift
//  lottoApp2Tests
//

import Dependencies
import Foundation
import IdentifiedCollections
import Testing

@testable import lottoApp2

struct ChainRulesTests {

    private let chainID = UUID(0)
    private let a = UUID(1)
    private let b = UUID(2)
    private let c = UUID(3)
    private let d = UUID(4)

    /// A chain built node by node, bypassing the attach rule. The tree operations (children, path, leaves,
    /// subtree removal) don't depend on block kinds, so these fixtures only need the shape.
    private func tree(_ nodes: [(UUID, UUID?)]) -> Chain {
        Chain(
            id: chainID, name: "Tree", revision: 0,
            nodes: IdentifiedArray(uniqueElements: nodes.map { ChainNode(id: $0.0, parentID: $0.1, block: .countUniqueElements) })
        )
    }

    // MARK: - Catalogue

    @Test
    func everyKindsDefaultBlock_isOfThatKind() {
        for kind in ProcessingBlockKind.allCases {
            #expect(kind.defaultBlock.kind == kind)
        }
    }

    // MARK: - outputKind

    @Test
    func outputKind_ofTheInputIsDraws() throws {
        #expect(try Chain.empty(id: chainID, name: "C").outputKind(of: nil) == .draws)
    }

    @Test
    func outputKind_ofAnUnknownNode_throws() {
        #expect(throws: ChainError.unknownNode) { try Chain.empty(id: chainID, name: "C").outputKind(of: a) }
    }

    // MARK: - attaching (FR-015)

    @Test
    func attaching_underTheInput_addsTheNodeAndBumpsTheRevision() throws {
        let chain = Chain.empty(id: chainID, name: "C")
        let (attached, id) = try chain.attaching(.countUniqueElements, under: nil, id: a)

        #expect(id == a)
        #expect(attached.nodes[id: a] == ChainNode(id: a, parentID: nil, block: .countUniqueElements))
        #expect(attached.revision == chain.revision + 1)
    }

    @Test
    func attaching_aBlockThatCannotTakeTheParentsOutput_isRefusedAndLeavesTheChainUnchanged() throws {
        let (chain, count) = try Chain.empty(id: chainID, name: "C").attaching(.countUniqueElements, under: nil, id: a)
        let before = chain

        #expect(throws: ChainError.inputMismatch(needs: [.draws], got: .counts)) {
            try chain.attaching(.countUniqueElements, under: count, id: b)
        }
        #expect(chain == before)
    }

    @Test
    func attaching_underAnUnknownParent_throws() {
        #expect(throws: ChainError.unknownNode) {
            try Chain.empty(id: chainID, name: "C").attaching(.countUniqueElements, under: a, id: b)
        }
    }

    // MARK: - updating (FR-016)

    @Test
    func updating_bumpsTheRevision() throws {
        let chain = tree([(a, nil)])
        let updated = try chain.updating(a, to: .countUniqueElements)
        #expect(updated.revision == chain.revision + 1)
        #expect(updated.nodes[id: a]?.block == .countUniqueElements)
    }

    @Test
    func updating_toABlockThatCannotTakeTheParentsOutput_throws() {
        // b sits under a count node, so a block needing draws doesn't fit there.
        let chain = tree([(a, nil), (b, a)])
        #expect(throws: ChainError.inputMismatch(needs: [.draws], got: .counts)) {
            try chain.updating(b, to: .countUniqueElements)
        }
    }

    @Test
    func updating_toABlockWhoseOutputAChildCannotTake_throws() {
        // After the update a outputs counts, and its child b needs draws.
        let chain = tree([(a, nil), (b, a)])
        #expect(throws: ChainError.inputMismatch(needs: [.draws], got: .counts)) {
            try chain.updating(a, to: .countUniqueElements)
        }
    }

    @Test
    func updating_anUnknownNode_throws() {
        #expect(throws: ChainError.unknownNode) { try tree([(a, nil)]).updating(b, to: .countUniqueElements) }
    }

    @Test
    func updating_aFilterWhoseNewKindStillFits_keepsItsChildren() throws {
        // A real edit (US6): "last 100" becomes "last 50" under the input, with a count below it.
        var (chain, filter) = try Chain.empty(id: chainID, name: "C").attaching(.suffix(100), under: nil, id: a)
        (chain, _) = try chain.attaching(.countUniqueElements, under: filter, id: b)

        let updated = try chain.updating(filter, to: .suffix(50))
        #expect(updated.nodes[id: a]?.block == .suffix(50))
        #expect(updated.children(of: a).map(\.id) == [b])
    }

    // MARK: - removingSubtree (FR-016)

    @Test
    func removingSubtree_removesTheNodeAndEveryDescendant() throws {
        let chain = tree([(a, nil), (b, a), (c, b), (d, nil)])
        let (removed, count) = try chain.removingSubtree(a)

        #expect(count == 3)
        #expect(removed.nodes.map(\.id) == [d])
        #expect(removed.revision == chain.revision + 1)
    }

    @Test
    func removingSubtree_ofAnUnknownNode_throws() {
        #expect(throws: ChainError.unknownNode) { try tree([(a, nil)]).removingSubtree(b) }
    }

    // MARK: - renamed

    @Test
    func renamed_changesTheNameButNotTheRevision() {
        // R4: a rename is not an edit that makes results out of date.
        let chain = tree([(a, nil)])
        let renamed = chain.renamed("Top 10")
        #expect(renamed.name == "Top 10")
        #expect(renamed.revision == chain.revision)
    }

    // MARK: - Queries

    @Test
    func children_keepInsertionOrder() {
        let chain = tree([(a, nil), (c, a), (b, a), (d, nil)])
        #expect(chain.children(of: a).map(\.id) == [c, b])
        #expect(chain.children(of: nil).map(\.id) == [a, d])
    }

    @Test
    func path_runsFromTheRootToTheNode() throws {
        let chain = tree([(a, nil), (b, a), (c, b)])
        #expect(chain.path(to: c) == [.countUniqueElements, .countUniqueElements, .countUniqueElements])
        #expect(chain.path(to: a).count == 1)
    }

    @Test
    func leaves_areTheNodesWithoutChildren() {
        let chain = tree([(a, nil), (b, a), (c, a), (d, nil)])
        #expect(Set(chain.leaves.map(\.id)) == [b, c, d])
    }

    @Test
    func evaluationOrder_putsEveryParentBeforeItsChildren() {
        // A decoded chain need not list parents first; evaluation order must still be parents-first.
        let chain = tree([(c, b), (b, a), (a, nil), (d, nil)])
        let order = chain.evaluationOrder.map(\.id)
        #expect(order.count == 4)
        for node in chain.nodes {
            if let parent = node.parentID {
                #expect(order.firstIndex(of: parent)! < order.firstIndex(of: node.id)!)
            }
        }
    }

    // MARK: - The attach matrix (SC-002, FR-010, FR-012)

    /// FR-010 written out by hand — deliberately not derived from `Block.accepts`, so the test checks the
    /// code against the spec rather than against itself. Keep in step with every kind the catalogue gains.
    private static let takes: [ProcessingBlockKind: Set<ValueKind>] = [
        .dropFirst: [.draws, .counts], .dropLast: [.draws, .counts], .prefix: [.draws, .counts], .suffix: [.draws, .counts],
        .sortByDate: [.draws], .sortByIndex: [.draws], .sortByCount: [.counts],
        .countUniqueElements: [.draws], .countUniqueCombinations: [.draws], .countUniqueSubCombinations: [.draws],
        .countAllElements: [.draws],
    ]

    /// What each parent outputs, by hand.
    private static let gives: [ProcessingBlockKind: ValueKind] = [
        .dropFirst: .draws, .dropLast: .draws, .prefix: .draws, .suffix: .draws,
        .sortByDate: .draws, .sortByIndex: .draws, .sortByCount: .counts,
        .countUniqueElements: .counts, .countUniqueCombinations: .counts, .countUniqueSubCombinations: .counts,
        .countAllElements: .number,
    ]

    /// A parent of `kind` on the shortest valid chain that reaches it.
    private func parent(_ kind: ProcessingBlockKind) throws -> (Chain, ChainNode.ID) {
        let empty = Chain.empty(id: chainID, name: "Matrix")
        if kind == .sortByCount {
            let (withCount, count) = try empty.attaching(.countUniqueElements, under: nil, id: a)
            return try withCount.attaching(kind.defaultBlock, under: count, id: b)
        }
        return try empty.attaching(kind.defaultBlock, under: nil, id: a)
    }

    @Test
    func everyBlockUnderEveryParent_isAcceptedExactlyAsFR010Says() throws {
        #expect(Set(Self.takes.keys) == Set(ProcessingBlockKind.allCases), "the hand-written table is missing a kind")

        var parents: [(label: String, chain: Chain, id: ChainNode.ID?, gives: ValueKind)] = [
            ("input", .empty(id: chainID, name: "Matrix"), nil, .draws),
        ]
        for kind in ProcessingBlockKind.allCases {
            let (chain, id) = try parent(kind)
            parents.append(("\(kind)", chain, id, try #require(Self.gives[kind])))
        }
        // A filter over counts outputs counts (FR-005).
        let (counted, count) = try Chain.empty(id: chainID, name: "Matrix").attaching(.countUniqueElements, under: nil, id: a)
        let (filtered, filter) = try counted.attaching(.prefix(10), under: count, id: b)
        parents.append(("prefix over counts", filtered, filter, .counts))

        for parent in parents {
            for kind in ProcessingBlockKind.allCases {
                let block = kind.defaultBlock
                let needs = try #require(Self.takes[kind])
                if needs.contains(parent.gives) {
                    #expect(throws: Never.self, "\(kind) under \(parent.label)") {
                        try parent.chain.attaching(block, under: parent.id, id: d)
                    }
                } else {
                    #expect(throws: ChainError.inputMismatch(needs: needs, got: parent.gives), "\(kind) under \(parent.label)") {
                        try parent.chain.attaching(block, under: parent.id, id: d)
                    }
                }
            }
        }
    }

    @Test
    func nothingAttachesUnderCountAllElements() throws {
        // FR-012: a single number ends a branch.
        let (chain, total) = try Chain.empty(id: chainID, name: "C").attaching(.countAllElements, under: nil, id: a)
        for kind in ProcessingBlockKind.allCases {
            #expect(throws: ChainError.self) { try chain.attaching(kind.defaultBlock, under: total, id: b) }
        }
    }

    // MARK: - Sub-combination size (FR-011)

    @Test
    func aSubCombinationSizeBelowTwo_isRefused_whenAddedOrEdited() throws {
        // US7 AS4: z = 1 can't be set; z < x waits for a run, since a chain isn't tied to a source.
        let empty = Chain.empty(id: chainID, name: "C")
        #expect(throws: ChainError.invalidParameter("z")) {
            try empty.attaching(.countUniqueSubCombinations(z: 1), under: nil, id: a)
        }
        let (chain, pairs) = try empty.attaching(.countUniqueSubCombinations(z: 2), under: nil, id: a)
        #expect(throws: ChainError.invalidParameter("z")) { try chain.updating(pairs, to: .countUniqueSubCombinations(z: 1)) }
        #expect(throws: Never.self) { try chain.updating(pairs, to: .countUniqueSubCombinations(z: 40)) }
    }
}
