//
//  SourceEntry.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 18/07/2025.
//

import ComposableArchitecture
import SwiftUI

struct SourceEntryView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @Bindable var store: StoreOf<SourceEntry>

    var body: some View {
        VStack(alignment: .leading, spacing: .headerDataSpacing) {
            headerRow
            if let count = store.skippedInLastSync {
                // Full width between the header and the details (spec 005 clarification).
                SkippedRecordsNote(count: count)
            }
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
        .accessibilityAction(named: Text(.sourceCardChooseAction)) { store.send(.cardTapped) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    /// Same reflow as `details`, for the same reason: side by side at accessibility text sizes the two
    /// columns each end up narrower than a single word, so the name breaks as "MB" / "Net" / "Ser" / "ver"
    /// and the sync badge as "Last" / "syn" / "ced:". Stacked, each gets the full card width and wraps at
    /// word boundaries instead.
    private var headerRow: some View {
        headerLayout {
            VStack(alignment: .leading, spacing: .headerVSpacing) {
                titleRow

                SyncStatusBadge(lastSync: store.lastSync, severity: store.lastSyncSeverity)
            }
            // Stands in for the `Spacer()` this row used to carry — see the note on `details`.
            .frame(maxWidth: .infinity, alignment: .leading)

            recordsColumn
        }
    }

    private var headerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: .headerStackSpacing))
            : AnyLayout(HStackLayout(alignment: .top))
    }

    private var recordsColumn: some View {
        VStack(alignment: recordsAlignment) {
            HStack(spacing: .headerVSpacing) {
                Image(.records)
                    .foregroundStyle(.textPrimary)
                recordsCount
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(.recordsCountLines)
                    .minimumScaleFactor(.recordsCountScale)
            }
            Text(.records)
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
    }

    /// Trailing while the count sits in its own right-hand column; leading once it is stacked under the
    /// name, where a right-aligned count would read as belonging to nothing.
    private var recordsAlignment: HorizontalAlignment {
        dynamicTypeSize.isAccessibilitySize ? .leading : .trailing
    }

    /// The checkmark is what keeps the chosen state legible without colour — the border alone would fail
    /// for anyone who cannot distinguish it (FR-015).
    private var titleRow: some View {
        HStack(spacing: .titleCheckSpacing) {
            // The checkmark takes its intrinsic width and the title keeps the rest: without this the
            // two split the column evenly at accessibility text sizes and the name hyphen-breaks
            // mid-word ("MB-/Net/Serv/er") purely because the badge appeared next to it.
            SourceTitle(title: store.name)
                .layoutPriority(.titleOverCheckmark)

            if store.isSelected {
                Image(.sourceCardCheckmark)
                    .font(.selectedCheckmark)
                    .foregroundStyle(Color.sourceCardCheckmark)
                    .fixedSize()
            }
        }
    }

    /// `lineLimit(1)` plus a scale floor because a record count is a single number: allowed to wrap it
    /// splits across lines at accessibility text sizes and reads as two separate figures.
    private var recordsCount: some View {
        if let count = store.recordsCount {
            Text(count.toString)
        } else {
            Text(.sourceCardNotAvailable)
        }
    }

    /// Side by side normally, stacked at accessibility text sizes: squeezed into the narrow trailing
    /// column the labels character-break mid-word ("Latest Recor" / "d:") and the button hyphenates
    /// ("Re-" / "fres" / "h"). Reflowing gives both the full card width instead of shrinking them.
    private var details: some View {
        detailsLayout {
            VStack(alignment: .leading) {
                RecordDateDetail(kind: .first, date: store.firstRecordDate)
                RecordDateDetail(kind: .latest, date: store.lastRecordDate)
            }
            // Replaces the `Spacer()` this row used to carry: it pushes the button to the trailing edge
            // in the horizontal layout *and* gives the column the full width in the stacked one, where a
            // spacer would only have added dead vertical space.
            .frame(maxWidth: .infinity, alignment: .leading)

            refreshButton
                .layoutPriority(.refreshOverDetails)
        }
    }

    private var detailsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: .detailsStackSpacing))
            : AnyLayout(HStackLayout())
    }

    private var refreshButton: some View {
        Button {
            store.send(.refreshButtonTapped)
        } label: {
            HStack(spacing: .refreshIconSpacing) {
                RefreshIcon(isRefreshing: store.isRefreshing)
                // One word on one line: allowed to wrap it hyphen-breaks into "Re-" / "fres" / "h" at
                // accessibility text sizes. The scale floor keeps the longer "Refreshing…" readable
                // rather than truncated when the card is still narrow.
                Text(store.isRefreshing ? .refreshing : .refresh)
                    .fontWeight(.refreshLabel)
                    .lineLimit(.refreshLabelLines)
                    .minimumScaleFactor(.refreshLabelScale)
            }
            .font(.refreshLabel)
            .padding(.horizontal, .refreshHPadding)
            .padding(.vertical, .refreshVPadding)
            .modifier(RefreshButtonStyle(isRefreshing: store.isRefreshing))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(store.isRefreshing)
    }
}

