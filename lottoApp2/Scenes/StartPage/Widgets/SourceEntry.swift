//
//  SourceEntry.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 18/07/2025.
//

import ComposableArchitecture
import Dependencies
import SwiftUI

struct SourceEntry: View {
    struct DisplayData: Equatable {
        let name: String
        let lastSync: String
        let lastSyncSeverity: SyncSeverity
        let firstRecordDate: String
        let lastRecordDate: String
        let recordsCount: String
    }

    enum SyncSeverity {
        case low
        case medium
        case high
    }

    let data: DisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: .headerDataSpacing) {
            headerRow
            details
        }
        .padding(8)
        .background(.background)
        .cornerRadius(.cardCorners)
        .shadow(color: .shadow, radius: .shadowRadius, x: .shadowXOffset, y: .shadowYOffset)
    }

    private var details: some View {
        VStack {
            HStack {
                Image(.firstRecord)
                    .foregroundStyle(Color.firstRecordImage)
                VStack(alignment: .leading, spacing: .detailsSpacing) {
                    Text(.firstRecordTitle)
                        .font(.firstlastRecordTitle)
                        .foregroundStyle(Color.firstlastRecordTitle)
                    Text(data.firstRecordDate)
                        .font(.firstlastRecordDate)
                        .fontWeight(.firstlastRecordDate)
                        .foregroundStyle(Color.firstlastRecordDate)
                }
            }
            HStack {
                Image(.lastRecord)
                    .foregroundStyle(Color.lastRecordImage)
                VStack(alignment: .leading, spacing: .detailsSpacing) {
                    Text(.lastRecord)
                        .font(.firstlastRecordTitle)
                        .foregroundStyle(Color.firstlastRecordTitle)
                    Text(data.lastRecordDate)
                        .font(.firstlastRecordDate)
                        .fontWeight(.firstlastRecordDate)
                        .foregroundStyle(Color.firstlastRecordDate)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: .headerVSpacing) {
                Text(data.name)
                    .font(.sourceTitle)
                    .fontWeight(.sourceTitle)
                    .foregroundStyle(Color.sourceTitle)
                syncStatusBadge
            }

            Spacer()

            VStack(alignment: .trailing) {
                HStack(spacing: .headerVSpacing) {
                    Image(.records)
                        .foregroundStyle(.primary)
                    Text(data.recordsCount)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                Text(.records)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var syncStatusBadge: some View {
        HStack {
            Image(.lastSync)
            Text(.lastSynced(data.lastSync))
                .font(.caption)
        }
        .foregroundStyle(lastSyncForeground)
        .padding(.horizontal, .syncStatusHPadding)
        .padding(.vertical, .syncStatusVPadding)
        .background(lastSyncBackground)
        .cornerRadius(.syncStatusCorners)
    }

    private var lastSyncForeground: Color {
        .syncSeverityForeground[data.lastSyncSeverity] ?? .syncSeverityHigh
    }

    private var lastSyncBackground: Color {
        .syncSeverityBackground[data.lastSyncSeverity] ?? .syncSeverityHigh
    }
}

extension Color {
    fileprivate static let shadow: Self = .black.opacity(0.05)
    fileprivate static let syncSeverityForeground: [SourceEntry.SyncSeverity: Self] = [
        .low: .syncSeverityLow,
        .medium: .syncSeverityMedium,
        .high: .syncSeverityHigh
    ]
    fileprivate static let syncSeverityBackground: [SourceEntry.SyncSeverity: Self] = [
        .low: .syncSeverityLow.opacity(0.1),
        .medium: .syncSeverityMedium.opacity(0.1),
        .high: .syncSeverityHigh.opacity(0.1)
    ]
    fileprivate static let firstRecordImage: Self = .blue
    fileprivate static let firstlastRecordTitle: Self = .secondary
    fileprivate static let firstlastRecordDate: Self = .primary

    fileprivate static let lastRecordImage: Self = .purple
    fileprivate static let sourceTitle: Self = .primary

    fileprivate static let syncSeverityLow: Self = .green
    fileprivate static let syncSeverityMedium: Self = .yellow
    fileprivate static let syncSeverityHigh: Self = .red
}

extension Font {
    fileprivate static let firstlastRecordTitle: Self = .caption
    fileprivate static let firstlastRecordDate: Self = .subheadline
    fileprivate static let sourceTitle: Self = .title
}

extension Font.Weight {
    fileprivate static let firstlastRecordDate: Self = .medium
    fileprivate static let sourceTitle: Self = .semibold
}

extension ImageType {
    fileprivate static let firstRecord: Self = .system("calendar")
    fileprivate static let records: Self = .system("square.3.layers.3d")
    fileprivate static let lastRecord: Self = .system("clock")
    fileprivate static let lastSync: Self = .system("arrow.trianglehead.2.clockwise.rotate.90")
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
}

extension LocalizedStringKey {
    fileprivate static let firstRecordTitle: Self = "First Record:"
    fileprivate static let lastRecord: Self = "Latest Record:"
    fileprivate static func lastSynced(_ date: String) -> Self { "Last synced: \(date)" }
    fileprivate static let records: Self = "records"
}

#Preview("Dark Mode") {
    List {
        SourceEntry(data: .mock1n)
            .padding()
            .preferredColorScheme(.dark)
        SourceEntry(data: .mock1m)
            .padding()
            .preferredColorScheme(.dark)
        SourceEntry(data: .mock1s)
            .padding()
            .preferredColorScheme(.dark)
    }
}

#Preview("Light Mode - none") {
    SourceEntry(data: .mock1n)
        .padding()
        .preferredColorScheme(.light)
    SourceEntry(data: .mock1m)
        .padding()
        .preferredColorScheme(.light)
    SourceEntry(data: .mock1s)
        .padding()
        .preferredColorScheme(.light)
}

extension SourceEntry.DisplayData {
    static let mock1n: Self = .init(
        name: "MBTN Server",
        lastSync: "Jul 19, 2024, 10:15 AM",
        lastSyncSeverity: .low,
        firstRecordDate: "Mar 15, 2020",
        lastRecordDate: "Jul 18, 2024",
        recordsCount: "15,847"
    )

    static let mock1m: Self = .init(
        name: "MBTN Server",
        lastSync: "Jul 19, 2024, 10:15 AM",
        lastSyncSeverity: .medium,
        firstRecordDate: "Mar 15, 2020",
        lastRecordDate: "Jul 18, 2024",
        recordsCount: "15,847"
    )

    static let mock1s: Self = .init(
        name: "MBTN Server",
        lastSync: "Jul 19, 2024, 10:15 AM",
        lastSyncSeverity: .high,
        firstRecordDate: "Mar 15, 2020",
        lastRecordDate: "Jul 18, 2024",
        recordsCount: "15,847"
    )
}
