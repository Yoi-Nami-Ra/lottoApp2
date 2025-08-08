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
            StartPage(store: Store(initialState: StartPageFeature.State()) {
                StartPageFeature()
            })
        }
    }
}
