//
//  BlocksPage.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//

import ComposableArchitecture
import Foundation

/// The processing-blocks step: the saved chains, and a way to start a new one (spec 003 FR-017). Opening a
/// chain pushes its editor, which runs against the source chosen on the start page.
@Reducer
struct BlocksPage {
    /// The name a new chain starts with; the person can rename it.
    static let defaultChainName = String(localized: "New chain")

    @ObservableState
    struct State: Equatable {
        /// The source chosen on the start page; every chain opened here runs against it (FR-018).
        let sourceID: String
        /// The chosen source's display name, which the page header shows.
        let sourceName: String
        var chains: IdentifiedArrayOf<Chain> = []
        /// Whether the saved chains have been read, so the empty state never flashes before them (spec 006).
        var hasLoaded = false
        /// The chain whose rename alert is showing, and the name being typed (spec 006 FR-020).
        var renaming: Chain.ID?
        var renameDraft = ""
        @Presents var editor: ChainEditor.State?
        @Presents var alert: AlertState<Action.Alert>?

        init(sourceID: String, sourceName: String) {
            self.sourceID = sourceID
            self.sourceName = sourceName
        }

        var source: ChainSource { ChainSource(id: sourceID, name: sourceName) }

        /// "No chains yet" above New chain, once the list is known to be empty (FR-016).
        var showsEmptyState: Bool { hasLoaded && chains.isEmpty }
    }

    enum Action {
        case onAppear
        case chainsLoaded([Chain])
        case newChainTapped
        case chainTapped(Chain.ID)
        /// From the leading swipe, the long-press menu or the accessibility action alike.
        case renameTapped(Chain.ID)
        case renameDraftChanged(String)
        case renameConfirmed
        case renameCancelled
        case deleteChainTapped(Chain.ID)
        case deleteConfirmationLoaded(Chain.ID, savedCount: Int, hasDraft: Bool)
        case saveFailed
        case editor(PresentationAction<ChainEditor.Action>)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Equatable {
            case confirmDelete(Chain.ID)
        }
    }

    @Dependency(\.chainsRepo) var chainsRepo
    @Dependency(\.uuid) var uuid

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [chainsRepo] send in await send(.chainsLoaded(await chainsRepo.listChains())) }

            case .chainsLoaded(let chains):
                state.chains = IdentifiedArray(uniqueElements: chains)
                state.hasLoaded = true
                return .none

            case .newChainTapped:
                let chain = Chain.empty(id: uuid(), name: Self.defaultChainName)
                state.chains.append(chain)
                state.editor = ChainEditor.State(chain: chain, source: state.source)
                return save(chain)

            case .chainTapped(let id):
                guard let chain = state.chains[id: id] else { return .none }
                state.editor = ChainEditor.State(chain: chain, source: state.source)
                return .none

            case .renameTapped(let id):
                guard let chain = state.chains[id: id] else { return .none }
                state.renaming = id
                state.renameDraft = chain.name
                return .none

            case .renameDraftChanged(let draft):
                state.renameDraft = draft
                return .none

            case .renameCancelled:
                state.renaming = nil
                state.renameDraft = ""
                return .none

            case .renameConfirmed:
                let id = state.renaming
                let trimmed = state.renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                state.renaming = nil
                state.renameDraft = ""
                // A blank or unchanged name is ignored, as is a chain deleted meanwhile.
                guard let id, !trimmed.isEmpty, let chain = state.chains[id: id], chain.name != trimmed else { return .none }
                let renamed = chain.renamed(trimmed)
                state.chains[id: id] = renamed
                return save(renamed)

            case .deleteChainTapped(let id):
                // The confirmation names what goes with the chain: its saved results, and unsaved ones when it
                // has a draft (FR-017, FR-032). Leaving the editor already warned about results on screen.
                return .run { [chainsRepo] send in
                    let savedCount = await chainsRepo.listResults(id).count
                    let hasDraft = await chainsRepo.draft(id) != nil
                    await send(.deleteConfirmationLoaded(id, savedCount: savedCount, hasDraft: hasDraft))
                }

            case let .deleteConfirmationLoaded(id, savedCount, hasDraft):
                guard let chain = state.chains[id: id] else { return .none }
                state.alert = .deleteChain(chain, savedCount: savedCount, hasDraft: hasDraft)
                return .none

            case .alert(.presented(.confirmDelete(let id))):
                state.chains.remove(id: id)
                return .run { [chainsRepo] _ in try await chainsRepo.deleteChain(id) } catch: { _, send in await send(.saveFailed) }

            case .editor(.presented(.delegate(.chainChanged(let chain)))):
                state.chains[id: chain.id] = chain
                return .none

            case .saveFailed:
                state.alert = .saveFailed
                return .none

            case .editor, .alert:
                return .none
            }
        }
        .ifLet(\.$editor, action: \.editor) { ChainEditor() }
        .ifLet(\.$alert, action: \.alert)
    }

    private func save(_ chain: Chain) -> Effect<Action> {
        .run { [chainsRepo] _ in try await chainsRepo.saveChain(chain) } catch: { _, send in await send(.saveFailed) }
    }
}

extension AlertState where Action == BlocksPage.Action.Alert {
    static func deleteChain(_ chain: Chain, savedCount: Int, hasDraft: Bool) -> AlertState {
        AlertState {
            TextState(.deleteChainTitle(chain.name))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete(chain.id)) {
                TextState(.deleteChainConfirm)
            }
            ButtonState(role: .cancel) {
                TextState(.deleteChainCancel)
            }
        } message: {
            TextState(.deleteChainMessage(savedCount: savedCount, hasDraft: hasDraft))
        }
    }

    static var saveFailed: AlertState {
        AlertState {
            TextState(.saveFailedTitle)
        } message: {
            TextState(.saveFailedMessage)
        }
    }
}

// MARK: - Resources
extension LocalizedStringResource {
    fileprivate static func deleteChainTitle(_ name: String) -> Self { "Delete “\(name)”?" }
    fileprivate static func deleteChainMessage(savedCount: Int, hasDraft: Bool) -> Self {
        switch (savedCount, hasDraft) {
        case (0, false): "The chain will be deleted."
        case (0, true): "Its unsaved results will be deleted too."
        case (1, false): "Its saved result will be deleted too."
        case (1, true): "Its saved result and its unsaved results will be deleted too."
        case (_, false): "Its \(savedCount) saved results will be deleted too."
        case (_, true): "Its \(savedCount) saved results and its unsaved results will be deleted too."
        }
    }
    fileprivate static let deleteChainConfirm: Self = "Delete"
    fileprivate static let deleteChainCancel: Self = "Cancel"
    fileprivate static let saveFailedTitle: Self = "Couldn't save your chains"
    fileprivate static let saveFailedMessage: Self = "Your last change may not be kept after the app closes."
}
