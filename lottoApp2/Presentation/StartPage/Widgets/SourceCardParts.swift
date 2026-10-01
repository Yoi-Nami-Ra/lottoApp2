//
//  SourceCardParts.swift
//  lottoApp2
//
//  The pieces the full source card (`SourceEntryView`) and the compact one (`CompactSourceEntryView`) both
//  draw, so a badge, a note or a refresh button reads the same in either variant (spec 007 R4). Each part
//  renders what it is handed and owns no state.
//

import SwiftUI

// MARK: - Styles
struct SourceCardStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, .cardVPadding)
            .padding(.horizontal, .cardHPadding)
            // Fills a regular-width grid cell, so the cards in one row share its height (FR-014). A `List` row
            // sizes to its content's ideal height, which this frame leaves alone, so it changes nothing there.
            .frame(maxHeight: .infinity, alignment: .top)
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

/// The refresh button's look in both variants — colours, border and corners — dimmed while a sync runs. The
/// label (icon only, or icon and text) and its padding belong to the caller.
struct RefreshButtonStyle: ViewModifier {
    let isRefreshing: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isRefreshing ? Color.refreshActiveForeground : .refreshIdleForeground)
            .background(isRefreshing ? Color.refreshActiveBackground : .refreshIdleBackground)
            .cornerRadius(.refreshCorners)
            .overlay(
                RoundedRectangle(cornerRadius: .refreshCorners)
                    .stroke(
                        isRefreshing ? Color.refreshActiveBorder : .refreshIdleBorder,
                        lineWidth: .refreshBorderWidth
                    )
            )
    }
}

// MARK: - Parts

/// The refresh glyph, spinning while a sync runs.
struct RefreshIcon: View {
    let isRefreshing: Bool

    var body: some View {
        Image(.refresh)
            .rotationEffect(.degrees(isRefreshing ? .refreshSpinDegrees : 0))
            .animation(isRefreshing ? .refreshSpin : .default, value: isRefreshing)
    }
}

/// The severity-coloured "Last synced: …" / "Not synced" capsule.
struct SyncStatusBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let lastSync: Date?
    let severity: SourceEntry.SyncSeverity

    var body: some View {
        HStack {
            Image(.lastSync)
            if let lastSync {
                Text(.sourceCardLastSynced(lastSync))
                    .font(.caption)
            } else {
                Text(.sourceCardNotSynced)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, .syncStatusHPadding)
        .padding(.vertical, .syncStatusVPadding)
        .background(foreground.opacity(colorScheme == .light ? .lightOpacity : .darkOpacity))
        .cornerRadius(.syncStatusCorners)
    }

    private var foreground: Color { .sourceCardSeverity(severity) }
}

/// The last sync's skipped-records warning (spec 005). Full width, so it needs no reflow rule of its own: at
/// accessibility text sizes it simply wraps, at word boundaries.
struct SkippedRecordsNote: View {
    @Environment(\.colorScheme) private var colorScheme

    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .skippedNoteIconSpacing) {
            // The icon carries the warning without relying on colour (FR-011); the text already says it all,
            // so VoiceOver skips the icon and reads the note as its own element inside the card (FR-010).
            Image(.skippedWarning)
                .foregroundStyle(Color.skippedNoteIcon)
                .accessibilityHidden(true)
            // No `lineLimit` or scale floor: a sentence may wrap, whereas shrinking it would make it unreadable
            // at the very sizes it has to survive.
            Text(.skippedInLastSync(count))
                .font(.skippedNote)
                .foregroundStyle(Color.skippedNoteText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .skippedNoteHPadding)
        .padding(.vertical, .skippedNoteVPadding)
        .background(Color.skippedNoteIcon.opacity(colorScheme == .light ? .lightOpacity : .darkOpacity))
        .cornerRadius(.skippedNoteCorners)
    }
}

/// "First Record:" or "Latest Record:" with its icon and date, "N/A" when there is none.
struct RecordDateDetail: View {
    enum Kind {
        case first
        case latest
    }

    let kind: Kind
    let date: Date?

    var body: some View {
        HStack {
            Image(kind == .first ? .firstRecord : .lastRecord)
                .foregroundStyle(kind == .first ? Color.firstRecordImage : .lastRecordImage)
            VStack(alignment: .leading, spacing: .detailsSpacing) {
                Text(kind == .first ? .firstRecordTitle : .lastRecordTitle)
                    .font(.recordDateTitle)
                    .foregroundStyle(Color.recordDateTitle)
                dateText
                    .font(.recordDate)
                    .fontWeight(.recordDate)
                    .foregroundStyle(Color.recordDate)
            }
        }
    }

    private var dateText: Text {
        if let date {
            Text(date.formatted(date: .abbreviated, time: .omitted))
        } else {
            Text(.sourceCardNotAvailable)
        }
    }
}

// MARK: - Resources
// Shared by both cards, hence `internal` and prefixed so they can't collide with another view's tokens.
extension Color {
    /// A `switch` rather than a dictionary lookup with a fallback: adding a severity then fails to compile
    /// instead of silently rendering as an error colour.
    static func sourceCardSeverity(_ severity: SourceEntry.SyncSeverity) -> Self {
        switch severity {
        case .low: .syncSeverityLow
        case .medium: .syncSeverityMedium
        case .high: .syncSeverityHigh
        case .notSynced: .syncSeverityNone
        }
    }
    static let sourceCardCheckmark: Self = .primaryBlue
}

