//
//  ResultPageView.swift
//  lottoApp2
//
//  One block's full output (LTA-9): count rows, draws, or a single number, headed by the source it was
//  computed from.
//

import ComposableArchitecture
import SwiftUI

struct ResultPageView: View {
    let store: StoreOf<ResultPage>

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)
            if let banner = LocalizedStringKey.freshnessBanner(store.freshness, chainChanged: store.chainChanged) {
                Section {
                    Label(banner, systemImage: .bannerIcon)
                        .font(.banner)
                        .foregroundStyle(Color.bannerForeground)
                }
                .listRowBackground(Color.bannerBackground)
            }
            if store.isEmpty {
                Section {
                    Text(.emptyMessage)
                        .font(.emptyMessage)
                        .foregroundStyle(Color.secondaryText)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            } else if !store.groups.isEmpty {
                ForEach(store.groups) { group in
                    Section(LocalizedStringKey.groupHeader(group)) {
                        ForEach(group.shown) { row in
                            Text(.countItem(row.item))
                                .font(.rowItem)
                                .monospacedDigit()
                                .foregroundStyle(Color.primaryText)
                        }
                        if group.remaining > 0 {
                            Button(LocalizedStringKey.more(group.remaining)) {
                                store.send(.showAllTapped(count: group.count))
                            }
                        }
                    }
                }
            } else {
                Section { content }
            }
        }
        .navigationTitle(LocalizedStringKey.resultTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .headerVSpacing) {
            Text(.sourceCaption)
                .font(.detail)
                .foregroundStyle(Color.secondaryText)
            Text(store.stamp.sourceDisplayName)
                .font(.headerName)
                .foregroundStyle(Color.primaryText)
            Text(.dataState(store.stamp.dataState))
                .font(.detail)
                .foregroundStyle(Color.secondaryText)
        }
        .listRowInsets(.headerInsets)
    }

    @ViewBuilder
    private var content: some View {
        switch store.value {
        case .counts:
            ForEach(store.rows) { row in
                HStack(spacing: .rowSpacing) {
                    if let rank = row.rank {
                        Text(.rank(rank))
                            .font(.rowCount)
                            .monospacedDigit()
                            .foregroundStyle(Color.tertiaryText)
                            .frame(minWidth: .rankWidth, alignment: .leading)
                    }
                    Text(.countItem(row.item))
                        .font(.rowItem)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Text(row.count.formatted())
                        .font(.rowCount)
                        .monospacedDigit()
                        .foregroundStyle(Color.secondaryText)
                }
            }
        case .draws(let game):
            ForEach(game.entries, id: \.index) { entry in
                VStack(alignment: .leading, spacing: .drawVSpacing) {
                    Text(.drawHeading(entry))
                        .font(.detail)
                        .foregroundStyle(Color.secondaryText)
                    Text(.elements(entry.combination.elements))
                        .font(.rowItem)
                        .monospacedDigit()
                        .foregroundStyle(Color.primaryText)
                }
            }
        case .number(let total):
            Text(.total(total))
                .font(.total)
                .foregroundStyle(Color.primaryText)
        }
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let primaryText: Self = .textPrimary
    fileprivate static let secondaryText: Self = .textSecondary
    fileprivate static let tertiaryText: Self = .textTertiary
    fileprivate static let bannerForeground: Self = .textPrimary
    fileprivate static let bannerBackground: Self = .warningYellow.opacity(.bannerOpacity)
}

extension Font {
    fileprivate static let headerName: Self = .title2.weight(.semibold)
    fileprivate static let detail: Self = .caption
    fileprivate static let rowItem: Self = .body
    fileprivate static let rowCount: Self = .body
    fileprivate static let total: Self = .largeTitle
    fileprivate static let emptyMessage: Self = .callout
    fileprivate static let banner: Self = .footnote
}

extension CGFloat {
    fileprivate static let headerVSpacing: Self = 4
    fileprivate static let drawVSpacing: Self = 2
    fileprivate static let rowSpacing: Self = 12
    fileprivate static let rankWidth: Self = 28
}

extension EdgeInsets {
    fileprivate static let headerInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 0)
}

extension Double {
    fileprivate static let bannerOpacity: Self = 0.25
}

extension String {
    fileprivate static let bannerIcon = "exclamationmark.triangle"
}

extension LocalizedStringKey {
    fileprivate static let resultTitle: Self = "Result"
    fileprivate static let sourceCaption: Self = "Source"
    fileprivate static let emptyMessage: Self = "Nothing to show — this result is empty."

