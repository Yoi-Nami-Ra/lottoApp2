//
//  SourceEntry.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 18/07/2025.
//

import ComposableArchitecture
import SwiftUI

struct SourceEntryView: View {
    @Environment(\.colorScheme) var colorScheme

    @Bindable var store: StoreOf<SourceEntry>

    var body: some View {
        VStack(alignment: .leading, spacing: .headerDataSpacing) {
            headerRow
            details
        }
        .modifier(SourceCardStyle.sourceCardStyle(isSelected: store.isSelected))
        // A tap gesture rather than wrapping the card in a `Button`: the Refresh button lives inside, and
        // a nested button would swallow or ambiguate its taps (FR-012). `contentShape` makes the gaps
        // between rows hittable too, so "anywhere on the card" is literal.
        .contentShape(Rectangle())
        .onTapGesture { store.send(.cardTapped) }
        // `.contain` keeps Refresh as its own element (FR-032) while the card itself still carries the
        // name, the selected trait, and a way to choose it without sight of the highlight.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(store.name))
        .accessibilityAddTraits(store.isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(named: Text(.chooseSourceAction)) { store.send(.cardTapped) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: .headerVSpacing) {
                titleRow

                syncStatusBadge
            }

            Spacer()

            VStack(alignment: .trailing) {
                HStack(spacing: .headerVSpacing) {
                    Image(.records)
                        .foregroundStyle(.textPrimary)
                    recordsCount
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.textPrimary)
                }
                Text(.records)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    /// The checkmark is what keeps the chosen state legible without colour — the border alone would fail
    /// for anyone who cannot distinguish it (FR-015).
    private var titleRow: some View {
        HStack(spacing: .titleCheckSpacing) {
            SourceTitle(title: store.name)

            if store.isSelected {
                Image(.selectedCheckmark)
                    .font(.selectedCheckmark)
                    .foregroundStyle(Color.selectedCheckmark)
            }
        }
    }

    private var recordsCount: some View {
        if let count = store.recordsCount {
            Text(count.toString)
        } else {
            Text(.notAvailable)
        }
    }

    private var syncStatusBadge: some View {
        HStack {
            Image(.lastSync)
            if let lastSync = store.lastSync {
                Text(.lastSynced(lastSync))
                    .font(.caption)
            } else {
                Text(.notSynced)
            }
        }
        .foregroundStyle(lastSyncForeground)
        .padding(.horizontal, .syncStatusHPadding)
        .padding(.vertical, .syncStatusVPadding)
        .background(lastSyncBackground)
        .cornerRadius(.syncStatusCorners)
    }

    private var lastSyncForeground: Color {
        .syncSeverityForeground(store.lastSyncSeverity)
    }

    private var lastSyncBackground: Color {
        lastSyncForeground.opacity(colorScheme == .light ? .lightOpacity : .darkOpacity)
    }

    private var details: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Image(.firstRecord)
                        .foregroundStyle(Color.firstRecordImage)
                    VStack(alignment: .leading, spacing: .detailsSpacing) {
                        Text(.firstRecordTitle)
                            .font(.firstlastRecordTitle)
                            .foregroundStyle(Color.firstlastRecordTitle)
                        firstRecordDate
                            .font(.firstlastRecordDate)
                            .fontWeight(.firstlastRecordDate)
                            .foregroundStyle(Color.firstlastRecordDate)
                    }
                }
                HStack {
                    Image(.lastRecord)
                        .foregroundStyle(Color.lastRecordImage)
                    VStack(alignment: .leading, spacing: .detailsSpacing) {
                        Text(.lastRecordTitle)
                            .font(.firstlastRecordTitle)
                            .foregroundStyle(Color.firstlastRecordTitle)
                        lastRecordDate
                            .font(.firstlastRecordDate)
                            .fontWeight(.firstlastRecordDate)
                            .foregroundStyle(Color.firstlastRecordDate)
                    }
                }
            }
            Spacer()
            refreshButton
        }
    }

    private var refreshButton: some View {
        Button {
            store.send(.refreshButtonTapped)
        } label: {
            HStack(spacing: .refreshIconSpacing) {
                Image(.refresh)
                    .rotationEffect(.degrees(store.isRefreshing ? .refreshSpinDegrees : 0))
                    .animation(
                        store.isRefreshing ? .refreshSpin : .default,
                        value: store.isRefreshing
                    )
                Text(store.isRefreshing ? .refreshing : .refresh)
                    .fontWeight(.refreshLabel)
            }
            .font(.refreshLabel)
            .foregroundStyle(store.isRefreshing ? Color.refreshActiveForeground : .refreshIdleForeground)
            .padding(.horizontal, .refreshHPadding)
            .padding(.vertical, .refreshVPadding)
            .background(store.isRefreshing ? Color.refreshActiveBackground : .refreshIdleBackground)
            .cornerRadius(.refreshCorners)
            .overlay(
                RoundedRectangle(cornerRadius: .refreshCorners)
                    .stroke(
                        store.isRefreshing ? Color.refreshActiveBorder : .refreshIdleBorder,
                        lineWidth: .refreshBorderWidth
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(store.isRefreshing)
    }

    private var firstRecordDate: some View {
        if let date = store.firstRecordDate {
            Text(date.formatted(date: .abbreviated, time: .omitted))
        } else {
            Text(.notAvailable)
        }
    }

    private var lastRecordDate: some View {
        if let date = store.lastRecordDate {
            Text(date.formatted(date: .abbreviated, time: .omitted))
        } else {
            Text(.notAvailable)
        }
    }
}

// MARK: - Styles
struct SourceCardStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, .cardVPadding)
            .padding(.horizontal, .cardHPadding)
            .background(.backgroundPrimary)
            .cornerRadius(.cardCorners)
            .overlay(
                RoundedRectangle(cornerRadius: .cardCorners)
                    .stroke(
                        Color.cardBorder(isSelected: isSelected),
                        lineWidth: .cardBorderWidth(isSelected: isSelected)
                    )
            )
            .shadow(color: .cardShadow, radius: .shadowRadius, x: .shadowXOffset, y: .shadowYOffset)
    }
}

