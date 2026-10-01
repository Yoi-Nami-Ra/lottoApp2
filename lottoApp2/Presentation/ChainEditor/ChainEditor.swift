//
//  ChainEditor.swift
//  lottoApp2
//
//  One open chain (LTA-21, LTA-23): its outline, adding blocks, running it against the chosen source, and
//  each node's result (spec 003 FR-013–FR-024).
//

import ComposableArchitecture
import Foundation
import SwiftUI

/// The source a chain runs against — always the one chosen on the start page (FR-018).
struct ChainSource: Equatable, Sendable {
    let id: String
    let name: String
}

@Reducer
struct ChainEditor {
    @ObservableState
    struct State: Equatable {
        var chain: Chain
        let source: ChainSource
        /// Per node; a node without an entry reads as not run.
        var results: [ChainNode.ID: NodeResult] = [:]
        /// Current data state per source id, for judging each result against its own source (R13).
        var dataStates: [String: SourceDataState?] = [:]
        var isRunning = false
        /// Elements per draw of the chosen source, once its draws have been read; bounds z (spec 006 FR-009).
        var drawSize: Int?
        /// The stamp of the run in progress or last finished.
        var runStamp: RunStamp?
        /// Nodes whose subtree the outline folds away (LTA-21).
        var collapsed: Set<ChainNode.ID> = []
        /// This chain's saved results, newest first (FR-029).
        var savedResults: IdentifiedArrayOf<SavedResult> = []
        /// Nodes whose current result has been saved since the last run.
        var savedNodeIDs: Set<ChainNode.ID> = []
        /// A draft found on opening, waiting for the person to restore or decline it (FR-031).
        var pendingDraft: ChainDraft?
        @Presents var addBlock: AddBlock.State?
        /// The parameter step on its own, editing an existing block (LTA-22 edit mode).
        @Presents var editBlock: BlockParameters.State?
        @Presents var result: ResultPage.State?
        @Presents var alert: AlertState<Action.Alert>?

        init(chain: Chain, source: ChainSource) {
            self.chain = chain
            self.source = source
        }

        /// A run can start whenever there is something to run — also while one is going, which it then
        /// replaces (FR-020).
        var canRun: Bool { !chain.nodes.isEmpty }

        /// Whether a node's result still describes the chain and its source (FR-021).
        func freshness(_ nodeID: ChainNode.ID) -> ResultFreshness? {
            results[nodeID].map { $0.freshness(chainRevision: chain.revision, dataStates: dataStates) }
        }

        /// Any shown result is out of date — the outline's banner (LTA-21).
        var hasOutdatedResults: Bool {
            results.keys.contains { freshness($0) == .outOfDate }
        }

        /// Opens a block's parameter step on its own; a block without parameters has nothing to edit.
        mutating func startEditing(_ nodeID: ChainNode.ID) {
            guard isEditable(nodeID), let node = chain.nodes[id: nodeID] else { return }
            editBlock = BlockParameters.State(
                kind: node.block.kind, mode: .edit(nodeID: nodeID, original: node.block), context: context(under: node.parentID)
            )
        }

        /// Any value result not saved since the last run — what leaving would lose (FR-032). Failures can't be
        /// saved, so they don't count, though a draft keeps them.
        var hasUnsavedResults: Bool {
            results.contains { nodeID, result in
                if case .value = result { !savedNodeIDs.contains(nodeID) } else { false }
            }
        }

        /// Only blocks with parameters have anything to edit.
        func isEditable(_ nodeID: ChainNode.ID) -> Bool {
            guard let node = chain.nodes[id: nodeID] else { return false }
            return BlockParameters.State(kind: node.block.kind, mode: .add).parameter != .none
        }

        /// Whether a block can go under `nodeID` at all: a single number ends a branch (FR-012).
        func canAdd(under nodeID: ChainNode.ID?) -> Bool {
            guard let output = try? chain.outputKind(of: nodeID) else { return false }
            return output != .number
        }

        /// The chosen source's record count, once known.
        var sourceRecordsCount: Int? { dataStates[source.id]??.recordsCount }

