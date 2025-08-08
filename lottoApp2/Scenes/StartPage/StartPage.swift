//
//  StartPage.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 03/07/2025.
//

import ComposableArchitecture
import Dependencies
import SwiftUI

struct StartPage: View {
    let store: StoreOf<StartPageFeature>

    var body: some View {
        List {
            ForEach(store.sources, id: \.name) { source in
                SourceEntry(data: source)
            }
        }
        .border(.cyan)
        .padding()
        .task {
            store.send(.task)
        }
    }
}

#Preview {
    StartPage(
        store: Store(initialState: StartPageFeature.State()) {
            StartPageFeature()
        }
    )
}
