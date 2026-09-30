//
//  BlockEvaluatorTests.swift
//  lottoApp2Tests
//
//  Every block against the hand-computed reference set (SC-001).
//

import Foundation
import Testing

@testable import lottoApp2

struct BlockEvaluatorTests {

    private func counts(_ value: BlockValue) throws -> CountResult {
        guard case let .counts(result) = value else {
            Issue.record("expected counts, got \(value)")
            throw Unexpected()
        }
        return result
    }

    private func elementTable(_ result: CountResult) -> [Element: Int] {
        Dictionary(uniqueKeysWithValues: result.counts.compactMap { unique in
            guard case let .element(element) = unique.item else { return nil }
            return (element, unique.count)
        })
    }

    private struct Unexpected: Error {}

    // MARK: - Count Unique Elements (FR-010 row 1)

    @Test
    func countUniqueElements_matchesTheHandCountOfThreeDraws() throws {
        // US1 AS1: {1,2,3}, {2,3,4}, {3,4,5} → 1→1, 2→2, 3→3, 4→2, 5→1 and nothing else.
        let result = try counts(BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.threeOfFive)))
        #expect(elementTable(result) == ReferenceDraws.threeOfFiveElementCounts)
        #expect(result.counts.count == 5)
    }

    @Test
    func countUniqueElements_leavesOutElementsThatWereNeverDrawn() throws {
        // US1 AS2: 17 is never drawn in the reference set.
        let result = try counts(BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.lotto)))
        #expect(elementTable(result) == ReferenceDraws.lottoElementCounts)
        #expect(elementTable(result)[17] == nil)
    }

    @Test
    func countUniqueElements_ofNoDraws_isEmpty() throws {
        // US1 AS3: an empty source counts nothing — an empty result, not an error.
        let result = try counts(BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.empty)))
        #expect(result.counts.isEmpty)
    }

    @Test
    func countUniqueElements_isUnorderedAndStoredItemAscending() throws {
        let result = try counts(BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.lotto)))
        #expect(result.ordering == .unordered)
        #expect(result.counts.map(\.item) == result.counts.map(\.item).sorted())
    }

    // MARK: - Filters (FR-005, FR-006)

    private func draws(_ value: BlockValue) throws -> Game {
        guard case let .draws(game) = value else {
            Issue.record("expected draws, got \(value)")
            throw Unexpected()
        }
        return game
    }

    private func indices(_ block: Block, on game: Game) throws -> [Int] {
        try draws(BlockEvaluator.evaluate(block, on: .draws(game))).entries.map(\.index)
    }

    @Test
    func suffix_keepsTheLastXDraws() throws {
        // US2 AS1: of 500 draws, keep the last 100.
        #expect(try indices(.suffix(100), on: ReferenceDraws.sequential(count: 500)) == Array(401...500))
    }

    @Test
    func filtersAskingForMoreThanTheInput_clamp() throws {
        // US2 AS2/AS3, FR-006: keep returns everything, skip returns nothing.
        let fifty = ReferenceDraws.sequential(count: 50)
        #expect(try indices(.suffix(100), on: fifty) == Array(1...50))
        #expect(try indices(.prefix(100), on: fifty) == Array(1...50))
        #expect(try indices(.dropFirst(100), on: fifty).isEmpty)
        #expect(try indices(.dropLast(100), on: fifty).isEmpty)
    }

    @Test
    func aParameterOfZero_keepsNothing_orSkipsNothing() throws {
        // US2 AS4, Edge Cases.
        let fifty = ReferenceDraws.sequential(count: 50)
        #expect(try indices(.prefix(0), on: fifty).isEmpty)
        #expect(try indices(.suffix(0), on: fifty).isEmpty)
        #expect(try indices(.dropFirst(0), on: fifty) == Array(1...50))
        #expect(try indices(.dropLast(0), on: fifty) == Array(1...50))
    }

    @Test
    func dropAndPrefix_workOnTheCurrentOrder() throws {
        let ten = ReferenceDraws.sequential(count: 10)
        #expect(try indices(.dropFirst(3), on: ten) == Array(4...10))
        #expect(try indices(.dropLast(3), on: ten) == Array(1...7))
        #expect(try indices(.prefix(3), on: ten) == [1, 2, 3])
    }

    @Test
    func filtersOnACountResult_keepItsKindAndOrdering() throws {
        // FR-005: filters take counts too and return counts, in the input's current order.
        let counts = try counts(BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.threeOfFive)))
        let kept = try self.counts(BlockEvaluator.evaluate(.prefix(2), on: .counts(counts)))
        #expect(kept.counts.map(\.item) == [.element(1), .element(2)])
        #expect(kept.ordering == .unordered)

        let skipped = try self.counts(BlockEvaluator.evaluate(.dropFirst(10), on: .counts(counts)))
        #expect(skipped.counts.isEmpty)
    }

    // MARK: - Sorts (FR-007, FR-009)

    @Test
    func sortByDateDescending_thenPrefix_keepsTheNewest() throws {
        // US2 AS5: the ten newest draws.
        let sorted = try BlockEvaluator.evaluate(.sortByDate(.descending), on: .draws(ReferenceDraws.sequential(count: 30)))
        let newest = try draws(BlockEvaluator.evaluate(.prefix(10), on: sorted))
        #expect(newest.entries.map(\.index) == Array((21...30).reversed()))
    }

    @Test
    func equalDates_fallBackToIndexAscending_inBothDirections() throws {
        // Draws 5 and 6 of the reference set share a date.
        let ascending = try indices(.sortByDate(.ascending), on: ReferenceDraws.lotto)
        let descending = try indices(.sortByDate(.descending), on: ReferenceDraws.lotto)
        #expect(ascending == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        #expect(descending == [12, 11, 10, 9, 8, 7, 5, 6, 4, 3, 2, 1])
    }

    @Test
    func sortByIndex_ordersByIndexInEitherDirection() throws {
        let shuffled = ReferenceDraws.lotto.replacingEntries(ReferenceDraws.lotto.entries.reversed())
        #expect(try indices(.sortByIndex(.ascending), on: shuffled) == Array(1...12))
        #expect(try indices(.sortByIndex(.descending), on: shuffled) == Array((1...12).reversed()))
    }

    @Test
    func sortingNoDraws_isEmpty() throws {
        #expect(try indices(.sortByDate(.ascending), on: ReferenceDraws.empty).isEmpty)
        #expect(try indices(.sortByIndex(.descending), on: ReferenceDraws.empty).isEmpty)
    }

    // MARK: - Sort by count (FR-008, FR-009)

    private func counts(_ pairs: [(Element, Int)]) throws -> CountResult {
        CountResult(unordered: try pairs.map { try UniqueCount(item: .element($0.0), count: $0.1) })
    }

    @Test
    func sortByCountDescending_breaksTiesByItemAscending() throws {
        // US3 AS1: 3→5, 7→5, 12→4 → 3, 7, 12.
        let input = try counts([(12, 4), (7, 5), (3, 5)])
        let sorted = try counts(BlockEvaluator.evaluate(.sortByCount(.descending), on: .counts(input)))
        #expect(sorted.counts.map(\.item) == [.element(3), .element(7), .element(12)])
        #expect(sorted.ordering == .byCount(.descending))
    }

    @Test
    func sortByCountAscending_stillBreaksTiesByItemAscending() throws {
        // US3 AS2: → 12, 3, 7.
        let input = try counts([(12, 4), (7, 5), (3, 5)])
        let sorted = try counts(BlockEvaluator.evaluate(.sortByCount(.ascending), on: .counts(input)))
        #expect(sorted.counts.map(\.item) == [.element(12), .element(3), .element(7)])
        #expect(sorted.ordering == .byCount(.ascending))
    }

    @Test
    func sortByCount_ofNothing_isEmpty() throws {
        let sorted = try counts(BlockEvaluator.evaluate(.sortByCount(.descending), on: .counts(CountResult(unordered: []))))
        #expect(sorted.counts.isEmpty)
    }

    // MARK: - Count All Elements (FR-010 row 4)

    @Test
    func countAllElements_countsEveryDrawnElement() throws {
        // entries × x, but computed rather than assumed.
        #expect(try BlockEvaluator.evaluate(.countAllElements, on: .draws(ReferenceDraws.lotto)) == .number(72))
        #expect(try BlockEvaluator.evaluate(.countAllElements, on: .draws(ReferenceDraws.threeOfFive)) == .number(9))
    }

    @Test
    func countAllElements_ofNoDraws_isZero() throws {
        #expect(try BlockEvaluator.evaluate(.countAllElements, on: .draws(ReferenceDraws.empty)) == .number(0))
    }

    // MARK: - Combinations and sub-combinations (FR-010 rows 2–3, FR-011, FR-022)

    /// `entries` draws of 20 elements from a pool of 80 — large enough to exceed the sub-combination budget.
    static func twentyOfEighty(entries: Int) -> Game {
        let type = GameType(id: "t-20-80", name: "20/80", combinationType: try! CombinationType(pick: 20, pool: 80))
        return ReferenceDraws.game(type, (1...entries).map { index in
            (index, ReferenceDraws.day(index), (1...20).map { Element(($0 + index) % 80 + 1) })
        })
    }

    @Test
    func countUniqueCombinations_findsTheRepeatedDraw_whateverItsOrder() throws {
        // US7 AS1/AS2
        let result = try counts(BlockEvaluator.evaluate(.countUniqueCombinations, on: .draws(ReferenceDraws.lotto)))
        let repeated = try Combination(type: ReferenceDraws.sixOfFortyNineType, elements: ReferenceDraws.lottoRepeatedCombination)
        let once = ReferenceDraws.lotto.entries[1].combination
        #expect(result.counts.first { $0.item == .combination(repeated) }?.count == 2)
        #expect(result.counts.first { $0.item == .combination(once) }?.count == 1)
        #expect(result.counts.count == ReferenceDraws.lottoUniqueCombinations)
    }

    @Test
    func countUniqueSubCombinations_ofPairs_countsEveryPairOfEveryDraw() throws {
        // US7 AS3: each 6-of-49 draw contributes its 15 pairs; {10, 11} is in 3 draws.
        let result = try counts(BlockEvaluator.evaluate(.countUniqueSubCombinations(z: 2), on: .draws(ReferenceDraws.lotto)))
        let shared = try SubCombination(parentType: ReferenceDraws.sixOfFortyNineType, elements: ReferenceDraws.lottoSharedPair)
        #expect(result.counts.reduce(0) { $0 + $1.count } == 12 * 15)
        #expect(result.counts.count == ReferenceDraws.lottoUniquePairs)
        #expect(result.counts.first { $0.item == .subCombination(shared) }?.count == 3)
    }

    @Test
    func aSubCombinationSizeNotBelowX_failsNamingTheParameter() {
        // FR-011: z < x is checked against the source the run uses.
        #expect(throws: BlockFailure.invalidParameter(name: "z")) {
            try BlockEvaluator.evaluate(.countUniqueSubCombinations(z: 6), on: .draws(ReferenceDraws.lotto))
        }
        #expect(throws: BlockFailure.invalidParameter(name: "z")) {
            try BlockEvaluator.evaluate(.countUniqueSubCombinations(z: 3), on: .draws(ReferenceDraws.threeOfFive))
        }
    }

    @Test
    func tooManySubCombinations_failsNamingTheLimit_beforeGeneratingAny() {
        // FR-022: 28 × C(20, 10) = 5,173,168 > 5,000,000.
        #expect(throws: BlockFailure.overBudget(limit: 5_000_000)) {
            try BlockEvaluator.evaluate(.countUniqueSubCombinations(z: 10), on: .draws(Self.twentyOfEighty(entries: 28)))
        }
    }
}