extension ViewModifier where Self == SourceCardStyle {
    static func sourceCardStyle(isSelected: Bool) -> SourceCardStyle { .init(isSelected: isSelected) }
}

// MARK: - Resources
extension Color {
    fileprivate static var cardShadow: Self { .shadow }
    /// A `switch` rather than a dictionary lookup with a fallback: adding a severity then fails to compile
    /// instead of silently rendering as an error colour.
    fileprivate static func syncSeverityForeground(_ severity: SourceEntry.SyncSeverity) -> Self {
        switch severity {
        case .low: .syncSeverityLow
        case .medium: .syncSeverityMedium
        case .high: .syncSeverityHigh
        case .notSynced: .syncSeverityNone
        }
    }
    fileprivate static func cardBorder(isSelected: Bool) -> Self {
        isSelected ? .cardSelectedBorder : .cardIdleBorder
    }
    fileprivate static let cardSelectedBorder: Self = .primaryBlue
    fileprivate static let cardIdleBorder: Self = .clear
    fileprivate static let selectedCheckmark: Self = .primaryBlue

    fileprivate static let firstRecordImage: Self = .primaryBlue
    fileprivate static let firstlastRecordTitle: Self = .textSecondary
    fileprivate static let firstlastRecordDate: Self = .textPrimary

    fileprivate static let lastRecordImage: Self = .accentPurple

    fileprivate static let syncSeverityLow: Self = .successGreen
    fileprivate static let syncSeverityMedium: Self = .warningYellow
    fileprivate static let syncSeverityHigh: Self = .errorRed
    fileprivate static let syncSeverityNone: Self = .undefinedGrey

