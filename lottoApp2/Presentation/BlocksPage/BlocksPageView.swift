//
//  BlocksPageView.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//

import ComposableArchitecture
import SwiftUI

struct BlocksPageView: View {
    let store: StoreOf<BlocksPage>

    var body: some View {
        VStack(alignment: .leading, spacing: .headerListSpacing) {
            header
            blockList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.pageBackground)
        .navigationTitle(LocalizedStringKey.blocksPageTitle)
        // Only iOS has a navigation bar title display mode; the Mac destination builds the same view.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The name only — record counts and sync status stay on the screen the person just left, so nothing
    /// here needs refreshing while the page is open (FR-024).
    private var header: some View {
        VStack(alignment: .leading, spacing: .headerVSpacing) {
            Text(.headerCaption)
                .font(.headerCaption)
                .foregroundStyle(Color.headerCaption)
            Text(store.sourceName)
                .font(.headerName)
                .fontWeight(.headerName)
                .foregroundStyle(Color.headerName)
                .lineLimit(.headerNameLines)
                .minimumScaleFactor(.headerNameScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .contentHPadding)
        .padding(.top, .headerTopPadding)
    }

    private var blockList: some View {
        List {
            ForEach(store.blocks, id: \.self) { kind in
                row(for: kind)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.blockRow)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(for kind: ProcessingBlockKind) -> some View {
        HStack(spacing: .rowSpacing) {
            Image(.blockIcon)
                .font(.blockIcon)
                .foregroundStyle(Color.blockIcon)
            Text(.blockLabel(kind))
                .font(.blockLabel)
                .fontWeight(.blockLabel)
                .foregroundStyle(Color.blockLabel)
            Spacer()
        }
        .padding(.vertical, .rowVPadding)
        .padding(.horizontal, .rowHPadding)
        .background(.backgroundPrimary)
        .cornerRadius(.rowCorners)
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let pageBackground: Self = .backgroundSecondary
    fileprivate static let headerCaption: Self = .textSecondary
    fileprivate static let headerName: Self = .textPrimary
    fileprivate static let blockIcon: Self = .primaryBlue
    fileprivate static let blockLabel: Self = .textPrimary
}

extension Font {
    fileprivate static let headerCaption: Self = .caption
    fileprivate static let headerName: Self = .title2
    fileprivate static let blockIcon: Self = .title3
    fileprivate static let blockLabel: Self = .body
}

extension Font.Weight {
    fileprivate static let headerName: Self = .semibold
    fileprivate static let blockLabel: Self = .medium
}

extension ImageType {
    fileprivate static let blockIcon: Self = .system("function")
}

extension EdgeInsets {
    fileprivate static let blockRow = EdgeInsets(
        top: .rowVInset, leading: .contentHPadding, bottom: .rowVInset, trailing: .contentHPadding
    )
}

extension CGFloat {
    fileprivate static let headerListSpacing: Self = 16
    fileprivate static let headerVSpacing: Self = 4
    fileprivate static let headerTopPadding: Self = 16
    fileprivate static let contentHPadding: Self = 16
    fileprivate static let rowSpacing: Self = 12
    fileprivate static let rowVPadding: Self = 14
    fileprivate static let rowHPadding: Self = 14
    fileprivate static let rowCorners: Self = 12
    fileprivate static let rowVInset: Self = 6
    /// Low enough that a long name still fits within `headerNameLines` at the largest accessibility
    /// text size, where `.title2` roughly doubles and two lines at 0.8 would truncate.
    fileprivate static let headerNameScale: Self = 0.6
}

extension Int {
    fileprivate static let headerNameLines: Self = 3
}

extension LocalizedStringKey {
    fileprivate static let blocksPageTitle: Self = "Processing Blocks"
    fileprivate static let headerCaption: Self = "Source"

    /// An exhaustive `switch` rather than a dictionary lookup with a fallback: adding a block then fails
    /// to compile instead of silently rendering as a blank row.
    fileprivate static func blockLabel(_ kind: ProcessingBlockKind) -> Self {
        switch kind {
        case .countUniqueElements: .countUniqueElements
        }
    }

    fileprivate static let countUniqueElements: Self = "Count Unique Elements"
}

#Preview("Blocks page - light") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewName))
    }
    .preferredColorScheme(.light)
}

#Preview("Blocks page - dark") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewName))
    }
    .preferredColorScheme(.dark)
}

#Preview("Blocks page - long source name - light") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewLongName))
    }
    .preferredColorScheme(.light)
}

#Preview("Blocks page - long source name - dark") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewLongName))
    }
    .preferredColorScheme(.dark)
}

extension StoreOf<BlocksPage> {
    fileprivate static func preview(sourceName: String) -> StoreOf<BlocksPage> {
        Store(initialState: BlocksPage.State(sourceID: "mbnet", sourceName: sourceName)) {
            BlocksPage()
        }
    }
}

extension String {
    fileprivate static let previewName = "MBNet Server"
    fileprivate static let previewLongName = "EuroJackpot International Historical Server"
}