        /// How big the parent's output was in its last run — even an out-of-date one — or the source's record
        /// count directly under it; `nil` when nothing has told us (spec 006 FR-002).
        func parentSize(of parentID: ChainNode.ID?) -> BlockParameters.ParentSize? {
            guard let parentID else { return sourceRecordsCount.map { .init(count: $0, unit: .draws) } }
            guard case let .value(value, _) = results[parentID] else { return nil }
            switch value {
            case .draws(let game): return .init(count: game.entries.count, unit: .draws)
            case .counts(let result): return .init(count: result.counts.count, unit: .items)
            case .number: return nil
            }
        }

        /// What the parameter step for a block under `parentID` should know.
        func context(under parentID: ChainNode.ID?) -> BlockParameters.Context {
            BlockParameters.Context(parentSize: parentSize(of: parentID), drawSize: drawSize)
        }

        /// The summary of a node that ran — a leaf or an intermediate block (FR-024).
        func summary(_ nodeID: ChainNode.ID) -> ValueSummary? {
            guard case let .value(value, _) = results[nodeID] else { return nil }
            return ResultSummary.summary(of: value)
        }

        /// What a row shows — and says — on its right (LTA-21, spec 006 FR-014).
        func rowStatus(_ nodeID: ChainNode.ID) -> RowStatus {
            switch results[nodeID] {
            case .running: .running
            case .value(let value, _): .value(ResultSummary.summary(of: value), isStale: freshness(nodeID) != .current)
            case .failed(let failure, _): .failed(failure)
            case .notRun, nil: .notRun
            }
        }

        /// The chain as an indented outline: every node after its parent, children in insertion order, and
        /// nothing below a collapsed node.
        var outline: [OutlineRow] {
            var rows: [OutlineRow] = []
            func visit(_ parentID: ChainNode.ID?, depth: Int) {
                for node in chain.children(of: parentID) {
                    rows.append(OutlineRow(node: node, depth: depth, hasChildren: !chain.children(of: node.id).isEmpty))
                    if !collapsed.contains(node.id) { visit(node.id, depth: depth + 1) }
                }
            }
            visit(nil, depth: 1)
            return rows
        }

        /// How many blocks a collapsed node hides; 0 when it is expanded.
        func hiddenCount(_ nodeID: ChainNode.ID) -> Int {
            guard collapsed.contains(nodeID) else { return 0 }
            func descendants(of id: ChainNode.ID) -> Int {
                chain.children(of: id).reduce(0) { $0 + 1 + descendants(of: $1.id) }
            }
            return descendants(of: nodeID)
        }
    }

    enum RowStatus: Equatable {
        case notRun
        case running
        case value(ValueSummary, isStale: Bool)
        case failed(BlockFailure)
    }

    struct OutlineRow: Equatable, Identifiable {
        let node: ChainNode
        /// 1 for a block directly under the input.
        let depth: Int
        let hasChildren: Bool
        var id: ChainNode.ID { node.id }
    }

    enum Action {
        case onAppear
        case loaded(savedResults: [SavedResult], draft: ChainDraft?, dataStates: [String: SourceDataState?], drawSize: Int?)
        case addTapped(parent: ChainNode.ID?)
        case addBlock(PresentationAction<AddBlock.Action>)
        case nodeTapped(ChainNode.ID)
        case editTapped(ChainNode.ID)
        case editBlock(PresentationAction<BlockParameters.Action>)
        case removeTapped(ChainNode.ID)
        case toggleCollapsed(ChainNode.ID)
        case runTapped
        case gameLoaded(Result<SourceSnapshot, SourceReadFailure>)
        case runEvent(RunEvent)
        case saveResultTapped(ChainNode.ID)
        case savedResultTapped(SavedResult.ID)
        case deleteSavedResultTapped(SavedResult.ID)
        case backTapped
        case scenePhaseChanged(ScenePhase)
        case saveFailed
        case result(PresentationAction<ResultPage.Action>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        @CasePathable
        enum Alert: Equatable {
            case confirmRemove(ChainNode.ID)
            case saveAndLeave
            case discardAndLeave
            case restoreDraft
            case declineDraft
        }

        @CasePathable
        enum Delegate: Equatable {
            case chainChanged(Chain)
        }
    }

