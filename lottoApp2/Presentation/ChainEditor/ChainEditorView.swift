//
//  ChainEditorView.swift
//  lottoApp2
//
//  The chain outline, per design/final/chain-builder.html (LTA-21, with LTA-33's accessibility pass).
//  Renders `ChainEditor.State` and sends actions — every decision is in the reducer.
//

import ComposableArchitecture
import SwiftUI

struct ChainEditorView: View {
    @Bindable var store: StoreOf<ChainEditor>
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At accessibility sizes a row's summary wraps under its title and nesting takes less width (FR-015).
    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }
    private var indentPerLevel: CGFloat { isAccessibilitySize ? .indentPerLevelAccessible : .indentPerLevel }

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if store.hasOutdatedResults {
                Section {
                    Label(LocalizedStringKey.staleBanner, systemImage: .staleIcon)
                        .font(.rowDetail)
                        .foregroundStyle(Color.primaryText)
                }
                .listRowBackground(Color.staleBackground)
            }

            Section {
                inputRow
                ForEach(store.outline) { row in
                    nodeRow(row)
                        .swipeActions {
                            Button(role: .destructive) { store.send(.removeTapped(row.id)) } label: {
                                Label(LocalizedStringKey.remove, systemImage: .removeIcon)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if canSave(row.id) {
                                Button { store.send(.saveResultTapped(row.id)) } label: {
                                    Label(LocalizedStringKey.saveResult, systemImage: .saveIcon)
                                }
                                .tint(Color.icon)
                            }
                        }
                        .contextMenu {
                            if canSave(row.id) {
                                Button { store.send(.saveResultTapped(row.id)) } label: {
                                    Label(LocalizedStringKey.saveResult, systemImage: .saveIcon)
                                }
                            }
                            if store.state.isEditable(row.id) {
                                Button { store.send(.editTapped(row.id)) } label: {
                                    Label(LocalizedStringKey.edit, systemImage: .editIcon)
                                }
                            }
                            Button(role: .destructive) { store.send(.removeTapped(row.id)) } label: {
                                Label(LocalizedStringKey.remove, systemImage: .removeIcon)
                            }
                        }
                }
            }

            if store.chain.nodes.isEmpty {
                Section { emptyState }
                    .listRowBackground(Color.clear)
            }

            if !store.savedResults.isEmpty {
                Section(LocalizedStringKey.savedHeader) {
                    ForEach(store.savedResults) { saved in
                        savedRow(saved)
                            .swipeActions {
                                Button(role: .destructive) { store.send(.deleteSavedResultTapped(saved.id)) } label: {
                                    Label(LocalizedStringKey.delete, systemImage: .removeIcon)
                                }
                            }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { runBar }
        .navigationTitle(store.chain.name)
        // The system back button can't ask first, so the editor owns the way out (FR-032, R11). Hiding it
        // also disables swipe-back.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { store.send(.backTapped) } label: {
                    Label(LocalizedStringKey.back, systemImage: .backIcon)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in store.send(.scenePhaseChanged(phase)) }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { store.send(.onAppear) }
        .sheet(item: $store.scope(state: \.addBlock, action: \.addBlock)) { addBlock in
            AddBlockView(store: addBlock)
        }
        .sheet(item: $store.scope(state: \.editBlock, action: \.editBlock)) { editBlock in
            NavigationStack { BlockParametersView(store: editBlock) }
                #if os(macOS)
                // Same as the add-block sheet: a macOS sheet would collapse around the List.
                .frame(minWidth: .sheetMinWidth, minHeight: .sheetMinHeight)
                #endif
        }
        .navigationDestination(item: $store.scope(state: \.result, action: \.result)) { result in
            ResultPageView(store: result)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .headerVSpacing) {
            Text(.sourceCaption)
                .font(.sourceCaption)
                .foregroundStyle(Color.secondaryText)
            Text(store.source.name)
                .font(.headerName)
                .foregroundStyle(Color.primaryText)
        }
        .listRowInsets(.headerInsets)
    }

    /// The chain's input: always first, never removed.
    private var inputRow: some View {
        HStack(spacing: .rowSpacing) {
            HStack(spacing: .rowSpacing) {
                Image(.chainInput)
                    .foregroundStyle(Color.icon)
                VStack(alignment: .leading, spacing: .rowVSpacing) {
                    Text(store.source.name)
                        .foregroundStyle(Color.primaryText)
                    if let count = store.sourceRecordsCount {
                        Text(.summary(.draws(count: count)))
                            .font(.rowDetail)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(.sourceRowReading(name: store.source.name, count: store.sourceRecordsCount)))
            Spacer()
            addButton(parent: nil)
        }
    }

    private func nodeRow(_ row: ChainEditor.OutlineRow) -> some View {
        HStack(spacing: .rowSpacing) {
            disclosure(row)
            Button { store.send(.nodeTapped(row.id)) } label: {
                HStack(alignment: isAccessibilitySize ? .top : .center, spacing: .rowSpacing) {
                    Image(.block)
                        .foregroundStyle(Color.icon)
                    titleAndStatusLayout {
                        VStack(alignment: .leading, spacing: .rowVSpacing) {
                            Text(.blockTitle(row.node.block.kind))
                                .foregroundStyle(Color.primaryText)
                            detail(row)
                        }
                        if !isAccessibilitySize { Spacer() }
                        HStack(spacing: .rowSpacing) {
                            if store.savedNodeIDs.contains(row.id) {
                                Image(.saved)
                                    .font(.rowDetail)
                                    .foregroundStyle(Color.icon)
                            }
                            status(row.id)
                        }
                    }
                    if isAccessibilitySize { Spacer(minLength: 0) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(reading(row))
            addButton(parent: row.id)
        }
        .padding(.leading, CGFloat(row.depth - 1) * indentPerLevel)
        .overlay(alignment: .leading) {
            // Guide lines back to each ancestor level (LTA-21).
            HStack(spacing: .guideSpacing) {
                ForEach(0..<(row.depth - 1), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.guide)
                        .frame(width: .guideWidth)
                        .frame(maxWidth: indentPerLevel, alignment: .leading)
                }
            }
        }
    }

    /// Title and status side by side, or stacked at accessibility sizes (FR-015).
    private var titleAndStatusLayout: AnyLayout {
        isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: .rowVSpacing))
            : AnyLayout(HStackLayout(spacing: .rowSpacing))
    }

    /// One spoken sentence per row: "<block>, <parameter>, level <n>, <summary or state>" (FR-014).
    private func reading(_ row: ChainEditor.OutlineRow) -> Text {
        var parts = [Text(.blockTitle(row.node.block.kind))]
        if let parameters = LocalizedStringKey.blockParameters(row.node.block) { parts.append(Text(parameters)) }
        let hidden = store.state.hiddenCount(row.id)
        if hidden > 0 { parts.append(Text(.hiddenBlocks(hidden))) }
        parts.append(Text(.levelReading(row.depth)))
        switch store.state.rowStatus(row.id) {
        case .running:
            parts.append(Text(.runningReading))
        case let .value(summary, isStale):
            parts.append(Text(.summary(summary)))
            if isStale { parts.append(Text(.outOfDate)) }
        case .failed(let failure):
            parts.append(Text(.failure(failure)))
        case .notRun:
            parts.append(Text(.notRun))
        }
        if store.savedNodeIDs.contains(row.id) { parts.append(Text(.savedReading)) }
        return .reading(parts)
    }

    /// A node with a value that hasn't been saved since the last run (FR-027).
    private func canSave(_ nodeID: ChainNode.ID) -> Bool {
        guard case .value = store.results[nodeID] else { return false }
        return !store.savedNodeIDs.contains(nodeID)
    }

    /// A saved result: the blocks that produced it, its source and when, and whether it is still current.
    private func savedRow(_ saved: SavedResult) -> some View {
        Button { store.send(.savedResultTapped(saved.id)) } label: {
            HStack(spacing: .rowSpacing) {
                Image(.saved)
                    .foregroundStyle(Color.icon)
                VStack(alignment: .leading, spacing: .rowVSpacing) {
                    Text(.path(saved.path))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(.pathLines)
                    Text(.savedDetail(saved))
                        .font(.rowDetail)
                        .foregroundStyle(Color.secondaryText)
                    if let status = LocalizedStringKey.savedStatus(
                        saved.freshness(dataStates: store.dataStates), chainChanged: saved.chainChanged(since: store.chain)
                    ) {
                        Text(status)
                            .font(.badge)
                            .padding(.horizontal, .badgeHPadding)
                            .background(Color.staleBackground)
                            .cornerRadius(.badgeCorners)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                Spacer()
                Image(.chevron)
                    .font(.rowDetail)
                    .foregroundStyle(Color.tertiaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The fold chevron for a node with children; an equal-width gap otherwise, so rows stay aligned.
    @ViewBuilder
    private func disclosure(_ row: ChainEditor.OutlineRow) -> some View {
        if row.hasChildren {
            Button { store.send(.toggleCollapsed(row.id)) } label: {
                Image(.disclosure)
                    .font(.disclosure)
                    .rotationEffect(store.collapsed.contains(row.id) ? .zero : .expanded)
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: .disclosureWidth)
            }
            .buttonStyle(.borderless)
        } else {
            Color.clear.frame(width: .disclosureWidth)
        }
    }

    /// Parameters, plus how many blocks a folded node hides.
    @ViewBuilder
    private func detail(_ row: ChainEditor.OutlineRow) -> some View {
        let parameters = LocalizedStringKey.blockParameters(row.node.block)
        let hidden = store.state.hiddenCount(row.id)
        if parameters != nil || hidden > 0 {
            HStack(spacing: .chevronSpacing) {
                if let parameters { Text(parameters) }
                if hidden > 0 { Text(.hiddenBlocks(hidden)) }
            }
            .font(.rowDetail)
            .foregroundStyle(Color.secondaryText)
        }
    }

    @ViewBuilder
    private func status(_ nodeID: ChainNode.ID) -> some View {
        switch store.state.rowStatus(nodeID) {
        case .running:
            ProgressView()
        case let .value(summary, isStale):
            VStack(alignment: .trailing, spacing: .rowVSpacing) {
                HStack(spacing: .chevronSpacing) {
                    Text(.summary(summary))
                        .strikethrough(isStale)
                    Image(.chevron)
                }
                if isStale {
                    Text(.outOfDate)
                        .font(.badge)
                        .padding(.horizontal, .badgeHPadding)
                        .background(Color.staleBackground)
                        .cornerRadius(.badgeCorners)
                }
            }
            .font(.rowDetail)
            .foregroundStyle(Color.secondaryText)
        case .failed(let failure):
            Text(.failure(failure))
                .font(.rowDetail)
                .foregroundStyle(Color.failure)
                .multilineTextAlignment(isAccessibilitySize ? .leading : .trailing)
        case .notRun:
            Text(.notRun)
                .font(.rowDetail)
                .foregroundStyle(Color.tertiaryText)
        }
    }

    /// "+" under any node that can take a child; a count-all row (a single number) gets none (FR-012).
    @ViewBuilder
    private func addButton(parent: ChainNode.ID?) -> some View {
        if store.state.canAdd(under: parent) {
            Button { store.send(.addTapped(parent: parent)) } label: {
                Image(.add)
                    .font(.addButton)
                    .foregroundStyle(Color.icon)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(addLabel(parent: parent)))
        }
    }

    /// "Add block under <block>", or under the source's name (FR-013).
    private func addLabel(parent: ChainNode.ID?) -> LocalizedStringKey {
        guard let parent, let node = store.chain.nodes[id: parent] else {
            return .addBlockUnder(sourceName: store.source.name)
        }
        return .addBlockUnder(node.block.kind)
    }

    private var emptyState: some View {
        VStack(spacing: .emptySpacing) {
            Image(.block)
                .font(.emptyIcon)
                .foregroundStyle(Color.tertiaryText)
            Text(.emptyTitle)
                .font(.emptyTitle)
                .foregroundStyle(Color.secondaryText)
            Text(.emptyMessage)
                .font(.rowDetail)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .emptyVPadding)
    }

    private var runBar: some View {
        Button { store.send(.runTapped) } label: {
            HStack(spacing: .rowSpacing) {
                if store.isRunning { ProgressView() }
                Text(store.isRunning ? LocalizedStringKey.running : .run)
            }
            .font(.runLabel)
            .foregroundStyle(Color.runForeground(isEnabled: store.canRun))
            .frame(maxWidth: .infinity)
            .padding(.vertical, .runVPadding)
            .background(Color.runBackground(isEnabled: store.canRun))
            .cornerRadius(.runCorners)
        }
        .buttonStyle(.plain)
        .disabled(!store.canRun)
        .padding(.horizontal, .barHPadding)
        .padding(.vertical, .barVPadding)
        .background(Color.barBackground)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let icon: Self = .primaryBlue
    fileprivate static let primaryText: Self = .textPrimary
    fileprivate static let secondaryText: Self = .textSecondary
    fileprivate static let tertiaryText: Self = .textTertiary
    fileprivate static let failure: Self = .errorRed
    fileprivate static let barBackground: Self = .backgroundPrimary
    fileprivate static let guide: Self = .borderPrimary
    fileprivate static let staleBackground: Self = .warningYellow.opacity(.staleOpacity)

    fileprivate static func runForeground(isEnabled: Bool) -> Self {
        isEnabled ? .backgroundPrimary : .textTertiary
    }

    fileprivate static func runBackground(isEnabled: Bool) -> Self {
        isEnabled ? .primaryBlue : .undefinedGrey.opacity(.disabledBackground)
    }
}

extension Font {
    fileprivate static let headerName: Self = .title2.weight(.semibold)
    fileprivate static let sourceCaption: Self = .caption
    fileprivate static let rowDetail: Self = .footnote
    fileprivate static let addButton: Self = .title3
    fileprivate static let emptyIcon: Self = .largeTitle
    fileprivate static let emptyTitle: Self = .headline
    fileprivate static let runLabel: Self = .headline
    fileprivate static let disclosure: Self = .caption
    fileprivate static let badge: Self = .caption2.weight(.semibold)
}

extension Angle {
    fileprivate static let expanded: Self = .degrees(90)
}

extension CGFloat {
    fileprivate static let headerVSpacing: Self = 4
    fileprivate static let rowSpacing: Self = 10
    fileprivate static let rowVSpacing: Self = 2
    fileprivate static let chevronSpacing: Self = 4
    /// Outline indent per depth level (LTA-21).
    fileprivate static let indentPerLevel: Self = 22
    /// The indent at accessibility text sizes (spec 006 FR-015).
    fileprivate static let indentPerLevelAccessible: Self = 12
    fileprivate static let guideWidth: Self = 1
    fileprivate static let guideSpacing: Self = 0
    fileprivate static let disclosureWidth: Self = 12
    fileprivate static let badgeHPadding: Self = 6
    fileprivate static let badgeCorners: Self = 4
    fileprivate static let emptySpacing: Self = 6
    fileprivate static let emptyVPadding: Self = 24
    fileprivate static let runVPadding: Self = 14
    fileprivate static let runCorners: Self = 12
    fileprivate static let barHPadding: Self = 16
    fileprivate static let barVPadding: Self = 12
    fileprivate static let sheetMinWidth: Self = 440
    fileprivate static let sheetMinHeight: Self = 560
}

extension EdgeInsets {
    fileprivate static let headerInsets = EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 0)
}

extension Double {
    fileprivate static let disabledBackground: Self = 0.2
    fileprivate static let staleOpacity: Self = 0.25
}

extension String {
    fileprivate static let staleIcon = "exclamationmark.triangle"
    fileprivate static let removeIcon = "trash"
    fileprivate static let editIcon = "slider.horizontal.3"
    fileprivate static let saveIcon = "bookmark"
    fileprivate static let backIcon = "chevron.backward"
}

extension Int {
    fileprivate static let pathLines: Self = 2
}

extension ImageType {
    fileprivate static let add: Self = .system("plus.circle")
    fileprivate static let chevron: Self = .system("chevron.right")
    fileprivate static let disclosure: Self = .system("chevron.right")
    fileprivate static let saved: Self = .system("bookmark.fill")
}

extension LocalizedStringKey {
    fileprivate static let sourceCaption: Self = "Source"
    fileprivate static let notRun: Self = "Not run"
    fileprivate static let run: Self = "Run"
    fileprivate static let running: Self = "Running…"
    fileprivate static let emptyTitle: Self = "No blocks yet"
    fileprivate static let emptyMessage: Self = "Tap + on the source to add the first block."
    fileprivate static let staleBanner: Self = "Results are out of date. Run again to update them."
    fileprivate static let outOfDate: Self = "Out of date"
    fileprivate static let remove: Self = "Remove"
    fileprivate static let edit: Self = "Edit"
    fileprivate static let back: Self = "Chains"
    fileprivate static let saveResult: Self = "Save Result"
    fileprivate static let savedHeader: Self = "Saved results"
    fileprivate static let delete: Self = "Delete"

    /// A saved result's path, root to block (FR-028).
    fileprivate static func path(_ path: [Block]) -> Self {
        // Titles are per-kind tokens; joined here because a path's length varies.
        "\(path.map { String(localized: .blockName($0.kind)) }.joined(separator: " → "))"
    }

    fileprivate static func savedDetail(_ saved: SavedResult) -> Self {
        "\(saved.stamp.sourceDisplayName) · \(saved.savedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    fileprivate static func savedStatus(_ freshness: ResultFreshness, chainChanged: Bool) -> Self? {
        switch freshness {
        case .outOfDate: "Out of date"
        case .sourceUnavailable: "Source unavailable"
        case .current: chainChanged ? "Chain changed since" : nil
        }
    }

    fileprivate static func hiddenBlocks(_ count: Int) -> Self {
        count == 1 ? "· 1 block hidden" : "· \(count.formatted()) blocks hidden"
    }
}

#Preview("Chain - empty - light") {
    NavigationStack { ChainEditorView(store: .preview(.previewEmpty)) }
        .preferredColorScheme(.light)
}

#Preview("Chain - empty - dark") {
    NavigationStack { ChainEditorView(store: .preview(.previewEmpty)) }
        .preferredColorScheme(.dark)
}

#Preview("Chain - not run - light") {
    NavigationStack { ChainEditorView(store: .preview(.previewCountOnly)) }
        .preferredColorScheme(.light)
}

#Preview("Chain - running - dark") {
    NavigationStack {
        ChainEditorView(store: .preview(.previewCountOnly, results: [.previewCountNode: .running], isRunning: true))
    }
    .preferredColorScheme(.dark)
}

#Preview("Chain - has result - light") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, results: [.previewCountNode: .value(.previewElementCounts, .previewMock)]
        ))
    }
    .preferredColorScheme(.light)
}

