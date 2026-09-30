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
            // The unit tests are hosted in this app. Building the real store there runs its `.task` effect
            // against unimplemented test dependencies while swift-testing is still bootstrapping, which
            // crashes the test process — so the host shows nothing under test.
            if !isTesting {
                StartPageView(store: Store(initialState: StartPage.State()) {
                    StartPage()
                })
            }
        }
    }
}