    nonisolated private enum CancelID: Hashable, Sendable {
        case run
    }

    @Dependency(\.blSources) var blSources
    @Dependency(\.chainRunner) var chainRunner
    @Dependency(\.chainsRepo) var chainsRepo
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Saved results and a draft can come from other sources than the chosen one; each is judged
                // against its own source, so read the state of every source involved (R13).
                return .run { [chainID = state.chain.id, sourceID = state.source.id, blSources, chainsRepo] send in
                    // The draw size bounds z; a source without stored draws leaves it unknown (spec 006 R1). It
                    // needs none of the reads below, so it runs alongside them.
                    async let drawSize = try? blSources.gameFor(sourceID).get().game.type.combinationType.pick
                    let saved = await chainsRepo.listResults(chainID)
                    let draft = await chainsRepo.draft(chainID)
                    var sources: Set<String> = [sourceID]
                    sources.formUnion(saved.map(\.stamp.sourceName))
                    sources.formUnion(draft?.results.values.compactMap(\.stamp?.sourceName) ?? [])
                    var states: [String: SourceDataState?] = [:]
                    for source in sources { states[source] = await blSources.dataStateFor(source) }
                    await send(.loaded(savedResults: saved, draft: draft, dataStates: states, drawSize: await drawSize))
                }

            case let .loaded(saved, draft, states, drawSize):
                state.savedResults = IdentifiedArray(uniqueElements: saved)
                // A run may already have read the draws; a load that couldn't doesn't forget them.
                if let drawSize { state.drawSize = drawSize }
                state.dataStates.merge(states) { _, loaded in loaded }
                if let draft {
                    state.pendingDraft = draft
                    state.alert = .restoreDraft
                }
                return .none

            case .addTapped(let parentID):
                guard state.canAdd(under: parentID), let parentOutput = try? state.chain.outputKind(of: parentID)
                else { return .none }
                let parent: AddBlock.Parent = if let parentID, let node = state.chain.nodes[id: parentID] {
                    .block(node.block)
                } else {
                    .input(sourceName: state.source.name)
                }
                state.addBlock = AddBlock.State(
                    parentID: parentID, parent: parent, parentOutput: parentOutput, context: state.context(under: parentID)
                )
                return .none

            case .addBlock(.presented(.delegate(.added(let block)))):
                guard let parentID = state.addBlock.map(\.parentID) else { return .none }
                state.addBlock = nil
                do throws(ChainError) {
                    let (chain, _) = try state.chain.attaching(block, under: parentID, id: uuid())
                    state.chain = chain
                } catch {
                    // The sheet only offers blocks that fit, so this guards the rule rather than a normal path.
                    if case let .inputMismatch(needs, _) = error { state.alert = .attachRefused(needs: needs) }
                    return .none
                }
                return saveChain(state.chain)

            case .nodeTapped(let nodeID):
                // A block that ran opens its result (FR-024); one that hasn't is edited instead (LTA-21).
                guard case let .value(value, stamp) = state.results[nodeID] else {
                    state.startEditing(nodeID)
                    return .none
                }
                state.result = ResultPage.State(value: value, stamp: stamp, freshness: state.freshness(nodeID) ?? .current)
                return .none

            case .editTapped(let nodeID):
                state.startEditing(nodeID)
                return .none

            case .editBlock(.presented(.delegate(.confirmed(let block)))):
                guard case let .edit(nodeID, _) = state.editBlock?.mode else { return .none }
                state.editBlock = nil
                do throws(ChainError) {
                    // Results stay, now out of date through the revision; nothing re-runs (FR-021).
                    state.chain = try state.chain.updating(nodeID, to: block)
                } catch {
                    if case let .inputMismatch(needs, _) = error { state.alert = .attachRefused(needs: needs) }
                    return .none
                }
                return saveChain(state.chain)