extension ImageType {
    static let sourceCardCheckmark: Self = .system("checkmark.circle.fill")
}

extension LocalizedStringKey {
    static func sourceCardLastSynced(_ date: Date) -> Self {
        "Last synced: \(date.formatted(date: .abbreviated, time: .shortened))"
    }
    static let sourceCardNotSynced: Self = "Not synced"
    static let sourceCardNotAvailable: Self = "N/A"
}

extension Color {
    fileprivate static var cardShadow: Self { .shadow }
    fileprivate static func cardBorder(isSelected: Bool) -> Self {
        isSelected ? .cardSelectedBorder : .cardIdleBorder
    }
    fileprivate static let cardSelectedBorder: Self = .primaryBlue
    fileprivate static let cardIdleBorder: Self = .clear

    fileprivate static let firstRecordImage: Self = .primaryBlue
    fileprivate static let lastRecordImage: Self = .accentPurple
    fileprivate static let recordDateTitle: Self = .textSecondary
    fileprivate static let recordDate: Self = .textPrimary

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

    fileprivate static let skippedNoteIcon: Self = .warningYellow
    fileprivate static let skippedNoteText: Self = .textPrimary
}

extension Font {
    fileprivate static let recordDateTitle: Self = .caption
    fileprivate static let recordDate: Self = .subheadline
    fileprivate static let skippedNote: Self = .caption
}

extension Font.Weight {
    fileprivate static let recordDate: Self = .medium
}

extension Animation {
    fileprivate static let refreshSpin: Self = .linear(duration: 1).repeatForever(autoreverses: false)
}

extension ImageType {
    fileprivate static let firstRecord: Self = .system("calendar")
    fileprivate static let lastRecord: Self = .system("clock")
    fileprivate static let lastSync: Self = .system("arrow.trianglehead.2.clockwise.rotate.90")
    fileprivate static let refresh: Self = .system("arrow.trianglehead.2.clockwise.rotate.90")
    fileprivate static let skippedWarning: Self = .system("exclamationmark.triangle.fill")
}

extension CGFloat {
    fileprivate static func cardBorderWidth(isSelected: Bool) -> Self {
        isSelected ? .cardSelectedBorderWidth : .cardIdleBorderWidth
    }
    fileprivate static let cardSelectedBorderWidth: Self = 2
    fileprivate static let cardIdleBorderWidth: Self = 0
    fileprivate static let cardCorners: Self = 12
    fileprivate static let cardVPadding: Self = 8
    fileprivate static let cardHPadding: Self = 10

    fileprivate static let shadowRadius: Self = 2
    fileprivate static let shadowXOffset: Self = 0
    fileprivate static let shadowYOffset: Self = 1

    fileprivate static let detailsSpacing: Self = 2

    fileprivate static let syncStatusHPadding: Self = 8
    fileprivate static let syncStatusVPadding: Self = 4
    fileprivate static let syncStatusCorners: Self = 12

    fileprivate static let refreshCorners: Self = 8
    fileprivate static let refreshBorderWidth: Self = 1

    fileprivate static let skippedNoteHPadding: Self = 8
    fileprivate static let skippedNoteVPadding: Self = 4
    fileprivate static let skippedNoteCorners: Self = 8
    fileprivate static let skippedNoteIconSpacing: Self = 4
    fileprivate static let previewSpacing: Self = 12
    fileprivate static let previewRefreshPadding: Self = 8
}

extension Double {
    fileprivate static let lightOpacity: Self = 0.15
    fileprivate static let darkOpacity: Self = 0.35
    fileprivate static let refreshSpinDegrees: Self = 360
}

extension LocalizedStringKey {
    fileprivate static let firstRecordTitle: Self = "First Record:"
    fileprivate static let lastRecordTitle: Self = "Latest Record:"
    /// Grouped per locale ("1,204"), singular for exactly one (spec 005 FR-008, R5).
    fileprivate static func skippedInLastSync(_ count: Int) -> Self {
        count == 1
            ? "\(count.formatted()) record skipped in last sync"
            : "\(count.formatted()) records skipped in last sync"
    }
}

// MARK: - Previews
private struct SourceCardPartsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .previewSpacing) {
            SyncStatusBadge(lastSync: .previewLastSync, severity: .low)
            SyncStatusBadge(lastSync: .previewLastSync, severity: .medium)
            SyncStatusBadge(lastSync: .previewLastSync, severity: .high)
            SyncStatusBadge(lastSync: nil, severity: .notSynced)
            SkippedRecordsNote(count: 3)
            RecordDateDetail(kind: .first, date: .previewLastSync)
            RecordDateDetail(kind: .latest, date: nil)
            HStack {
                RefreshIcon(isRefreshing: false)
                    .padding(.previewRefreshPadding)
                    .modifier(RefreshButtonStyle(isRefreshing: false))
                RefreshIcon(isRefreshing: true)
                    .padding(.previewRefreshPadding)
                    .modifier(RefreshButtonStyle(isRefreshing: true))
            }
        }
        .modifier(SourceCardStyle.sourceCardStyle(isSelected: true))
        .padding()
        .background(.backgroundSecondary)
    }
}

#Preview("Card parts - light") {
    SourceCardPartsPreview()
        .preferredColorScheme(.light)
}

#Preview("Card parts - dark") {
    SourceCardPartsPreview()
        .preferredColorScheme(.dark)
}

extension Date {
    fileprivate static let previewLastSync = Date(timeIntervalSinceNow: -100_000)
}
