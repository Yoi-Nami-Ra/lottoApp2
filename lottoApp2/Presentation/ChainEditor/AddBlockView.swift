//
//  AddBlockView.swift
//  lottoApp2
//
//  The add-block sheet's catalogue step, per design/final/add-block-sheet.html.
//

import ComposableArchitecture
import SwiftUI

struct AddBlockView: View {
    @Bindable var store: StoreOf<AddBlock>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    parentLine
                }
                .listRowBackground(Color.clear)

                ForEach(CatalogueSection.allCases, id: \.self) { section in
                    let kinds = section.kinds.filter(store.catalogue.contains)
                    if !kinds.isEmpty {
                        Section(LocalizedStringKey.catalogueSection(section)) {
                            ForEach(kinds, id: \.self) { kind in row(kind) }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey.sheetTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey.cancel) { store.send(.cancelTapped) }
                }
            }
            .navigationDestination(item: $store.scope(state: \.parameters, action: \.parameters)) { parameters in
                BlockParametersView(store: parameters)
            }
        }
        #if os(macOS)
        // A macOS sheet takes its content's ideal size, and a List has no ideal height, so without a
        // minimum the sheet collapses to its toolbar and every block row is hidden.
        .frame(minWidth: .sheetMinWidth, minHeight: .sheetMinHeight)
        #endif
    }

    /// "Under <parent>" plus the kind chip, so the reason behind any unavailable row is visible at a glance.
    private var parentLine: some View {
        HStack(spacing: .chipSpacing) {
            Text(.under)
                .foregroundStyle(Color.secondaryText)
            Text(.parentName(store.parent))
                .fontWeight(.parentName)
                .foregroundStyle(Color.primaryText)
            Text(.valueKind(store.parentOutput))
                .font(.chip)
                .padding(.horizontal, .chipHPadding)
                .padding(.vertical, .chipVPadding)
                .background(Color.chipBackground)
                .cornerRadius(.chipCorners)
        }
        .font(.parentLine)
        .listRowInsets(.parentLineInsets)
    }

    private func row(_ kind: ProcessingBlockKind) -> some View {
        let availability = store.state.availability(kind)
        let isAvailable = availability == .available
        return Button { store.send(.kindTapped(kind)) } label: {
            HStack(spacing: .rowSpacing) {
                Image(.block)
                    .foregroundStyle(isAvailable ? Color.icon : Color.tertiaryText)
                VStack(alignment: .leading, spacing: .rowVSpacing) {
                    Text(.blockTitle(kind))
                        .foregroundStyle(isAvailable ? Color.primaryText : Color.tertiaryText)
                    if case let .needs(kinds) = availability {
                        Label(LocalizedStringKey.needs(kinds), systemImage: .reasonIcon)
                            .font(.tagline)
                            .foregroundStyle(Color.secondaryText)
                    } else if let tagline = LocalizedStringKey.blockTagline(kind) {
                        Text(tagline)
                            .font(.tagline)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                Spacer()
                if isAvailable {
                    Image(.chevron)
                        .font(.tagline)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel(Text(unavailableReading(kind, availability)), isEnabled: !isAvailable)
    }

    /// "<block>, unavailable, <reason>" for a disabled row (spec 006 FR-010).
    private func unavailableReading(_ kind: ProcessingBlockKind, _ availability: AddBlock.Availability) -> LocalizedStringKey {
        guard case let .needs(kinds) = availability else { return .blockTitle(kind) }
        return .unavailableReading(kind, needs: kinds)
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let icon: Self = .primaryBlue
    fileprivate static let primaryText: Self = .textPrimary
    fileprivate static let secondaryText: Self = .textSecondary
    fileprivate static let tertiaryText: Self = .textTertiary
    fileprivate static let chipBackground: Self = .backgroundTertiary
}

extension Font {
    fileprivate static let parentLine: Self = .footnote
    fileprivate static let chip: Self = .caption2
    fileprivate static let tagline: Self = .footnote
}

extension Font.Weight {
    fileprivate static let parentName: Self = .semibold
}

extension CGFloat {
    fileprivate static let chipSpacing: Self = 6
    fileprivate static let chipHPadding: Self = 6
    fileprivate static let chipVPadding: Self = 2
    fileprivate static let chipCorners: Self = 4
    fileprivate static let rowSpacing: Self = 12
    fileprivate static let rowVSpacing: Self = 2
    fileprivate static let sheetMinWidth: Self = 440
    fileprivate static let sheetMinHeight: Self = 560
}

extension EdgeInsets {
    fileprivate static let parentLineInsets = EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
}

extension ImageType {
    fileprivate static let chevron: Self = .system("chevron.right")
}

extension String {
    fileprivate static let reasonIcon = "info.circle"
}

extension LocalizedStringKey {
    fileprivate static let sheetTitle: Self = "Add Block"
    fileprivate static let cancel: Self = "Cancel"
    fileprivate static let under: Self = "Under"

    fileprivate static func parentName(_ parent: AddBlock.Parent) -> Self {
        switch parent {
        case .input(let sourceName): "\(sourceName)"
        case .block(let block): .blockTitle(block.kind)
        }
    }
}

#Preview("Add block - under draws - light") {
    AddBlockView(store: .preview).preferredColorScheme(.light)
}

#Preview("Add block - under draws - dark") {
    AddBlockView(store: .preview).preferredColorScheme(.dark)
}

#Preview("Add block - under counts - light") {
    AddBlockView(store: .previewUnderCounts).preferredColorScheme(.light)
}

#Preview("Add block - under counts - dark") {
    AddBlockView(store: .previewUnderCounts).preferredColorScheme(.dark)
}

extension StoreOf<AddBlock> {
    fileprivate static var preview: StoreOf<AddBlock> {
        Store(initialState: AddBlock.State(parentID: nil, parent: .input(sourceName: "MBNet Server"), parentOutput: .draws)) {
            AddBlock()
        }
    }

    fileprivate static var previewUnderCounts: StoreOf<AddBlock> {
        Store(initialState: AddBlock.State(parentID: nil, parent: .block(.countUniqueElements), parentOutput: .counts)) {
            AddBlock()
        }
    }
}
