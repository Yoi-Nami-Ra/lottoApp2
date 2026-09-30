//
//  CombinationTests.swift
//  lottoApp2Tests
//

import Foundation
import Testing

@testable import lottoApp2

struct CombinationTests {

    // MARK: - CombinationType

    @Test
    func combinationType_rejectsAPickOutsideOneToPool() {
        // "1 ≤ x ≤ y"
        #expect(throws: DomainError.invalidType) { try CombinationType(pick: 0, pool: 5) }
        #expect(throws: DomainError.invalidType) { try CombinationType(pick: 6, pool: 5) }
        #expect(throws: Never.self) { try CombinationType(pick: 5, pool: 5) }
    }

    // MARK: - Combination invariants (FR-001)

    @Test
    func combination_rejectsTheWrongNumberOfElements() throws {
        let type = try CombinationType(pick: 3, pool: 49)
        #expect(throws: DomainError.wrongCount(expected: 3, got: 2)) {
            try Combination(type: type, elements: [1, 2])
        }
    }

    @Test
    func combination_rejectsARepeatedElement() throws {
        let type = try CombinationType(pick: 3, pool: 49)
        #expect(throws: DomainError.duplicate(7)) {
            try Combination(type: type, elements: [7, 3, 7])
        }
    }

    @Test
    func combination_rejectsElementsOutsideThePool() throws {
        let type = try CombinationType(pick: 3, pool: 49)
        #expect(throws: DomainError.outOfPool(0)) { try Combination(type: type, elements: [0, 1, 2]) }
        #expect(throws: DomainError.outOfPool(50)) { try Combination(type: type, elements: [1, 2, 50]) }
    }

    @Test
    func combination_storesItsElementsAscending() throws {
        let type = try CombinationType(pick: 3, pool: 49)
        let combination = try Combination(type: type, elements: [9, 1, 5])
        #expect(combination.elements == [1, 5, 9])
    }

    @Test
    func combination_equalityIgnoresTheOrderElementsWereGivenIn() throws {
        // FR-001: {1, 5, 9} and {9, 1, 5} are the same combination.
        let type = try CombinationType(pick: 3, pool: 49)
        let a = try Combination(type: type, elements: [1, 5, 9])
        let b = try Combination(type: type, elements: [9, 1, 5])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func combination_comparesElementByElement() throws {
        // FR-008 tie-break: combinations order by their sorted elements.
        let type = try CombinationType(pick: 3, pool: 49)
        let lower = try Combination(type: type, elements: [1, 2, 9])
        let higher = try Combination(type: type, elements: [1, 3, 4])
        #expect(lower < higher)
        #expect(!(higher < lower))
    }

    // MARK: - Game (FR-002)

    @Test
    func game_rejectsEntriesOfAnotherShape() throws {
        let sixOf49 = try CombinationType(pick: 6, pool: 49)
        let threeOf49 = try CombinationType(pick: 3, pool: 49)
        let type = GameType(id: "t", name: "T", combinationType: sixOf49)
        let odd = GameEntry(
            index: 1, date: .init(timeIntervalSince1970: 0),
            combination: try Combination(type: threeOf49, elements: [1, 2, 3])
        )
        #expect(throws: DomainError.mixedShapes) { try Game(type: type, entries: [odd]) }
    }

    // MARK: - Codable

    @Test
    func combinationAndGame_surviveAJSONRoundTrip() throws {
        let game = ReferenceDraws.lotto
        let decoded = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
        #expect(decoded == game)

        let combination = game.entries[0].combination
        let decodedCombination = try JSONDecoder().decode(Combination.self, from: JSONEncoder().encode(combination))
        #expect(decodedCombination == combination)
    }

    @Test
    func decodingAnInvalidCombination_fails() {
        // A stored row that breaks an invariant must not decode into an invalid value.
        let json = Data(#"{"type":{"pick":3,"pool":49},"elements":[1,1,2]}"#.utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Combination.self, from: json) }
    }

    // MARK: - SubCombination (LTA-7)

    @Test
    func subCombination_sizeMustBeAtLeastTwoAndBelowX() throws {
        let sixOf49 = try CombinationType(pick: 6, pool: 49)
        #expect(throws: DomainError.invalidSubCombinationSize(1)) { try SubCombination(parentType: sixOf49, elements: [3]) }
        #expect(throws: DomainError.invalidSubCombinationSize(6)) {
            try SubCombination(parentType: sixOf49, elements: [1, 2, 3, 4, 5, 6])
        }
        #expect(throws: Never.self) { try SubCombination(parentType: sixOf49, elements: [9, 4]) }
    }

    @Test
    func subCombination_followsTheCombinationRules() throws {
        let sixOf49 = try CombinationType(pick: 6, pool: 49)
        #expect(throws: DomainError.duplicate(4)) { try SubCombination(parentType: sixOf49, elements: [4, 4]) }
        #expect(throws: DomainError.outOfPool(50)) { try SubCombination(parentType: sixOf49, elements: [1, 50]) }
        let pair = try SubCombination(parentType: sixOf49, elements: [5, 1])
        #expect(pair.elements == [1, 5])
        #expect(pair == (try SubCombination(parentType: sixOf49, elements: [1, 5])))
    }

    @Test
    func aCombination_listsAllItsSubCombinationsOfSizeZ() throws {
        let draw = ReferenceDraws.lotto.entries[0].combination
        let pairs = try draw.subCombinations(size: 2)
        let triples = try draw.subCombinations(size: 3)
        #expect(pairs.count == 15)  // C(6, 2)
        #expect(Set(pairs).count == 15)
        #expect(triples.count == 20)  // C(6, 3)
        #expect(pairs.allSatisfy { $0.elements.count == 2 && $0.parentType == draw.type })
        #expect(throws: DomainError.invalidSubCombinationSize(6)) { try draw.subCombinations(size: 6) }
    }
}