            case .removeTapped(let nodeID):
                let below = state.chain.children(of: nodeID).isEmpty
                if below { return remove(nodeID, from: &state) }
                guard let (_, removing) = try? state.chain.removingSubtree(nodeID) else { return .none }
                state.alert = .confirmRemove(nodeID, removing: removing)
                return .none

            case .alert(.presented(.confirmRemove(let nodeID))):
                return remove(nodeID, from: &state)

            case .toggleCollapsed(let nodeID):
                if state.collapsed.remove(nodeID) == nil { state.collapsed.insert(nodeID) }
                return .none

            case .runTapped:
                guard state.canRun else { return .none }
                state.isRunning = true
                return .run { [sourceID = state.source.id, blSources] send in
                    await send(.gameLoaded(await blSources.gameFor(sourceID)))
                }
                .cancellable(id: CancelID.run, cancelInFlight: true)

            case .gameLoaded(.failure(let failure)):
                state.isRunning = false
                state.alert = .readFailed(failure, sourceName: state.source.name)
                return .none

            case .gameLoaded(.success(let snapshot)):
                let stamp = RunStamp(
                    sourceName: state.source.id,
                    sourceDisplayName: state.source.name,
                    dataState: snapshot.dataState,
                    chainRevision: state.chain.revision
                )
                state.dataStates[state.source.id] = snapshot.dataState
                state.drawSize = snapshot.game.type.combinationType.pick
                state.runStamp = stamp
                state.results = Dictionary(uniqueKeysWithValues: state.chain.nodes.map { ($0.id, .running) })
                state.savedNodeIDs = []
                return .run { [chain = state.chain, chainRunner] send in
                    for await event in chainRunner.run(chain, snapshot.game) {
                        await send(.runEvent(event))
                    }
                }
                .cancellable(id: CancelID.run, cancelInFlight: true)

            case let .runEvent(.nodeFinished(nodeID, result)):
                // A node removed while the run was going has nowhere to show its result.
                guard let stamp = state.runStamp, state.chain.nodes[id: nodeID] != nil else { return .none }
                switch result {
                case .success(let value): state.results[nodeID] = .value(value, stamp)
                case .failure(let failure): state.results[nodeID] = .failed(failure, stamp)
                }
                return .none

            case .runEvent(.finished):
                state.isRunning = false
                return .none

            case .saveResultTapped(let nodeID):
                guard let saved = state.savedResult(for: nodeID, id: uuid(), at: date.now) else { return .none }
                state.savedResults.insert(saved, at: 0)
                state.savedNodeIDs.insert(nodeID)
                return .merge(save([saved]), deleteDraft(state.chain.id))

            case .savedResultTapped(let id):
                guard let saved = state.savedResults[id: id] else { return .none }
                state.result = ResultPage.State(
                    value: saved.value,
                    stamp: saved.stamp,
                    freshness: saved.freshness(dataStates: state.dataStates),
                    chainChanged: saved.chainChanged(since: state.chain)
                )
                return .none

            case .deleteSavedResultTapped(let id):
                state.savedResults.remove(id: id)
                return .run { [chainsRepo] _ in try await chainsRepo.deleteResult(id) } catch: { _, send in
                    await send(.saveFailed)
                }

            case .backTapped:
                // The one way out of the editor (the system back button is hidden), so the warning can't be
                // skipped (FR-032, R11).
                guard state.hasUnsavedResults else { return .run { [dismiss] _ in await dismiss() } }
                state.alert = .leaveWithUnsaved
                return .none

            case .alert(.presented(.saveAndLeave)):
                let now = date.now
                let unsaved = state.results.keys.sorted { $0.uuidString < $1.uuidString }
                    .filter { !state.savedNodeIDs.contains($0) }
                    .compactMap { state.savedResult(for: $0, id: uuid(), at: now) }
                state.savedResults.insert(contentsOf: unsaved, at: 0)
                state.savedNodeIDs.formUnion(unsaved.map(\.nodeID))
                return .concatenate(save(unsaved), deleteDraft(state.chain.id), .run { [dismiss] _ in await dismiss() })