#Preview("Chain - two branches - light") {
    NavigationStack { ChainEditorView(store: .preview(.previewBranches)) }
        .preferredColorScheme(.light)
}

#Preview("Chain - collapsed branch - dark") {
    NavigationStack { ChainEditorView(store: .preview(.previewBranches, collapsed: [.previewFilterNode])) }
        .preferredColorScheme(.dark)
}

#Preview("Chain - out of date - light") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly.bumped, results: [.previewCountNode: .value(.previewElementCounts, .previewMock)]
        ))
    }
    .preferredColorScheme(.light)
}

#Preview("Chain - out of date - dark") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly.bumped, results: [.previewCountNode: .value(.previewElementCounts, .previewMock)]
        ))
    }
    .preferredColorScheme(.dark)
}

#Preview("Chain - failed - light") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, results: [.previewCountNode: .failed(.overBudget(limit: 5_000_000), .previewMock)]
        ))
    }
    .preferredColorScheme(.light)
}

#Preview("Chain - saved results - light") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, results: [.previewCountNode: .value(.previewElementCounts, .previewMock)], saved: .previewSaved
        ))
    }
    .preferredColorScheme(.light)
}

#Preview("Chain - saved results - dark") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, results: [.previewCountNode: .value(.previewElementCounts, .previewMock)], saved: .previewSaved
        ))
    }
    .preferredColorScheme(.dark)
}

