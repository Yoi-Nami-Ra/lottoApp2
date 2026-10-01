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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable var store: StoreOf<SourceEntry>

    var body: some View {
        VStack(alignment: .leading, spacing: .rowDetailsSpacing) {
            row
            if store.isExpanded {
                details
            }
        }
        .modifier(SourceCardStyle.sourceCardStyle(isSelected: store.isSelected))
        // As on the full card: a tap gesture rather than a `Button`, so the two buttons inside keep their
        // own taps, and `contentShape` makes the whole card — details and gaps included — choose the
        // source (FR-004, clarification 1).
        .contentShape(Rectangle())
        .onTapGesture { store.send(.cardTapped) }
        // The full card's pattern: `.contain` keeps both buttons as their own elements, while the card carries
        // the name, the sync status as words (so severity never depends on the dot), the selected trait, and a
        // way to choose it without sight of the highlight (FR-012).
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(store.name))
        .accessibilityValue(Text(syncStatus))
        .accessibilityAddTraits(store.isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(named: Text(.sourceCardChooseAction)) { store.send(.cardTapped) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var row: some View {
        HStack(spacing: .rowSpacing) {
            // Decorative: the card's accessibility value says the same in words.
            Circle()
                .fill(Color.sourceCardSeverity(store.lastSyncSeverity))
                .frame(width: .dotSize, height: .dotSize)
                .accessibilityHidden(true)

            nameLabel
                .frame(maxWidth: .infinity, alignment: .leading)

            // Intrinsic size at every text size: at accessibility sizes the name wraps onto more lines
            // rather than squeezing the buttons (FR-013).
            refreshButton
                .fixedSize()
            disclosureButton
                .fixedSize()
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
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(.nameOverNotSynced)

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
            SyncIcon(action: .refresh, isSyncing: store.isRefreshing)
                .font(.compactRefreshIcon)
                .frame(width: .refreshWidth, height: .refreshHeight)
                .modifier(RefreshButtonStyle(isRefreshing: store.isRefreshing))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(store.isRefreshing)
        .accessibilityLabel(Text(store.isRefreshing ? .refreshingLabel : .refreshLabel))
    }

    private var syncStatus: LocalizedStringKey {
        store.lastSync.map(LocalizedStringKey.sourceCardLastSynced) ?? .sourceCardNotSynced
    }

    /// The record count, last sync, the last sync's skipped note and the record dates — what the full card shows,
    /// in the same formats (FR-008, FR-009). The note spans both columns between the two rows (clarification 2).
    private var details: some View {
        VStack(alignment: .leading, spacing: .detailsSpacing) {
            Divider()
            detailsBody
                // Lines the details up under the name rather than under the dot.
                .padding(.leading, .detailsLeadingInset)
        }
    }

    /// Two columns normally; one at accessibility text sizes, where each half of the card would be narrower
    /// than a single word and the labels would break mid-word (FR-013).
    @ViewBuilder
    private var detailsBody: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: .detailsSpacing) {
                recordsDetail
                lastSyncDetail
                if let count = store.skippedInLastSync {
                    SkippedRecordsNote(count: count)
                }
                RecordDateDetail(kind: .first, date: store.firstRecordDate)
                RecordDateDetail(kind: .latest, date: store.lastRecordDate)
            }
        } else {
            Grid(alignment: .topLeading, horizontalSpacing: .detailsColumnSpacing, verticalSpacing: .detailsSpacing) {
                GridRow {
                    recordsDetail
                    lastSyncDetail
                }
                if let count = store.skippedInLastSync {
                    GridRow {
                        SkippedRecordsNote(count: count)
                            .gridCellColumns(.detailsColumns)
                    }
                }
                GridRow {
                    RecordDateDetail(kind: .first, date: store.firstRecordDate)
                    RecordDateDetail(kind: .latest, date: store.lastRecordDate)
                }
            }
        }
    }

    private var recordsDetail: some View {
        VStack(alignment: .leading, spacing: .detailLabelSpacing) {
            Text(.recordsTitle)
                .font(.detailLabel)
                .foregroundStyle(Color.detailLabel)
            recordsCount
                .font(.recordsCount)
                .fontWeight(.recordsCount)
                .foregroundStyle(Color.recordsCount)
        }
    }

    private var recordsCount: Text {
        if let count = store.recordsCount {
            Text(count.toString)
        } else {
            Text(.sourceCardNotAvailable)
        }
    }

    private var lastSyncDetail: some View {
        VStack(alignment: .leading, spacing: .detailLabelSpacing) {
            Text(.lastSyncTitle)
                .font(.detailLabel)
                .foregroundStyle(Color.detailLabel)
            SyncStatusBadge(lastSync: store.lastSync, severity: store.lastSyncSeverity)
        }
    }

    private var disclosureButton: some View {
        Button {
            // Animated through the store's transaction, so the reducer stays pure; none with Reduce Motion (R9).
            store.send(.disclosureButtonTapped, animation: reduceMotion ? nil : .disclosure)
        } label: {
            Image(store.isExpanded ? .collapseDetails : .expandDetails)
                .font(.disclosure)
                .fontWeight(.disclosure)
                .foregroundStyle(Color.disclosure)
                .frame(width: .disclosureWidth, height: .refreshHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(Text(store.isExpanded ? .hideDetails : .showDetails))
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let compactName: Self = .textPrimary
    fileprivate static let notSyncedInline: Self = .textSecondary
    fileprivate static let disclosure: Self = .textTertiary
    fileprivate static let detailLabel: Self = .textSecondary
    fileprivate static let recordsCount: Self = .textPrimary
}

extension Font {
    fileprivate static let compactName: Self = .headline
    fileprivate static let compactCheckmark: Self = .body
    fileprivate static let notSyncedInline: Self = .caption
    fileprivate static let compactRefreshIcon: Self = .callout
    fileprivate static let disclosure: Self = .footnote
    fileprivate static let detailLabel: Self = .caption
    fileprivate static let recordsCount: Self = .title3
}

extension Font.Weight {
    fileprivate static let disclosure: Self = .semibold
    fileprivate static let recordsCount: Self = .bold
}

extension Animation {
    fileprivate static let disclosure: Self = .snappy
}

extension Int {
    fileprivate static let detailsColumns: Self = 2
}

extension Double {
    fileprivate static let nameOverNotSynced: Self = 1
}

extension DynamicTypeSize {
    /// `accessibility-extra-extra-extra-large`, the largest size the system offers.
    fileprivate static let largestAccessibility: Self = .accessibility5
}

extension LocalizedStringKey {
    fileprivate static let recordsTitle: Self = "Records"
    fileprivate static let lastSyncTitle: Self = "Last sync"
    fileprivate static let refreshLabel: Self = "Refresh"
    fileprivate static let refreshingLabel: Self = "Refreshing"
    fileprivate static let showDetails: Self = "Show details"
    fileprivate static let hideDetails: Self = "Hide details"
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
    fileprivate static let rowDetailsSpacing: Self = 4
    fileprivate static let detailsSpacing: Self = 8
    fileprivate static let detailsColumnSpacing: Self = 12
    fileprivate static let detailLabelSpacing: Self = 2
    /// The dot's width plus the row's spacing, so the details start where the name does.
    fileprivate static let detailsLeadingInset: Self = dotSize + rowSpacing
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

#Preview("Compact - expanded - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1expanded) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Compact - expanded - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1expanded) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Compact - expanded, selected - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1expandedSelected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Compact - expanded, selected - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1expandedSelected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Compact - expanded, skipped note - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1expandedSkipped) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Compact - expanded, skipped note - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1expandedSkipped) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Compact - expanded, never synced - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1expandedEmpty) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Compact - expanded, never synced - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1expandedEmpty) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Compact - AX5 collapsed - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1n) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
        .dynamicTypeSize(.largestAccessibility)
}

#Preview("Compact - AX5 collapsed, long name - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1longNameSelected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.largestAccessibility)
}

#Preview("Compact - AX5 expanded - light") {
    CompactSourceEntryView(store: Store(initialState: .mock1expanded) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
        .dynamicTypeSize(.largestAccessibility)
}

#Preview("Compact - AX5 expanded, skipped note - dark") {
    CompactSourceEntryView(store: Store(initialState: .mock1expandedSkipped) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.largestAccessibility)
}

extension SourceEntry.State {
    fileprivate static let mock1longNameSelected: Self = {
        var state = mock1selected
        state.name = "EuroJackpot International Archive"
        return state
    }()
    fileprivate static let mock1expanded: Self = expanded(.mock1n)
    fileprivate static let mock1expandedSelected: Self = expanded(.mock1selected)
    fileprivate static let mock1expandedSkipped: Self = expanded(.mock1skipped)
    fileprivate static let mock1expandedEmpty: Self = expanded(.mock1e)

    private static func expanded(_ state: Self) -> Self {
        var state = state
        state.isExpanded = true
        return state
    }
}
