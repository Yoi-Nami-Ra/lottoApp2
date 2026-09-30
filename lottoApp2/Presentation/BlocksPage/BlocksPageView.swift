//
//  BlocksPageView.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//
//  The chain list (spec 003 FR-017), per design/final/chain-list.html (LTA-32, completed by LTA-33).
//

import ComposableArchitecture
import SwiftUI

struct BlocksPageView: View {
    @Bindable var store: StoreOf<BlocksPage>

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
            TextField(LocalizedStringKey.renamePlaceholder, text: $store.renameDraft.sending(\.renameDraftChanged))
            Button(LocalizedStringKey.renameConfirm) { store.send(.renameConfirmed) }
            Button(LocalizedStringKey.cancel, role: .cancel) { store.send(.renameCancelled) }
        }
    }

    /// Shown while the reducer has a rename in progress. Both buttons end it through an action, so the
    /// alert's own dismissal has nothing left to report.
    private var isRenaming: Binding<Bool> {
        Binding(get: { store.renaming != nil }, set: { _ in })
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
                    .swipeActions(edge: .leading) {
                        Button { store.send(.renameTapped(chain.id)) } label: {
                            Label(LocalizedStringKey.rename, systemImage: .renameIcon)
                        }
                        .tint(Color.renameTint)
                    }
                    .contextMenu {
                        Button { store.send(.renameTapped(chain.id)) } label: {
                            Label(LocalizedStringKey.rename, systemImage: .renameIcon)
                        }
                        Button(role: .destructive) { store.send(.deleteChainTapped(chain.id)) } label: {
                            Label(LocalizedStringKey.delete, systemImage: .deleteIcon)
                        }
                    }
                    // Neither action depends on knowing the swipes (FR-019).
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(.chainReading(name: chain.name, blocks: chain.nodes.count)))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { store.send(.chainTapped(chain.id)) }
                    .accessibilityAction(named: Text(.rename)) { store.send(.renameTapped(chain.id)) }
                    .accessibilityAction(named: Text(.delete)) { store.send(.deleteChainTapped(chain.id)) }
            }
            if store.showsEmptyState {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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

    /// Before the first chain: what a chain is, above the New chain row (FR-016).
    private var emptyState: some View {
        VStack(spacing: .emptySpacing) {
            Image(.blockIcon)
                .font(.emptyIcon)
                .foregroundStyle(Color.emptyIcon)
            Text(.emptyTitle)
                .font(.emptyTitle)
                .foregroundStyle(Color.emptyText)
            Text(.emptyMessage)
                .font(.emptyMessage)
                .foregroundStyle(Color.emptyText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .emptyVPadding)
        .padding(.horizontal, .emptyHPadding)
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
    fileprivate static let renameTint: Self = .primaryBlue
    fileprivate static let emptyIcon: Self = .textTertiary
    fileprivate static let emptyText: Self = .textSecondary
}

extension Font {
    fileprivate static let headerCaption: Self = .caption
    fileprivate static let headerName: Self = .title2
    fileprivate static let blockIcon: Self = .title3
    fileprivate static let blockLabel: Self = .body
    fileprivate static let emptyIcon: Self = .largeTitle
    fileprivate static let emptyTitle: Self = .headline
    fileprivate static let emptyMessage: Self = .footnote
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
    fileprivate static let emptySpacing: Self = 6
    fileprivate static let emptyVPadding: Self = 24
    fileprivate static let emptyHPadding: Self = 8
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
    fileprivate static let emptyTitle: Self = "No chains yet"
    fileprivate static let emptyMessage: Self =
        "A chain is a set of blocks that counts and sorts a source's draws. Tap New chain to build your first one."

    /// A chain row as VoiceOver reads it: "<name>, <N> blocks".
    fileprivate static func chainReading(name: String, blocks count: Int) -> Self {
        count == 1 ? "\(name), 1 block" : "\(name), \(count.formatted()) blocks"
    }

    fileprivate static func blockCount(_ count: Int) -> Self {
        count == 1 ? "1 block" : "\(count.formatted()) blocks"
    }
}

#Preview("Blocks page - empty chain list - light") {
    NavigationStack {
        BlocksPageView(store: .preview(sourceName: .previewName))
    }
    .preferredColorScheme(.light)
}

#Preview("Blocks page - empty chain list - dark") {
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