// MARK: - Resources
extension Font {
    fileprivate static let selectedCheckmark: Self = .title3
    fileprivate static let refreshLabel: Self = .caption
}

extension Font.Weight {
    fileprivate static let refreshLabel: Self = .medium
}

extension ImageType {
    fileprivate static let records: Self = .system("square.3.layers.3d")
}

extension CGFloat {
    fileprivate static let titleCheckSpacing: Self = 6
    fileprivate static let recordsCountScale: Self = 0.5

    fileprivate static let headerDataSpacing: Self = 16

    fileprivate static let detailsStackSpacing: Self = 12
    fileprivate static let headerStackSpacing: Self = 8
    fileprivate static let headerVSpacing: Self = 4

    fileprivate static let refreshIconSpacing: Self = 4
    fileprivate static let refreshHPadding: Self = 12
    fileprivate static let refreshVPadding: Self = 6
    fileprivate static let refreshLabelScale: Self = 0.7
}

extension DynamicTypeSize {
    /// `accessibility-extra-extra-extra-large`, the largest size the system offers — the one the card
    /// has to survive.
    fileprivate static let largestAccessibility: Self = .accessibility5
}

extension Int {
    fileprivate static let recordsCountLines: Self = 1
    fileprivate static let refreshLabelLines: Self = 1
}

extension Double {
    fileprivate static let titleOverCheckmark: Self = 1
    fileprivate static let refreshOverDetails: Self = 1
}

extension LocalizedStringKey {
    fileprivate static let records: Self = "records"
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

#Preview("Dark Mode - format changed alert") {
    SourceEntryView(store: Store(initialState: .mock1aFormatChanged) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - format changed alert") {
    SourceEntryView(store: Store(initialState: .mock1aFormatChanged) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Light Mode - skipped note") {
    SourceEntryView(store: Store(initialState: .mock1skipped) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

#Preview("Dark Mode - skipped note") {
    SourceEntryView(store: Store(initialState: .mock1skipped) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - one skipped record") {
    SourceEntryView(store: Store(initialState: .mock1skippedOne) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
}

// The largest accessibility text size — `accessibility-extra-extra-extra-large` — is where the header
// and details rows used to squeeze their columns until the labels broke mid-word. These previews are the
// canvas check that both reflow instead.
#Preview("Light Mode - AX5") {
    SourceEntryView(store: Store(initialState: .mock1n) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
        .dynamicTypeSize(.largestAccessibility)
}

#Preview("Dark Mode - AX5") {
    SourceEntryView(store: Store(initialState: .mock1selected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.largestAccessibility)
}

#Preview("Light Mode - AX5 refreshing") {
    SourceEntryView(store: Store(initialState: .mock1r) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
        .dynamicTypeSize(.largestAccessibility)
}

#Preview("Light Mode - AX5 skipped note") {
    SourceEntryView(store: Store(initialState: .mock1skipped) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.light)
        .dynamicTypeSize(.largestAccessibility)
}

#Preview("Dark Mode - AX5 skipped note") {
    SourceEntryView(store: Store(initialState: .mock1skippedSelected) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.largestAccessibility)
}

#Preview("Dark Mode - AX5 empty") {
    SourceEntryView(store: Store(initialState: .mock1e) { SourceEntry() })
        .padding()
        .background(.backgroundSecondary)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.largestAccessibility)
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
        state.alert = .syncFailed(.serverUnreachable, sourceName: "MBNet Server")
        return state
    }()

    /// The last sync kept most draws but skipped three (spec 005 US1).
    static let mock1skipped: Self = {
        var state = mock1n
        state.skippedInLastSync = 3
        return state
    }()

    /// Singular wording (spec 005 US1-AS5).
    static let mock1skippedOne: Self = {
        var state = mock1n
        state.skippedInLastSync = 1
        return state
    }()

    static let mock1skippedSelected: Self = {
        var state = mock1skipped
        state.isSelected = true
        return state
    }()

    /// `mock1a` after a sync whose response was in a format the app doesn't recognise (spec 004 US1-AS5).
    static let mock1aFormatChanged: Self = {
        var state = mock1a
        state.alert = .syncFailed(.unreadableData, sourceName: "MBNet Server")
        return state
    }()
}

extension Int {
    var toString: String { String(self) }
}
