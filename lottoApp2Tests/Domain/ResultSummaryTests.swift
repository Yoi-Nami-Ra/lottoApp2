//
//  ResultSummaryTests.swift
//  lottoApp2Tests
//
//  The short summary every node that ran shows (FR-024, research R14).
//

import Foundation
import Testing

@testable import lottoApp2

struct ResultSummaryTests {

    @Test
    func elementCounts_summariseAsTheNumberOfElements() throws {
        let counts = try BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.threeOfFive))
        #expect(ResultSummary.summary(of: counts) == .elements(count: 5))
    }

    @Test
    func anEmptyCountResult_summarisesAsEmptyCounts() {
        // FR-026: an empty result says there is nothing to show rather than looking like an error.
        #expect(ResultSummary.summary(of: .counts(CountResult(unordered: []))) == .empty(.counts))
    }

    @Test
    func draws_summariseAsTheNumberOfDraws() {
        #expect(ResultSummary.summary(of: .draws(ReferenceDraws.lotto)) == .draws(count: 12))
        #expect(ResultSummary.summary(of: .draws(ReferenceDraws.empty)) == .empty(.draws))
    }

    @Test
    func aNumber_summarisesAsItself_evenZero() {
        // A total of 0 is a result, not an empty one.
        #expect(ResultSummary.summary(of: .number(42_072)) == .number(42_072))
        #expect(ResultSummary.summary(of: .number(0)) == .number(0))
    }

    @Test
    func combinationCounts_summariseAsUniqueAndRepeating() throws {
        let combinations = try BlockEvaluator.evaluate(.countUniqueCombinations, on: .draws(ReferenceDraws.lotto))
        #expect(ResultSummary.summary(of: combinations) == .combinations(unique: 11, repeating: 1))
    }

    @Test
    func subCombinationCounts_summariseAsUniqueOfTheirSize() throws {
        let pairs = try BlockEvaluator.evaluate(.countUniqueSubCombinations(z: 2), on: .draws(ReferenceDraws.lotto))
        #expect(ResultSummary.summary(of: pairs) == .subCombinations(unique: 159, size: 2))
    }
}
