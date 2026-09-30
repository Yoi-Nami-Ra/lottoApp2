//
//  BlockParametersView.swift
//  lottoApp2
//
//  Step 2 of the add-block sheet (LTA-22): what the block does, its parameters, and the confirm button.
//

import ComposableArchitecture
import SwiftUI

struct BlockParametersView: View {
    @Bindable var store: StoreOf<BlockParameters>

    var body: some View {
        List {
            Section {
                VStack(spacing: .introSpacing) {
                    Image(.block)
                        .font(.icon)
                        .foregroundStyle(Color.icon)
                    Text(.blockTitle(store.kind))
                        .font(.blockTitle)
                        .foregroundStyle(Color.primaryText)
                    Text(.blockExplanation(store.kind))
                        .font(.explanation)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            parameterSection
        }
        .safeAreaInset(edge: .bottom) {
            Button { store.send(.confirmTapped) } label: {
                Text(.confirm(store.mode))
                    .font(.confirm)
                    .foregroundStyle(Color.confirmForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .confirmVPadding)
                    .background(Color.confirmBackground(isEnabled: store.isValid))
                    .cornerRadius(.confirmCorners)
            }
            .buttonStyle(.plain)
            .disabled(!store.isValid)
            .padding(.horizontal, .barHPadding)
            .padding(.vertical, .barVPadding)
        }
        .navigationTitle(LocalizedStringKey.title(store.mode, kind: store.kind))
        .toolbar {
            // Editing, this step is the sheet's root, so it needs its own way out.
            if case .edit = store.mode {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey.cancel) { store.send(.cancelTapped) }
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var parameterSection: some View {
        switch store.parameter {
        case .none:
            Section {
                Text(.noParameters)
                    .font(.explanation)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

        case .count, .size:
            Section {
                HStack(spacing: .fieldSpacing) {
                    Text(store.parameter == .size ? LocalizedStringKey.zLabel : .xLabel)
                    Spacer()
                    TextField(LocalizedStringKey.xPlaceholder, text: $store.countText.sending(\.countTextChanged))
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(maxWidth: .fieldWidth)
                    Button { store.send(.decrementTapped) } label: { Image(.minus) }
                        .buttonStyle(.bordered)
                        .disabled(!store.canDecrement)
                    Button { store.send(.incrementTapped) } label: { Image(.plus) }
                        .buttonStyle(.bordered)
                }
            } header: {
                Text(.parameterHeader)
            } footer: {
                if store.isValid == false {
                    Text(store.parameter == .size ? LocalizedStringKey.invalidZ : .invalidX)
                        .foregroundStyle(Color.invalid)
                }
            }

        case .direction:
            Section {
                Picker(LocalizedStringKey.directionHeader, selection: $store.direction.sending(\.directionChanged)) {
                    ForEach(SortDirection.allCases, id: \.self) { direction in
                        Text(.directionOption(direction)).tag(direction)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(.directionHeader)
            }
        }
    }
}

// MARK: - Resources
extension Color {
    fileprivate static let icon: Self = .primaryBlue
    fileprivate static let primaryText: Self = .textPrimary
    fileprivate static let secondaryText: Self = .textSecondary
    fileprivate static let confirmForeground: Self = .backgroundPrimary
    fileprivate static let invalid: Self = .errorRed

    fileprivate static func confirmBackground(isEnabled: Bool) -> Self {
        isEnabled ? .primaryBlue : .undefinedGrey.opacity(.disabledBackground)
    }
}

extension Font {
    fileprivate static let icon: Self = .largeTitle
    fileprivate static let blockTitle: Self = .title.weight(.semibold)
    fileprivate static let explanation: Self = .subheadline
    fileprivate static let confirm: Self = .headline
}

extension CGFloat {
    fileprivate static let introSpacing: Self = 8
    fileprivate static let confirmVPadding: Self = 14
    fileprivate static let confirmCorners: Self = 12
    fileprivate static let barHPadding: Self = 16
    fileprivate static let barVPadding: Self = 12
    fileprivate static let fieldSpacing: Self = 8
    /// Wide enough for any x a person would type, so no digit is ever scrolled out of sight.
    fileprivate static let fieldWidth: Self = 160
}

extension ImageType {
    fileprivate static let minus: Self = .system("minus")
    fileprivate static let plus: Self = .system("plus")
}

extension Double {
    fileprivate static let disabledBackground: Self = 0.2
}

extension LocalizedStringKey {
    fileprivate static let cancel: Self = "Cancel"
    fileprivate static let noParameters: Self = "No parameters."
    fileprivate static let parameterHeader: Self = "Parameter"
    fileprivate static let directionHeader: Self = "Direction"
    fileprivate static let xLabel: Self = "x"
    fileprivate static let xPlaceholder: Self = "0"
    fileprivate static let zLabel: Self = "z"
    fileprivate static let invalidX: Self = "Enter a whole number, 0 or more."
    fileprivate static let invalidZ: Self = "Enter a whole number, 2 or more."

    fileprivate static func directionOption(_ direction: SortDirection) -> Self {
        switch direction {
        case .ascending: "Ascending"
        case .descending: "Descending"
        }
    }

    fileprivate static func confirm(_ mode: BlockParameters.Mode) -> Self {
        switch mode {
        case .add: "Add Block"
        case .edit: "Save"
        }
    }

    fileprivate static func title(_ mode: BlockParameters.Mode, kind: ProcessingBlockKind) -> Self {
        switch mode {
        case .add: .blockTitle(kind)
        case .edit: .blockEditTitle(kind)
        }
    }
}

#Preview("Parameters - no parameters - light") {
    NavigationStack { BlockParametersView(store: .preview) }
        .preferredColorScheme(.light)
}

#Preview("Parameters - no parameters - dark") {
    NavigationStack { BlockParametersView(store: .preview) }
        .preferredColorScheme(.dark)
}

#Preview("Parameters - filter - light") {
    NavigationStack { BlockParametersView(store: .preview(.suffix)) }
        .preferredColorScheme(.light)
}

#Preview("Parameters - filter - dark") {
    NavigationStack { BlockParametersView(store: .preview(.suffix)) }
        .preferredColorScheme(.dark)
}

#Preview("Parameters - invalid x - light") {
    NavigationStack { BlockParametersView(store: .preview(.prefix, countText: "-3")) }
        .preferredColorScheme(.light)
}

#Preview("Parameters - sort - dark") {
    NavigationStack { BlockParametersView(store: .preview(.sortByDate)) }
        .preferredColorScheme(.dark)
}

extension StoreOf<BlockParameters> {
    fileprivate static var preview: StoreOf<BlockParameters> { preview(.countUniqueElements) }

    fileprivate static func preview(_ kind: ProcessingBlockKind, countText: String? = nil) -> StoreOf<BlockParameters> {
        var state = BlockParameters.State(kind: kind, mode: .add)
        if let countText { state.countText = countText }
        return Store(initialState: state) { BlockParameters() }
    }
}
