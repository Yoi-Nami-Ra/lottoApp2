//
//  BlocksPageView.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//
//  The chain list (spec 003 FR-017). LTA-32 (its design) is still in refine with no proposal file, so it
//  keeps this page's existing header and row language.
//

import ComposableArchitecture
import SwiftUI

struct BlocksPageView: View {
    @Bindable var store: StoreOf<BlocksPage>

    /// The chain being renamed and its draft name. Transient text entry, not feature state: the reducer only
    /// hears the confirmed name through `renameChain`.
    @State private var renaming: Chain?
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: .headerListSpacing) {
            header
            chainList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.pageBackground)
        .navigationTitle(LocalizedStringKey.blocksPageTitle)
        // Only iOS has a navigation bar title display mode; the Mac destination builds the same view.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { store.send(.onAppear) }
        .navigationDestination(item: $store.scope(state: \.editor, action: \.editor)) { editor in
            ChainEditorView(store: editor)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .alert(LocalizedStringKey.renameTitle, isPresented: isRenaming) {
            TextField(LocalizedStringKey.renamePlaceholder, text: $draftName)
            Button(LocalizedStringKey.renameConfirm) {
                if let renaming { store.send(.renameChain(renaming.id, draftName)) }
            }
            Button(LocalizedStringKey.cancel, role: .cancel) {}
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
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

    private var chainList: some View {
        List {
            ForEach(store.chains) { chain in
                chainRow(chain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.blockRow)
                    .swipeActions {
                        Button(role: .destructive) { store.send(.deleteChainTapped(chain.id)) } label: {
                            Label(LocalizedStringKey.delete, systemImage: .deleteIcon)
                        }
                    }
                    .contextMenu {
                        Button {
                            draftName = chain.name
                            renaming = chain
                        } label: {
                            Label(LocalizedStringKey.rename, systemImage: .renameIcon)
                        }
                    }
            }
            newChainRow
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(.blockRow)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func chainRow(_ chain: Chain) -> some View {
        Button { store.send(.chainTapped(chain.id)) } label: {
            HStack(spacing: .rowSpacing) {
                Image(.blockIcon)
                    .font(.blockIcon)
                    .foregroundStyle(Color.blockIcon)
                VStack(alignment: .leading, spacing: .headerVSpacing) {
                    Text(chain.name)
                        .font(.blockLabel)
                        .fontWeight(.blockLabel)
                        .foregroundStyle(Color.blockLabel)
                    Text(.blockCount(chain.nodes.count))
                        .font(.headerCaption)
                        .foregroundStyle(Color.headerCaption)
                }
                Spacer()
                Image(.chevron)
                    .foregroundStyle(Color.headerCaption)
            }
            .padding(.vertical, .rowVPadding)
            .padding(.horizontal, .rowHPadding)
            .background(.backgroundPrimary)
            .cornerRadius(.rowCorners)
        }
        .buttonStyle(.plain)
    }

    private var newChainRow: some View {
        Button { store.send(.newChainTapped) } label: {
            HStack(spacing: .rowSpacing) {
                Image(.newChainIcon)
                    .font(.blockIcon)
                Text(.newChain)
                    .font(.blockLabel)
                    .fontWeight(.blockLabel)
                Spacer()
            }
            .foregroundStyle(Color.blockIcon)
            .padding(.vertical, .rowVPadding)
            .padding(.horizontal, .rowHPadding)
            .background(.backgroundPrimary)
            .cornerRadius(.rowCorners)
        }
        .buttonStyle(.plain)
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
    fileprivate static let newChainIcon: Self = .system("plus.circle")
    fileprivate static let chevron: Self = .system("chevron.right")
}

extension String {
    fileprivate static let deleteIcon = "trash"
    fileprivate static let renameIcon = "pencil"
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
    /// The source name shrinks rather than truncating, down to this fraction of its size.
    fileprivate static let headerNameScale: Self = 0.6
}

extension Int {
    fileprivate static let headerNameLines: Self = 3
}

extension LocalizedStringKey {
    fileprivate static let blocksPageTitle: Self = "Processing Blocks"
    fileprivate static let headerCaption: Self = "Source"
    fileprivate static let newChain: Self = "New chain"
    fileprivate static let delete: Self = "Delete"
    fileprivate static let rename: Self = "Rename"
    fileprivate static let renameTitle: Self = "Rename chain"
    fileprivate static let renamePlaceholder: Self = "Name"
    fileprivate static let renameConfirm: Self = "Save"
    fileprivate static let cancel: Self = "Cancel"

    fileprivate static func blockCount(_ count: Int) -> Self {
        count == 1 ? "1 block" : "\(count.formatted()) blocks"
    }
}

#Preview("Blocks page - no chains - light") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewName))
    }
    .preferredColorScheme(.light)
}

#Preview("Blocks page - no chains - dark") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewName))
    }
    .preferredColorScheme(.dark)
}

#Preview("Blocks page - chains - light") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewName, chains: [.previewCountOnly, .previewEmpty]))
    }
    .preferredColorScheme(.light)
}

#Preview("Blocks page - chains - dark") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewName, chains: [.previewCountOnly, .previewEmpty]))
    }
    .preferredColorScheme(.dark)
}

#Preview("Blocks page - long source name - light") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewLongName))
    }
    .preferredColorScheme(.light)
}

extension StoreOf<BlocksPage> {
    fileprivate static func preview(sourceName: String, chains: [Chain] = []) -> StoreOf<BlocksPage> {
        Store(initialState: BlocksPage.State(sourceID: "mbnet", sourceName: sourceName)) {
            BlocksPage()
        } withDependencies: {
            $0.chainsRepo = .inMemory(seed: chains)
        }
    }
}

extension String {
    fileprivate static let previewName = "MBNet Server"
    fileprivate static let previewLongName = "EuroJackpot International Historical Server"
}