    fileprivate static let refreshIdleForeground: Self = .primaryBlue
    fileprivate static let refreshActiveForeground: Self = .textSecondary
    fileprivate static let refreshIdleBackground: Self = .primaryBlue.opacity(0.1)
    fileprivate static let refreshActiveBackground: Self = .undefinedGrey.opacity(0.15)
    fileprivate static let refreshIdleBorder: Self = .primaryBlue.opacity(0.3)
    fileprivate static let refreshActiveBorder: Self = .undefinedGrey
}

extension Font {
    fileprivate static let selectedCheckmark: Self = .title3
    fileprivate static let firstlastRecordTitle: Self = .caption
    fileprivate static let firstlastRecordDate: Self = .subheadline
    fileprivate static let refreshLabel: Self = .caption
}

extension Font.Weight {
    fileprivate static let firstlastRecordDate: Self = .medium
    fileprivate static let refreshLabel: Self = .medium
}

extension Animation {
    fileprivate static let refreshSpin: Self = .linear(duration: 1).repeatForever(autoreverses: false)
}

extension ImageType {
    fileprivate static let selectedCheckmark: Self = .system("checkmark.circle.fill")
    fileprivate static let firstRecord: Self = .system("calendar")
    fileprivate static let records: Self = .system("square.3.layers.3d")
    fileprivate static let lastRecord: Self = .system("clock")
    fileprivate static let lastSync: Self = .system("arrow.trianglehead.2.clockwise.rotate.90")
    fileprivate static let refresh: Self = .system("arrow.trianglehead.2.clockwise.rotate.90")
}

extension CGFloat {
    fileprivate static func cardBorderWidth(isSelected: Bool) -> Self {
        isSelected ? .cardSelectedBorderWidth : .cardIdleBorderWidth
    }
    fileprivate static let cardSelectedBorderWidth: Self = 2
    fileprivate static let cardIdleBorderWidth: Self = 0
    fileprivate static let titleCheckSpacing: Self = 6

    fileprivate static let headerDataSpacing: Self = 16
    fileprivate static let cardCorners: Self = 12
    fileprivate static let cardVPadding: Self = 8
    fileprivate static let cardHPadding: Self = 10

    fileprivate static let shadowRadius: Self = 2
    fileprivate static let shadowXOffset: Self = 0
    fileprivate static let shadowYOffset: Self = 1

    fileprivate static let detailsSpacing: Self = 2
    fileprivate static let headerVSpacing: Self = 4

    fileprivate static let syncStatusHPadding: Self = 8
    fileprivate static let syncStatusVPadding: Self = 4
    fileprivate static let syncStatusCorners: Self = 12

    fileprivate static let refreshIconSpacing: Self = 4
    fileprivate static let refreshHPadding: Self = 12
    fileprivate static let refreshVPadding: Self = 6
    fileprivate static let refreshCorners: Self = 8
    fileprivate static let refreshBorderWidth: Self = 1
}

extension Double {
    fileprivate static let lightOpacity: Self = 0.15
    fileprivate static let darkOpacity: Self = 0.35

    fileprivate static let refreshSpinDegrees: Self = 360
}

extension LocalizedStringKey {
    fileprivate static let chooseSourceAction: Self = "Choose this source"
    fileprivate static let firstRecordTitle: Self = "First Record:"
    fileprivate static let lastRecordTitle: Self = "Latest Record:"
    fileprivate static func lastSynced(_ date: Date) -> Self { "Last synced: \(date.formatted(date: .abbreviated, time: .shortened))" }
    fileprivate static let notSynced: Self = "Not synced"
    fileprivate static let records: Self = "records"
    fileprivate static let notAvailable: Self = "N/A"
    fileprivate static let refresh: Self = "Refresh"
    fileprivate static let refreshing: Self = "Refreshing…"
}

