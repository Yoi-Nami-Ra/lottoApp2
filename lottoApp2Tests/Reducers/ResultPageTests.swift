//
//  ResultPageTests.swift
//  lottoApp2Tests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import lottoApp2

struct ResultPage_Tests {

    private let stamp = RunStamp(
        sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 1
    )

    @Test
    func anUnorderedElementCount_isListedItemAscending() throws {
        // FR-025: an unsorted result is shown by item ascending, without implying a ranking.
        let value = try BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.threeOfFive))
        let state = ResultPage.State(value: value, stamp: stamp, freshness: .current)

        #expect(state.rows.map(\.item) == [.element(1), .element(2), .element(3), .element(4), .element(5)])
        #expect(state.rows.map(\.count) == [1, 2, 3, 2, 1])
        #expect(state.isEmpty == false)
    }

    @Test
    func anEmptyCountResult_isEmpty() {
        // FR-026
        let state = ResultPage.State(value: .counts(CountResult(unordered: [])), stamp: stamp, freshness: .current)
        #expect(state.isEmpty)
        #expect(state.rows.isEmpty)
    }

    @Test
    func freshnessAndChainChanged_passThroughUnchanged() {
        let state = ResultPage.State(value: .number(3), stamp: stamp, freshness: .outOfDate, chainChanged: true)
        #expect(state.freshness == .outOfDate)
        #expect(state.chainChanged)
    }

    @Test
    func aRankedResult_keepsItsOrder_andNumbersItsRows() throws {
        // FR-025: only a result sorted by count reads as a ranking.
        let ranked = try CountResult(
            counts: [UniqueCount(item: .element(7), count: 5), UniqueCount(item: .element(3), count: 4)],
            ordering: .byCount(.descending)
        )
        let state = ResultPage.State(value: .counts(ranked), stamp: stamp, freshness: .current)
        #expect(state.isRanked)
        #expect(state.rows.map(\.item) == [.element(7), .element(3)])
        #expect(state.rows.map(\.rank) == [1, 2])
    }

    @Test
    func anUnorderedResult_isNotRanked() throws {
        let value = try BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.threeOfFive))
        let state = ResultPage.State(value: value, stamp: stamp, freshness: .current)
        #expect(state.isRanked == false)
        #expect(state.rows.allSatisfy { $0.rank == nil })
    }

    // MARK: - Grouped combinations (LTA-18)

    @Test
    func combinationCounts_areGroupedByCount_repeatsFirst() throws {
        let value = try BlockEvaluator.evaluate(.countUniqueCombinations, on: .draws(ReferenceDraws.lotto))
        let state = ResultPage.State(value: value, stamp: stamp, freshness: .current)

        #expect(state.groups.map(\.count) == [2, 1])
        #expect(state.groups[0].total == 1)
        #expect(state.groups[1].total == 10)
        let shown = state.groups[1].shown.map(\.item)
        #expect(shown == shown.sorted())  // ascending by elements within a group
    }

    @MainActor
    @Test
    func aLargeGroup_showsTwenty_andHowManyMore_untilExpanded() async throws {
        // 60 distinct combinations drawn once each.
        let value = try BlockEvaluator.evaluate(.countUniqueCombinations, on: .draws(BlockEvaluatorTests.twentyOfEighty(entries: 60)))
        let store = TestStore(initialState: ResultPage.State(value: value, stamp: stamp, freshness: .current)) {
            ResultPage()
        }

        let group = try #require(store.state.groups.first)
        #expect(group.shown.count == 20)
        #expect(group.remaining == 40)

        await store.send(.showAllTapped(count: 1)) { $0.expandedGroups = [1] }
        #expect(store.state.groups.first?.shown.count == 60)
        #expect(store.state.groups.first?.remaining == 0)
    }
}
