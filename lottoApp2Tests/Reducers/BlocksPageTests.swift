//
//  BlocksPageTests.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import lottoApp2

struct BlocksPage_Tests {

    @MainActor
    @Test
    func initialState_listsTheWholeCatalogue() async throws {
        // FR-025 / FR-026: the page presents the blocks the app offers, which today is exactly one.
        // `allCases` is the catalogue, so adding a block is a one-line change here rather than a search.
        let state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")

        #expect(state.blocks == [.countUniqueElements])
    }

    @MainActor
    @Test
    func initialState_carriesTheChosenSource() async throws {
        // FR-024: the header names this source, and later steps will need its id.
        let state = BlocksPage.State(sourceID: "lotto", sourceName: "Lotto Server")

        #expect(state.sourceID == "lotto")
        #expect(state.sourceName == "Lotto Server")
    }
}
