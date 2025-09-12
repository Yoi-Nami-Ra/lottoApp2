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
    StartPageView(
        store: Store(initialState: StartPage.State()) {
            StartPage()
        }
    )
    .preferredColorScheme(.dark)
}

#Preview("Start page - light") {
    StartPageView(
        store: Store(initialState: StartPage.State()) {
            StartPage()
        }
    )
    .preferredColorScheme(.light)
}