            case .alert(.presented(.discardAndLeave)):
                return .concatenate(deleteDraft(state.chain.id), .run { [dismiss] _ in await dismiss() })

            case .scenePhaseChanged(let phase):
                // iOS gives no callback when the app is swiped away, so background is the last safe moment (R12).
                guard phase == .background, state.hasUnsavedResults else { return .none }
                let draft = ChainDraft(
                    chainID: state.chain.id,
                    results: state.results.filter { $0.value.stamp != nil },
                    createdAt: date.now
                )
                return .run { [chainsRepo] _ in try await chainsRepo.putDraft(draft) } catch: { _, send in
                    await send(.saveFailed)
                }

            case .alert(.presented(.restoreDraft)):
                guard let draft = state.pendingDraft else { return .none }
                state.pendingDraft = nil
                // Restored results keep their stamps, so the usual out-of-date rules apply (FR-021).
                state.results = draft.results.filter { state.chain.nodes[id: $0.key] != nil }
                return deleteDraft(state.chain.id)

            case .alert(.presented(.declineDraft)):
                state.pendingDraft = nil
                return deleteDraft(state.chain.id)

            case .saveFailed:
                state.alert = .saveFailed
                return .none

            case .addBlock, .editBlock, .result, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$addBlock, action: \.addBlock) { AddBlock() }
        .ifLet(\.$editBlock, action: \.editBlock) { BlockParameters() }
        .ifLet(\.$result, action: \.result) { ResultPage() }
        .ifLet(\.$alert, action: \.alert)
    }

    private func save(_ results: [SavedResult]) -> Effect<Action> {
        .run { [chainsRepo] _ in
            for result in results { try await chainsRepo.saveResult(result) }
        } catch: { _, send in
            await send(.saveFailed)
        }
    }

    /// Saving or discarding results also drops the chain's draft (FR-031).
    private func deleteDraft(_ chainID: Chain.ID) -> Effect<Action> {
        .run { [chainsRepo] _ in try? await chainsRepo.deleteDraft(chainID) }
    }

    /// Removes a block and its subtree (FR-016), with their results and fold state.
    private func remove(_ nodeID: ChainNode.ID, from state: inout State) -> Effect<Action> {
        guard let (chain, _) = try? state.chain.removingSubtree(nodeID) else { return .none }
        state.chain = chain
        state.results = state.results.filter { chain.nodes[id: $0.key] != nil }
        state.collapsed = state.collapsed.filter { chain.nodes[id: $0] != nil }
        state.savedNodeIDs = state.savedNodeIDs.filter { chain.nodes[id: $0] != nil }
        return saveChain(chain)
    }

    /// Keeps the edit (FR-017) and tells the chain list its row changed.
    private func saveChain(_ chain: Chain) -> Effect<Action> {
        .merge(
            .run { [chainsRepo] _ in try await chainsRepo.saveChain(chain) } catch: { _, send in await send(.saveFailed) },
            .send(.delegate(.chainChanged(chain)))
        )
    }
}

extension AlertState where Action == ChainEditor.Action.Alert {
    /// The failed-run alert, worded for why the draws couldn't be read (spec 004 FR-008, contracts §4).
    static func readFailed(_ failure: SourceReadFailure, sourceName: String) -> AlertState {
        AlertState {
            TextState(.readFailedTitle)
        } message: {
            TextState(LocalizedStringResource.readFailedMessage(failure, sourceName: sourceName))
        }
    }

    static var saveFailed: AlertState {
        AlertState {
            TextState(.saveFailedTitle)
        } message: {
            TextState(.saveFailedMessage)
        }
    }

    /// A block with children goes only after the person confirms how many blocks go with it (LTA-21).
    static func confirmRemove(_ nodeID: ChainNode.ID, removing count: Int) -> AlertState {
        AlertState {
            TextState(.removeTitle(count - 1))
        } actions: {
            ButtonState(role: .destructive, action: .confirmRemove(nodeID)) {
                TextState(.removeConfirm(count))
            }
            ButtonState(role: .cancel) {
                TextState(.removeCancel)
            }
        }
    }