#Preview("Dark Mode - none") {
    SourceEntryView(store: Store(initialState: .mock1n) { SourceEntry() })
        .padding()
        .background(.backgroundTertiary)
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode - medium") {
    SourceEntryView(store: Store(initialState: .mock1m) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode - severe") {
    SourceEntryView(store: Store(initialState: .mock1s) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode - empty") {
    SourceEntryView(store: Store(initialState: .mock1e) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - none") {
    SourceEntryView(store: Store(initialState: .mock1n) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Light Mode - medium") {
    SourceEntryView(store: Store(initialState: .mock1m) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Light Mode - severe") {
    SourceEntryView(store: Store(initialState: .mock1s) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Light Mode - empty") {
    SourceEntryView(store: Store(initialState: .mock1e) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Dark Mode - refreshing") {
    SourceEntryView(store: Store(initialState: .mock1r) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - refreshing") {
    SourceEntryView(store: Store(initialState: .mock1r) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Light Mode - selected") {
    SourceEntryView(store: Store(initialState: .mock1selected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Dark Mode - selected") {
    SourceEntryView(store: Store(initialState: .mock1selected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - selected while refreshing") {
    SourceEntryView(store: Store(initialState: .mock1selectedRefreshing) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Dark Mode - error alert") {
    SourceEntryView(store: Store(initialState: .mock1a) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - error alert") {
    SourceEntryView(store: Store(initialState: .mock1a) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

extension SourceEntry.State {
    static let mock1n: Self = .init(
        id: "mbtn",
        name: "MBTN Server",
        lastSync: Date(timeIntervalSinceNow: -100_000),         // ~1.2 days
        lastSyncSeverity: .low,                                 // green
        firstRecordDate: Date(timeIntervalSince1970: 18_223_210),
        lastRecordDate: Date(timeIntervalSinceNow: -180_000),
        recordsCount: 15_847
    )

    static let mock1m: Self = .init(
        id: "mbtn",
        name: "MBTN Server",
        lastSync: Date(timeIntervalSinceNow: -260_000),         // ~3 days
        lastSyncSeverity: .medium,                              // yellow
        firstRecordDate: Date(timeIntervalSince1970: 18_223_210),
        lastRecordDate: Date(timeIntervalSinceNow: -180_000),
        recordsCount: 15_847
    )

    static let mock1s: Self = .init(
        id: "mbtn",
        name: "MBTN Server",
        lastSync: Date(timeIntervalSinceNow: -500_000),         // ~5.8 days
        lastSyncSeverity: .high,                                // red
        firstRecordDate: Date(timeIntervalSince1970: 18_223_210),
        lastRecordDate: Date(timeIntervalSinceNow: -180_000),
        recordsCount: 15_847
    )

    static let mock1e: Self = .init(
        id: "mbtn",
        name: "MBTN Server",
        lastSync: nil,
        lastSyncSeverity: .notSynced,
        firstRecordDate: nil,
        lastRecordDate: nil,
        recordsCount: nil
    )

    static let mock1r: Self = .init(
        id: "mbnet",
        name: "MBNet Server",
        lastSync: Date(timeIntervalSinceNow: -100_000),
        lastSyncSeverity: .low,
        firstRecordDate: Date(timeIntervalSince1970: 18_223_210),
        lastRecordDate: Date(timeIntervalSinceNow: -180_000),
        recordsCount: 7380,
        isRefreshing: true
    )

    static let mock1selected: Self = {
        var state = mock1n
        state.isSelected = true
        return state
    }()

    /// A chosen source can still be syncing — choosing and refreshing are independent (FR-017).
    static let mock1selectedRefreshing: Self = {
        var state = mock1r
        state.isSelected = true
        return state
    }()

    static let mock1a: Self = {
        var state = Self(
            id: "mbnet",
            name: "MBNet Server",
            lastSync: Date(timeIntervalSinceNow: -100_000),
            lastSyncSeverity: .low,
            firstRecordDate: Date(timeIntervalSince1970: 18_223_210),
            lastRecordDate: Date(timeIntervalSinceNow: -180_000),
            recordsCount: 7380
        )
        state.alert = .syncFailed
        return state
    }()
}

extension Int {
    var toString: String { String(self) }
}
