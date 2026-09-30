//
//  Draws.swift
//  lottoApp2
//
//  The draw entities every block works on (LTA-6, spec 003 FR-001/FR-002, research R1).
//

import Foundation

/// A single drawable value, `1…pool` of its `CombinationType`.
typealias Element = UInt

/// A broken entity invariant, named so the caller can say which rule a value broke.
nonisolated enum DomainError: Error, Hashable, Sendable {
    case invalidType
    case wrongCount(expected: Int, got: Int)
    case duplicate(Element)
    case outOfPool(Element)
    case mixedShapes
    case invalidCount(Int)
    /// A sub-combination needs 2 ≤ z < x (LTA-7).
    case invalidSubCombinationSize(Int)
}

/// An "x of y" rule: `pick` non-repeating elements drawn from a pool of `pool`. Invariant: 1 ≤ x ≤ y.
nonisolated struct CombinationType: Hashable, Sendable {
    let pick: Int
    let pool: Int

    init(pick: Int, pool: Int) throws(DomainError) {
        guard pick >= 1, pick <= pool else { throw .invalidType }
        self.pick = pick
        self.pool = pool
    }
}

/// A concrete draw: exactly `type.pick` distinct elements, each in `1…type.pool`.
///
/// Elements are stored strictly ascending, which gives set semantics for equality and hashing — order never
/// matters (FR-001) — and a total order for free: comparing element by element is the FR-008 tie-break.
nonisolated struct Combination: Hashable, Sendable, Comparable {
    let type: CombinationType
    let elements: [Element]

    init(type: CombinationType, elements: [Element]) throws(DomainError) {
        guard elements.count == type.pick else {
            throw .wrongCount(expected: type.pick, got: elements.count)
        }
        let sorted = elements.sorted()
        for (offset, element) in sorted.enumerated() {
            guard element >= 1, element <= Element(type.pool) else { throw .outOfPool(element) }
            if offset > 0, sorted[offset - 1] == element { throw .duplicate(element) }
        }
        self.type = type
        self.elements = sorted
    }

    static func < (lhs: Combination, rhs: Combination) -> Bool {
        lhs.elements.lexicographicallyPrecedes(rhs.elements)
    }

    /// All C(x, z) sub-combinations of size `z` (2 ≤ z < x), in lexicographic order of their elements.
    func subCombinations(size z: Int) throws(DomainError) -> [SubCombination] {
        guard z >= 2, z < type.pick else { throw .invalidSubCombinationSize(z) }
        var result: [SubCombination] = []
        var indices = Array(0..<z)
        let n = elements.count
        while true {
            result.append(SubCombination(parentType: type, checkedElements: indices.map { elements[$0] }))
            // Advance to the next index combination: bump the rightmost index that can still move.
            var position = z - 1
            while position >= 0, indices[position] == n - z + position { position -= 1 }
            guard position >= 0 else { return result }
            indices[position] += 1
            for next in (position + 1)..<z { indices[next] = indices[next - 1] + 1 }
        }
    }
}

/// z elements taken from a combination, 2 ≤ z < x, with the combination's rules (LTA-7). It keeps only its
/// parent's shape, not the draw it came from, so equal sub-combinations from different draws are equal and
/// can be counted.
nonisolated struct SubCombination: Hashable, Sendable, Comparable {
    let parentType: CombinationType
    let elements: [Element]

    init(parentType: CombinationType, elements: [Element]) throws(DomainError) {
        guard elements.count >= 2, elements.count < parentType.pick else {
            throw .invalidSubCombinationSize(elements.count)
        }
        let sorted = elements.sorted()
        for (offset, element) in sorted.enumerated() {
            guard element >= 1, element <= Element(parentType.pool) else { throw .outOfPool(element) }
            if offset > 0, sorted[offset - 1] == element { throw .duplicate(element) }
        }
        self.parentType = parentType
        self.elements = sorted
    }

    /// For elements taken, in order, from a valid combination — the invariants already hold.
    fileprivate init(parentType: CombinationType, checkedElements: [Element]) {
        self.parentType = parentType
        self.elements = checkedElements
    }

    static func < (lhs: SubCombination, rhs: SubCombination) -> Bool {
        lhs.elements.lexicographicallyPrecedes(rhs.elements)
    }
}

/// One row of a game's history.
nonisolated struct GameEntry: Hashable, Codable, Sendable {
    let index: Int
    let date: Date
    let combination: Combination
}

/// Describes a Game — mainly its combination shape. Declared by the source that produces the game.
nonisolated struct GameType: Hashable, Codable, Sendable {
    let id: String
    let name: String
    let combinationType: CombinationType
}

/// What a source produces: its history as entries of one shape (FR-002).
nonisolated struct Game: Hashable, Sendable {
    let type: GameType
    let entries: [GameEntry]

    init(type: GameType, entries: [GameEntry]) throws(DomainError) {
        guard entries.allSatisfy({ $0.combination.type == type.combinationType }) else { throw .mixedShapes }
        self.type = type
        self.entries = entries
    }

    private init(type: GameType, checkedEntries: [GameEntry]) {
        self.type = type
        self.entries = checkedEntries
    }

    /// This game with its entries replaced by a subset or reordering of its **own** entries — what filters
    /// and sorts produce. The shape invariant holds by construction, so it isn't re-checked.
    func replacingEntries(_ entries: [GameEntry]) -> Game {
        Game(type: type, checkedEntries: entries)
    }
}

// MARK: - Codable
// Decoding goes through the throwing initialisers, so a stored value that breaks an invariant fails to decode
// instead of producing an invalid entity.

nonisolated extension CombinationType: Codable {
    private enum CodingKeys: String, CodingKey { case pick, pool }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(pick: container.decode(Int.self, forKey: .pick), pool: container.decode(Int.self, forKey: .pool))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pick, forKey: .pick)
        try container.encode(pool, forKey: .pool)
    }
}

nonisolated extension Combination: Codable {
    private enum CodingKeys: String, CodingKey { case type, elements }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            type: container.decode(CombinationType.self, forKey: .type),
            elements: container.decode([Element].self, forKey: .elements)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(elements, forKey: .elements)
    }
}

nonisolated extension SubCombination: Codable {
    private enum CodingKeys: String, CodingKey { case parentType, elements }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            parentType: container.decode(CombinationType.self, forKey: .parentType),
            elements: container.decode([Element].self, forKey: .elements)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(parentType, forKey: .parentType)
        try container.encode(elements, forKey: .elements)
    }
}

nonisolated extension Game: Codable {
    private enum CodingKeys: String, CodingKey { case type, entries }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            type: container.decode(GameType.self, forKey: .type),
            entries: container.decode([GameEntry].self, forKey: .entries)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(entries, forKey: .entries)
    }
}
