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
    @Bindable var store: StoreOf<StartPage>

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.pageBackground)
                // An inset rather than an overlay: the list's scrollable area shrinks to fit, so the last
                // card can be scrolled clear of the bar instead of sitting under it.
                .safeAreaInset(edge: .bottom) {
                    BottomActionBar(isNextEnabled: store.isNextEnabled) {
                        store.send(.nextButtonTapped)
                    }
                }
                // `.finish()` ties the effect to the view's lifetime, so it is cancelled on disappear instead of
                // outliving the screen.
                //
                // This also covers the reload after returning from the blocks page: pushing a destination
                // makes this view disappear and popping makes it reappear, so `.task` runs again. Verified
                // on the simulator rather than assumed — the load was observed firing twice across one
                // push/pop — so no extra `onAppear` trigger is needed. `hasLoaded` is what keeps the
                // populated list on screen while that second load runs.
                .task { await store.send(.task).finish() }
                .navigationDestination(
                    item: $store.scope(state: \.blocks, action: \.blocks)
                ) { blocksStore in
                    BlocksPageView(store: blocksStore)
                }
        }
    }

    /// The three states the screen can be in. `hasLoaded` is what separates "still finding out" from
    /// "there are none", so the empty message can never appear before a result has arrived.
    @ViewBuilder
    private var content: some View {
        if store.hasLoaded == false {
            loadingState
        } else if store.sources.isEmpty {
            noSourcesState
        } else {
            sourcesList
        }
    }

    private var loadingState: some View {
        ProgressView {
            Text(.loadingSources)
                .font(.stateMessage)
                .foregroundStyle(Color.stateMessage)
        }
    }

    private var noSourcesState: some View {
        VStack(spacing: .stateSpacing) {
            Image(.noSources)
                .font(.stateIcon)
                .foregroundStyle(Color.stateIcon)
            Text(.noSourcesMessage)
                .font(.stateMessage)
                .foregroundStyle(Color.stateMessage)
                .multilineTextAlignment(.center)
        }
        .padding(.stateHPadding)
    }

    private var sourcesList: some View {
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
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let pageBackground: Self = .backgroundSecondary
    fileprivate static let stateIcon: Self = .undefinedGrey
    fileprivate static let stateMessage: Self = .textSecondary
}

extension Font {
    fileprivate static let stateIcon: Self = .largeTitle
    fileprivate static let stateMessage: Self = .body
}

extension ImageType {
    fileprivate static let noSources: Self = .system("tray")
}

extension EdgeInsets {
    fileprivate static let sourceRow = EdgeInsets(
        top: .rowVInset, leading: .rowHInset, bottom: .rowVInset, trailing: .rowHInset
    )
}

extension CGFloat {
    fileprivate static let rowVInset: Self = 8
    fileprivate static let rowHInset: Self = 16
    fileprivate static let stateSpacing: Self = 12
    fileprivate static let stateHPadding: Self = 32
}

extension LocalizedStringKey {
    fileprivate static let noSourcesMessage: Self = "No sources available yet."
    fileprivate static let loadingSources: Self = "Loading sources…"
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

#Preview("Start page - single source - light") {
    StartPageView(store: .previewSingle)
        .preferredColorScheme(.light)
}

#Preview("Start page - single source - dark") {
    StartPageView(store: .previewSingle)
        .preferredColorScheme(.dark)
}

#Preview("Start page - loading - light") {
    StartPageView(store: .previewLoading)
        .preferredColorScheme(.light)
}

#Preview("Start page - loading - dark") {
    StartPageView(store: .previewLoading)
        .preferredColorScheme(.dark)
}

extension StoreOf<StartPage> {
    fileprivate static var previewMocked: StoreOf<StartPage> {
        preview(sources: Source.mocks)
    }

    fileprivate static var previewEmpty: StoreOf<StartPage> {
        preview(sources: [])
    }

    fileprivate static var previewSingle: StoreOf<StartPage> {
        preview(sources: [.mbnetMock])
    }

    /// A load that never returns, so the canvas shows the state that precedes the first result.
    fileprivate static var previewLoading: StoreOf<StartPage> {
        Store(initialState: StartPage.State()) {
            StartPage()
        } withDependencies: {
            $0.blSources = .previewMock
            $0.blSources.knownSources = {
                try? await Task.sleep(for: .seconds(.previewNeverFinishes))
                return []
            }
        }
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

extension Double {
    fileprivate static let previewNeverFinishes: Self = 3600
}