    fileprivate static func dataState(_ state: SourceDataState) -> Self {
        if let latest = state.latestRecord {
            return "\(state.recordsCount.formatted()) draws · latest \(latest.formatted(date: .abbreviated, time: .omitted))"
        }
        return "\(state.recordsCount.formatted()) draws"
    }

    fileprivate static func countItem(_ item: CountItem) -> Self {
        switch item {
        case .element(let element): "\(element.formatted())"
        case .combination(let combination): .elements(combination.elements)
        case .subCombination(let sub): .elements(sub.elements)
        }
    }

    fileprivate static func groupHeader(_ group: ResultPage.CountGroup) -> Self {
        group.count == 1
            ? "Drawn once · \(group.total.formatted())"
            : "Drawn \(group.count.formatted()) times · \(group.total.formatted())"
    }

    fileprivate static func more(_ remaining: Int) -> Self { "and \(remaining.formatted()) more" }

    fileprivate static func elements(_ elements: [Element]) -> Self {
        "\(elements.map { $0.formatted() }.joined(separator: " · "))"
    }

    fileprivate static func drawHeading(_ entry: GameEntry) -> Self {
        "#\(entry.index.formatted()) · \(entry.date.formatted(date: .abbreviated, time: .omitted))"
    }

    fileprivate static func total(_ total: Int) -> Self { "Total: \(total.formatted())" }

    fileprivate static func rank(_ rank: Int) -> Self { "\(rank.formatted())." }

    fileprivate static func freshnessBanner(_ freshness: ResultFreshness, chainChanged: Bool) -> Self? {
        switch freshness {
        case .outOfDate: "Out of date — the source's data has changed since this was computed."
        case .sourceUnavailable: "Source unavailable — it no longer exists."
        case .current: chainChanged ? "The chain changed since this was saved." : nil
        }
    }
}

#Preview("Result - elements - light") {
    NavigationStack { ResultPageView(store: .preview(.previewElementCounts)) }
        .preferredColorScheme(.light)
}

#Preview("Result - elements - dark") {
    NavigationStack { ResultPageView(store: .preview(.previewElementCounts)) }
        .preferredColorScheme(.dark)
}

#Preview("Result - empty - light") {
    NavigationStack { ResultPageView(store: .preview(.counts(CountResult(unordered: [])))) }
        .preferredColorScheme(.light)
}

#Preview("Result - empty - dark") {
    NavigationStack { ResultPageView(store: .preview(.counts(CountResult(unordered: [])))) }
        .preferredColorScheme(.dark)
}

#Preview("Result - out of date - light") {
    NavigationStack { ResultPageView(store: .preview(.previewElementCounts, freshness: .outOfDate)) }
        .preferredColorScheme(.light)
}

#Preview("Result - ranked - light") {
    NavigationStack { ResultPageView(store: .preview(.previewRankedCounts)) }
        .preferredColorScheme(.light)
}

#Preview("Result - ranked - dark") {
    NavigationStack { ResultPageView(store: .preview(.previewRankedCounts)) }
        .preferredColorScheme(.dark)
}

#Preview("Result - grouped combinations - light") {
    NavigationStack { ResultPageView(store: .preview(.previewCombinationCounts)) }
        .preferredColorScheme(.light)
}

#Preview("Result - grouped combinations - dark") {
    NavigationStack { ResultPageView(store: .preview(.previewCombinationCounts)) }
        .preferredColorScheme(.dark)
}

#Preview("Result - pairs - light") {
    NavigationStack { ResultPageView(store: .preview(.previewPairCounts)) }
        .preferredColorScheme(.light)
}

#Preview("Result - number - light") {
    NavigationStack { ResultPageView(store: .preview(.number(42_072))) }
        .preferredColorScheme(.light)
}

#Preview("Result - number - dark") {
    NavigationStack { ResultPageView(store: .preview(.number(42_072))) }
        .preferredColorScheme(.dark)
}

#Preview("Result - draws - dark") {
    NavigationStack { ResultPageView(store: .preview(.draws(.previewMock))) }
        .preferredColorScheme(.dark)
}

extension StoreOf<ResultPage> {
    fileprivate static func preview(_ value: BlockValue, freshness: ResultFreshness = .current) -> StoreOf<ResultPage> {
        Store(initialState: ResultPage.State(value: value, stamp: .previewMock, freshness: freshness)) {
            ResultPage()
        }
    }
}
