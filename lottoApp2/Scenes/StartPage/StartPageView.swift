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
            }
        }
        .padding()
        .background(.background)
        .task { store.send(.task) }
    }
}

#Preview("Start page - dark") {
    StartPageView(store: .previewMocked)
        .preferredColorScheme(.dark)
}

#Preview("Start page - light") {
    StartPageView(store: .previewMocked)
        .preferredColorScheme(.light)
}

#Preview("Start page - no sources") {
    StartPageView(store: .previewEmpty)
        .preferredColorScheme(.light)
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
