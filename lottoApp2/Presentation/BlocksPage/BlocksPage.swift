//
//  BlocksPage.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//

import ComposableArchitecture
import Foundation

/// The processing-blocks step: it presents the catalogue of blocks the app offers for the source the
/// person chose on the start page. It holds no behaviour yet — nothing on the page is selectable,
/// configurable, or runnable — so it runs no effects and renders fixed content.
@Reducer
struct BlocksPage {
    @ObservableState
    struct State: Equatable {
        /// Carried for the steps that follow this one; not displayed.
        let sourceID: String
        /// The chosen source's display name, which the page header shows.
        let sourceName: String
        /// The catalogue as presented. Defaulting to `allCases` means a new block appears here by adding
        /// its case, with no second list to keep in step.
        var blocks: [ProcessingBlockKind] = ProcessingBlockKind.allCases
    }

    /// Uninhabited on purpose: the page has no user-driven behaviour at this stage. A case added here
    /// would be a place to hang work the spec puts out of scope, so add one only with a requirement.
    enum Action: Equatable {}

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {}
        }
    }
}
