//
//  CompactSourceEntryView.swift
//  lottoApp2
//
//  The start page's source card at compact width (spec 007, design/final/source-cards.html): one row —
//  severity dot, name, refresh, disclosure — driven by the same `SourceEntry` store as the full card.
//

import ComposableArchitecture
import SwiftUI

struct CompactSourceEntryView: View {
    @Bindable var store: StoreOf<SourceEntry>

    var body: some View {
        row
            .modifier(SourceCardStyle.sourceCardStyle(isSelected: store.isSelected))
            // As on the full card: a tap gesture rather than a `Button`, so the two buttons inside keep their
            // own taps, and `contentShape` makes the whole card — gaps included — choose the source (FR-004).
            .contentShape(Rectangle())
            .onTapGesture { store.send(.cardTapped) }
            .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var row: some View {
        HStack(spacing: .rowSpacing) {
            Circle()
                .fill(Color.sourceCardSeverity(store.lastSyncSeverity))
                .frame(width: .dotSize, height: .dotSize)

            nameLabel
                .frame(maxWidth: .infinity, alignment: .leading)

            refreshButton
            disclosureButton
        }
        .frame(minHeight: .rowMinHeight)
    }

    /// The checkmark keeps the choice legible without the border's colour, and "Not synced" keeps a
    /// never-synced source legible without the dot's grey (FR-003).
    private var nameLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: .nameSpacing) {
            Text(store.name)
                .font(.compactName)
                .foregroundStyle(Color.compactName)

            if store.isSelected {
                Image(.sourceCardCheckmark)
                    .font(.compactCheckmark)
                    .foregroundStyle(Color.sourceCardCheckmark)
            }

            if store.lastSync == nil {
                Text(.sourceCardNotSynced)
                    .font(.notSyncedInline)
                    .foregroundStyle(Color.notSyncedInline)
            }
        }
    }

    /// Icon only; the spin, the dimming and the ignored taps while syncing are the full card's (FR-005).
    private var refreshButton: some View {
        Button {
            store.send(.refreshButtonTapped)
        } label: {
            RefreshIcon(isRefreshing: store.isRefreshing)
                .font(.compactRefreshIcon)
                .frame(width: .refreshWidth, height: .refreshHeight)
                .modifier(RefreshButtonStyle(isRefreshing: store.isRefreshing))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(store.isRefreshing)
    }

    private var disclosureButton: some View {
        Button {
            store.send(.disclosureButtonTapped)
        } label: {
            Image(store.isExpanded ? .collapseDetails : .expandDetails)
                .font(.disclosure)
                .fontWeight(.disclosure)
                .foregroundStyle(Color.disclosure)
                .frame(width: .disclosureWidth, height: .refreshHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let compactName: Self = .textPrimary
    fileprivate static let notSyncedInline: Self = .textSecondary
    fileprivate static let disclosure: Self = .textTertiary
}

extension Font {
    fileprivate static let compactName: Self = .headline
    fileprivate static let compactCheckmark: Self = .body
    fileprivate static let notSyncedInline: Self = .caption
    fileprivate static let compactRefreshIcon: Self = .callout
    fileprivate static let disclosure: Self = .footnote
}

extension Font.Weight {
    fileprivate static let disclosure: Self = .semibold
}

extension ImageType {
    fileprivate static let expandDetails: Self = .system("chevron.down")
    fileprivate static let collapseDetails: Self = .system("chevron.up")
}

extension CGFloat {
    fileprivate static let dotSize: Self = 12
    /// With `SourceCardStyle`'s 8 pt vertical padding on each side this makes the 52 pt minimum card (FR-002).
    fileprivate static let rowMinHeight: Self = 36
    fileprivate static let rowSpacing: Self = 10
    fileprivate static let nameSpacing: Self = 6
    fileprivate static let refreshWidth: Self = 36
    fileprivate static let refreshHeight: Self = 32
    fileprivate static let disclosureWidth: Self = 28
}

#Preview("Compact - collapsed - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1n) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Compact - collapsed - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1n) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Compact - selected - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1selected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Compact - selected - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1selected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Compact - refreshing - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1r) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Compact - refreshing - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1r) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Compact - never synced - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1e) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Compact - never synced - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1e) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}