    /// FR-032: leaving would lose unsaved results.
    static var leaveWithUnsaved: AlertState {
        AlertState {
            TextState(.leaveTitle)
        } actions: {
            ButtonState(action: .saveAndLeave) { TextState(.leaveSave) }
            ButtonState(role: .destructive, action: .discardAndLeave) { TextState(.leaveDiscard) }
            ButtonState(role: .cancel) { TextState(.removeCancel) }
        } message: {
            TextState(.leaveMessage)
        }
    }

    /// FR-031: a draft was kept when the app last went to the background.
    static var restoreDraft: AlertState {
        AlertState {
            TextState(.restoreTitle)
        } actions: {
            ButtonState(action: .restoreDraft) { TextState(.restoreConfirm) }
            ButtonState(role: .cancel, action: .declineDraft) { TextState(.restoreDecline) }
        } message: {
            TextState(.restoreMessage)
        }
    }

    /// FR-015: a refused attach names the kind the block needs.
    static func attachRefused(needs: Set<ValueKind>) -> AlertState {
        AlertState {
            TextState(.attachRefusedTitle)
        } message: {
            TextState(needs.contains(.counts) && !needs.contains(.draws) ? .needsCounts : .needsDraws)
        }
    }
}

// MARK: - Resources
extension LocalizedStringResource {
    fileprivate static let readFailedTitle: Self = "Couldn't run the chain"
    fileprivate static func readFailedMessage(_ failure: SourceReadFailure, sourceName name: String) -> Self {
        switch failure {
        case .sourceUnavailable: "\(name) is no longer available."
        case .unreadableStoredDraws: "\(name)'s stored draws couldn't be read. Refresh the source and try again."
        }
    }
    fileprivate static let saveFailedTitle: Self = "Couldn't save the chain"
    fileprivate static let saveFailedMessage: Self = "Your last change may not be kept after the app closes."
    fileprivate static func removeTitle(_ below: Int) -> Self {
        below == 1 ? "Remove this block and the block under it?" : "Remove this block and the \(below) blocks under it?"
    }
    fileprivate static func removeConfirm(_ count: Int) -> Self { "Remove \(count) Blocks" }
    fileprivate static let removeCancel: Self = "Cancel"
    fileprivate static let leaveTitle: Self = "Leave without saving?"
    fileprivate static let leaveMessage: Self = "This chain's unsaved results will be lost."
    fileprivate static let leaveSave: Self = "Save Results"
    fileprivate static let leaveDiscard: Self = "Discard"
    fileprivate static let restoreTitle: Self = "Restore unsaved results?"
    fileprivate static let restoreMessage: Self = "They were kept when the app last closed."
    fileprivate static let restoreConfirm: Self = "Restore"
    fileprivate static let restoreDecline: Self = "Discard"
    fileprivate static let attachRefusedTitle: Self = "This block can't go here"
    fileprivate static let needsDraws: Self = "It needs draws — add it under the source or a filter."
    fileprivate static let needsCounts: Self = "It needs counts — add a count block first."
}

extension ChainEditor.State {
    /// A node's current value as a saved result: the path that produced it, its source, and when (FR-028).
    func savedResult(for nodeID: ChainNode.ID, id: UUID, at date: Date) -> SavedResult? {
        guard case let .value(value, stamp) = results[nodeID] else { return nil }
        return SavedResult(
            id: id, chainID: chain.id, nodeID: nodeID, path: chain.path(to: nodeID),
            value: value, stamp: stamp, savedAt: date
        )
    }
}

nonisolated extension NodeResult {
    /// The stamp of a result that ran; `nil` before.
    var stamp: RunStamp? {
        switch self {
        case .notRun, .running: nil
        case .value(_, let stamp), .failed(_, let stamp): stamp
        }
    }
}