#Preview("Chain - restore prompt - light") {
    NavigationStack { ChainEditorView(store: .preview(.previewCountOnly, alert: .restoreDraft)) }
        .preferredColorScheme(.light)
}

#Preview("Chain - read failed alert - light") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, alert: .readFailed(.unreadableStoredDraws, sourceName: "MBNet Server")
        ))
    }
    .preferredColorScheme(.light)
}

#Preview("Chain - read failed alert - dark") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, alert: .readFailed(.sourceUnavailable, sourceName: "MBNet Server")
        ))
    }
    .preferredColorScheme(.dark)
}

#Preview("Chain - has result - AX5 - light") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, results: [.previewCountNode: .value(.previewElementCounts, .previewMock)]
        ))
    }
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.light)
}

#Preview("Chain - has result - AX5 - dark") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, results: [.previewCountNode: .value(.previewElementCounts, .previewMock)]
        ))
    }
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}

#Preview("Chain - has result - dark") {
    NavigationStack {
        ChainEditorView(store: .preview(
            .previewCountOnly, results: [.previewCountNode: .value(.previewElementCounts, .previewMock)]
        ))
    }
    .preferredColorScheme(.dark)
}

extension Chain {
    /// This chain one edit later, so results stamped with its revision read as out of date.
    fileprivate var bumped: Chain {
        var chain = self
        chain.revision += 1
        return chain
    }
}

extension StoreOf<ChainEditor> {
    fileprivate static func preview(
        _ chain: Chain,
        results: [ChainNode.ID: NodeResult] = [:],
        isRunning: Bool = false,
        collapsed: Set<ChainNode.ID> = [],
        saved: [SavedResult] = [],
        alert: AlertState<ChainEditor.Action.Alert>? = nil
    ) -> StoreOf<ChainEditor> {
        var state = ChainEditor.State(chain: chain, source: ChainSource(id: "mbnet", name: "MBNet Server"))
        state.results = results
        state.isRunning = isRunning
        state.collapsed = collapsed
        state.savedResults = IdentifiedArray(uniqueElements: saved)
        state.alert = alert
        state.dataStates = ["mbnet": .previewMock]
        return Store(initialState: state) {
            ChainEditor()
        } withDependencies: {
            $0.blSources = .previewMock
        }
    }
}
