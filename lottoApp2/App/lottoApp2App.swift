//
//  lottoApp2App.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 03/07/2025.
//

import SwiftUI
import ComposableArchitecture

@main
struct lottoApp2App: App {
    var body: some Scene {
        WindowGroup {
            StartPageView(store: Store(initialState: StartPage.State()) {
                StartPage()
            })
        }
    }
}
