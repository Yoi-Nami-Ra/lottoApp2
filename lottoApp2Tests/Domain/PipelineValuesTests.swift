//
//  PipelineValuesTests.swift
//  lottoApp2Tests
//

import Foundation
import Testing

@testable import lottoApp2

struct PipelineValuesTests {

    @Test
    func blockValue_kindNamesItsCase() {
        // FR-003: exactly three kinds of data flow between blocks.
        #expect(BlockValue.draws(ReferenceDraws.empty).kind == .draws)
        #expect(BlockValue.counts(CountResult(unordered: [])).kind == .counts)
        #expect(BlockValue.number(0).kind == .number)
    }

    @Test
    func unorderedCountResult_isStoredItemAscending() throws {
        // FR-025: an unsorted count result has one canonical form, so equal results compare equal.
        let a = try CountResult(unordered: [
            UniqueCount(item: .element(9), count: 1),
            UniqueCount(item: .element(2), count: 4),
            UniqueCount(item: .element(5), count: 2),
        ])
        let b = try CountResult(unordered: [
            UniqueCount(item: .element(5), count: 2),
            UniqueCount(item: .element(9), count: 1),
            UniqueCount(item: .element(2), count: 4),
        ])
        #expect(a.counts.map(\.item) == [.element(2), .element(5), .element(9)])
        #expect(a.ordering == .unordered)
        #expect(a == b)
    }

    @Test
    func countItem_elementsOrderAscending() {
        #expect(CountItem.element(3) < CountItem.element(12))
    }

    @Test
    func uniqueCount_rejectsACountBelowOne() {
        // FR-004: every count is at least 1.
        #expect(throws: DomainError.invalidCount(0)) { try UniqueCount(item: .element(1), count: 0) }
        #expect(throws: Never.self) { try UniqueCount(item: .element(1), count: 1) }
    }

    @Test
    func blockValue_survivesAJSONRoundTrip() throws {
        let values: [BlockValue] = [
            .draws(ReferenceDraws.threeOfFive),
            .counts(try CountResult(unordered: [UniqueCount(item: .element(3), count: 3)])),
            .number(42),
        ]
        for value in values {
            #expect(try JSONDecoder().decode(BlockValue.self, from: JSONEncoder().encode(value)) == value)
        }
    }

    @Test
    func combinationAndSubCombinationItems_orderElementByElement() throws {
        let sixOf49 = try CombinationType(pick: 6, pool: 49)
        let low = try Combination(type: sixOf49, elements: [1, 2, 3, 4, 5, 9])
        let high = try Combination(type: sixOf49, elements: [1, 2, 3, 4, 6, 7])
        #expect(CountItem.combination(low) < CountItem.combination(high))
        let pairLow = try SubCombination(parentType: sixOf49, elements: [2, 30])
        let pairHigh = try SubCombination(parentType: sixOf49, elements: [3, 4])
        #expect(CountItem.subCombination(pairLow) < CountItem.subCombination(pairHigh))
    }
}
