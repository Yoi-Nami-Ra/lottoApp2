//
//  StartPageView.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 03/07/2025.
//

import ComposableArchitecture
import Dependencies
import SwiftUI

struct StartPageView: View {
    let store: StoreOf<StartPage>

    var body: some View {
        List {
            ForEach(store.scope(state: \.sources, action: \.sources)) { sourceStore in
                SourceEntryView(store: sourceStore)
                    // `SourceCardStyle` already draws the card; without these the row adds a second
                    // background, its own shadow, and a separator on top of it.
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.sourceRow)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.pageBackground)
        // `.finish()` ties the effect to the view's lifetime, so it is cancelled on disappear instead of
        // outliving the screen.
        .task { await store.send(.task).finish() }
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let pageBackground: Self = .backgroundSecondary
}

extension EdgeInsets {
    fileprivate static let sourceRow = EdgeInsets(
        top: .rowVInset, leading: .rowHInset, bottom: .rowVInset, trailing: .rowHInset
    )
}

extension CGFloat {
    fileprivate static let rowVInset: Self = 8
    fileprivate static let rowHInset: Self = 16
}

#Preview("Start page - dark") {
    StartPageView(store: .previewMocked)
        .preferredColorScheme(.dark)
}

#Preview("Start page - light") {
    StartPageView(store: .previewMocked)
        .preferredColorScheme(.light)
}

#Preview("Start page - no sources - light") {
    StartPageView(store: .previewEmpty)
        .preferredColorScheme(.light)
}

#Preview("Start page - no sources - dark") {
    StartPageView(store: .previewEmpty)
        .preferredColorScheme(.dark)
}

extension StoreOf<StartPage> {
    fileprivate static var previewMocked: StoreOf<StartPage> {
        preview(sources: Source.mocks)
    }

    fileprivate static var previewEmpty: StoreOf<StartPage> {
        preview(sources: [])
    }

    private static func preview(sources: [Source]) -> StoreOf<StartPage> {
        Store(initialState: StartPage.State()) {
            StartPage()
        } withDependencies: {
            $0.blSources = .previewMock
            $0.blSources.knownSources = { sources }
        }
    }
}
