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

    let store: StoreOf<SourceEntry>

    var body: some View {
        VStack(alignment: .leading, spacing: .headerDataSpacing) {
            headerRow
            details
        }
        .modifier(SourceCardStyle.sourceCardStyle)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: .headerVSpacing) {
                SourceTitle(title: store.name)

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
        .syncSeverityForeground[store.lastSyncSeverity] ?? .syncSeverityHigh
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
            Button {
                store.send(.refresh)
            } label: {
                HStack {
                    Image(.refresh)
                        .font(.caption)
                        .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                        .animation(
                            store.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: store.isRefreshing
                        )
                    Text("Refresh")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(store.isRefreshing ? .secondary : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(store.isRefreshing ? .gray : Color.blue.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(store.isRefreshing ? .gray : Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
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

// MARK : - Styles
struct SourceCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.backgroundPrimary)
            .cornerRadius(.cardCorners)
            .shadow(color: .cardShadow, radius: .shadowRadius, x: .shadowXOffset, y: .shadowYOffset)
    }
}

extension ViewModifier where Self == SourceCardStyle {
    static var sourceCardStyle: SourceCardStyle { .init() }
}

// MARK: - Resources
extension Color {
    fileprivate static var cardShadow: Self { .shadow }
    fileprivate static var syncSeverityForeground: [SourceEntry.SyncSeverity: Self] {
        [
            .low: .syncSeverityLow,
            .medium: .syncSeverityMedium,
            .high: .syncSeverityHigh,
            .none: .syncSeverityNone,
        ]
    }
    fileprivate static let firstRecordImage: Self = .primaryBlue
    fileprivate static let firstlastRecordTitle: Self = .textSecondary
    fileprivate static let firstlastRecordDate: Self = .textPrimary

    fileprivate static let lastRecordImage: Self = .accentPurple
    fileprivate static let sourceTitle: Self = .textPrimary

    fileprivate static let syncSeverityLow: Self = .successGreen
    fileprivate static let syncSeverityMedium: Self = .warningYellow
    fileprivate static let syncSeverityHigh: Self = .errorRed
    fileprivate static let syncSeverityNone: Self = .undefinedGrey
}

extension Font {
    fileprivate static let firstlastRecordTitle: Self = .caption
    fileprivate static let firstlastRecordDate: Self = .subheadline
}

extension Font.Weight {
    fileprivate static let firstlastRecordDate: Self = .medium
}

extension ImageType {
    fileprivate static let firstRecord: Self = .system("calendar")
    fileprivate static let records: Self = .system("square.3.layers.3d")
    fileprivate static let lastRecord: Self = .system("clock")
    fileprivate static let lastSync: Self = .system("arrow.trianglehead.2.clockwise.rotate.90")
    fileprivate static let refresh: Self = .system("arrow.trianglehead.2.clockwise.rotate.90")
}

extension CGFloat {
    fileprivate static let headerDataSpacing: Self = 16
    fileprivate static let cardCorners: Self = 12

    fileprivate static let shadowRadius: Self = 2
    fileprivate static let shadowXOffset: Self = 0
    fileprivate static let shadowYOffset: Self = 1

    fileprivate static let detailsSpacing: Self = 2
    fileprivate static let headerVSpacing: Self = 4

    fileprivate static let syncStatusHPadding: Self = 8
    fileprivate static let syncStatusVPadding: Self = 4
    fileprivate static let syncStatusCorners: Self = 12

    fileprivate static let buttonCorners: Self = 15
}

extension Double {
    fileprivate static let lightOpacity: Self = 0.15
    fileprivate static let darkOpacity: Self = 0.35
}

extension LocalizedStringKey {
    fileprivate static let firstRecordTitle: Self = "First Record:"
    fileprivate static let lastRecordTitle: Self = "Latest Record:"
    fileprivate static func lastSynced(_ date: Date) -> Self { "Last synced: \(date.formatted(date: .abbreviated, time: .shortened))" }
    fileprivate static let notSynced: Self = "Not synced"
    fileprivate static let records: Self = "records"
    fileprivate static let notAvailable: Self = "N/A"
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

extension SourceEntry.State {
    static let mock1n: Self = .init(
        id: "mbtn",
        name: "MBTN Server",
        lastSync: Date(timeIntervalSinceNow: -100000),
        firstRecordDate: Date(timeIntervalSinceNow: -180000),
        lastRecordDate: Date(timeIntervalSince1970: 18223210),
        recordsCount: 15_847
    )

    static let mock1m: Self = .init(
        id: "mbtn",
        name: "MBTN Server",
        lastSync: Date(timeIntervalSinceNow: -100000),
        firstRecordDate: Date(timeIntervalSinceNow: -180000),
        lastRecordDate: Date(timeIntervalSince1970: 18223210),
        recordsCount: 15_847
    )

    static let mock1s: Self = .init(
        id: "mbtn",
        name: "MBTN Server",
        lastSync: Date(timeIntervalSinceNow: -100000),
        firstRecordDate: Date(timeIntervalSinceNow: -180000),
        lastRecordDate: Date(timeIntervalSince1970: 18223210),
        recordsCount: 15_847
    )

    static let mock1e: Self = .init(
        id: "mbtn",
        name: "MBTN Server",
        lastSync: nil,
        firstRecordDate: nil,
        lastRecordDate: nil,
        recordsCount: nil
    )
}

extension Int {
    var toString: String { String(self) }
}
