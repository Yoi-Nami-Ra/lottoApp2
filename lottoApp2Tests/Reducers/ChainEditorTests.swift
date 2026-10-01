//
//  ChainEditorTests.swift
//  lottoApp2Tests
//

import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import lottoApp2

struct ChainEditor_Tests {

    private let source = ChainSource(id: "mbnet", name: "MBNet Server")
    private let countNode = UUID(10)

    private var stamp: RunStamp {
        RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 1)
    }

    private var countValue: BlockValue {
        get throws { try BlockEvaluator.evaluate(.countUniqueElements, on: .draws(ReferenceDraws.threeOfFive)) }
    }

    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    @MainActor
    private func makeStore(
        _ state: ChainEditor.State,
        storage: LockIsolated<IdentifiedArrayOf<Chain>> = .init([]),
        results: LockIsolated<IdentifiedArrayOf<SavedResult>> = .init([]),
        drafts: LockIsolated<[Chain.ID: ChainDraft]> = .init([:]),
        runner: ChainRunner = .scripted([]),
        blSources: SourcesBLogic = .mock,
        dismissed: LockIsolated<Bool> = .init(false)
    ) -> TestStoreOf<ChainEditor> {
        TestStore(initialState: state) { ChainEditor() } withDependencies: {
            $0.chainsRepo = .inMemory(storage, results: results, drafts: drafts)
            $0.chainRunner = runner
            $0.blSources = blSources
            $0.uuid = .incrementing
            $0.date = .constant(now)
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }
    }

    // MARK: - Appearing

    @MainActor
    @Test
    func onAppear_loadsTheChosenSourcesDataState() async {
        let store = makeStore(ChainEditor.State(chain: .emptyMock, source: source))

        await store.send(.onAppear)
        await store.receive(\.loaded) {
            $0.dataStates = ["mbnet": .mbnetMock]
            $0.drawSize = 3
        }
    }

    // MARK: - Adding

    @MainActor
    @Test
    func addTapped_underTheInput_presentsTheSheetForDraws() async {
        let store = makeStore(ChainEditor.State(chain: .emptyMock, source: source))

        await store.send(.addTapped(parent: nil)) {
            $0.addBlock = AddBlock.State(parentID: nil, parent: .input(sourceName: "MBNet Server"), parentOutput: .draws)
        }
    }

    @MainActor
    @Test
    func addingABlock_attachesIt_savesTheChain_andLeavesItNotRun() async {
        var state = ChainEditor.State(chain: .emptyMock, source: source)
        state.addBlock = AddBlock.State(parentID: nil, parent: .input(sourceName: "MBNet Server"), parentOutput: .draws)
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([])
        let store = makeStore(state, storage: storage)

        let expected = Chain(
            id: Chain.emptyMock.id, name: Chain.emptyMock.name, revision: 1,
            nodes: [ChainNode(id: UUID(0), parentID: nil, block: .countUniqueElements)]
        )
        await store.send(\.addBlock.delegate.added, .countUniqueElements) {
            $0.chain = expected
            $0.addBlock = nil
        }
        await store.receive(\.delegate.chainChanged, expected)
        await store.finish()
        #expect(storage.value[id: expected.id] == expected)
        #expect(store.state.results[UUID(0)] == nil)  // reads as not run
    }

    // MARK: - Running (FR-018, FR-021)

    @MainActor
    @Test
    func run_stampsEveryResult_andSummarisesEveryNodeThatRan() async throws {
        let value = try countValue
        let store = makeStore(
            ChainEditor.State(chain: .countOnlyMock, source: source),
            runner: .scripted([.nodeFinished(countNode, .success(value)), .finished])
        )

        await store.send(.runTapped) {
            $0.isRunning = true
        }
        await store.receive(\.gameLoaded) {
            $0.dataStates = ["mbnet": .mbnetMock]  // the run's snapshot keeps the lookup in step with its stamp
            $0.drawSize = 3
            $0.runStamp = self.stamp
            $0.results = [self.countNode: .running]
        }
        await store.receive(\.runEvent) {
            $0.results = [self.countNode: .value(value, self.stamp)]
        }
        await store.receive(\.runEvent) {
            $0.isRunning = false
        }
        #expect(store.state.summary(countNode) == .elements(count: 5))
    }

    @MainActor
    @Test
    func runTapped_onAChainWithNoBlocks_doesNothing() async {
        let store = makeStore(ChainEditor.State(chain: .emptyMock, source: source))
        await store.send(.runTapped)
    }

    @MainActor
    @Test(arguments: [SourceReadFailure.sourceUnavailable, .unreadableStoredDraws])
    func aFailedRead_endsTheRun_keepsThePreviousResults_andSaysWhy(_ failure: SourceReadFailure) async throws {
        // Spec 004 US2 / FR-008: the alert says which of the two read failures stopped the run.
        var state = ChainEditor.State(chain: .countOnlyMock, source: source)
        state.results = [countNode: .value(try countValue, stamp)]
        let store = makeStore(state, blSources: .failing(read: failure))

        await store.send(.runTapped) {
            $0.isRunning = true
        }
        await store.receive(\.gameLoaded) {
            $0.isRunning = false
            $0.alert = .readFailed(failure, sourceName: "MBNet Server")
        }
    }

    @Test
    func theTwoReadFailures_haveTheirOwnMessages_underTheSameTitle() {
        // SC-004: distinct messages; the title stays "Couldn't run the chain".
        let unavailable = AlertState<ChainEditor.Action.Alert>.readFailed(.sourceUnavailable, sourceName: "MBNet Server")
        let unreadable = AlertState<ChainEditor.Action.Alert>.readFailed(.unreadableStoredDraws, sourceName: "MBNet Server")

        #expect(unavailable.message != unreadable.message)
        #expect(unavailable.title == unreadable.title)
    }

    // MARK: - Opening results (FR-024)

    @MainActor
    @Test
    func tappingANodeThatRan_opensItsResult() async throws {
        let value = try countValue
        var state = ChainEditor.State(chain: .countOnlyMock, source: source)
        state.results = [countNode: .value(value, stamp)]
        state.dataStates = ["mbnet": .mbnetMock]
        let store = makeStore(state)

        await store.send(.nodeTapped(countNode)) {
            $0.result = ResultPage.State(value: value, stamp: self.stamp, freshness: .current)
        }
    }

    @MainActor
    @Test
    func tappingAnIntermediateNodeThatRan_opensItsResultToo() async throws {
        // FR-024: every block that ran, not only leaves.
        let parent = UUID(20)
        let chain = Chain(
            id: UUID(0), name: "Two", revision: 1,
            nodes: [
                ChainNode(id: parent, parentID: nil, block: .countUniqueElements),
                ChainNode(id: countNode, parentID: parent, block: .countUniqueElements),
            ]
        )
        let value = try countValue
        var state = ChainEditor.State(chain: chain, source: source)
        state.results = [parent: .value(value, stamp), countNode: .running]
        state.dataStates = ["mbnet": .mbnetMock]
        let store = makeStore(state)

        await store.send(.nodeTapped(parent)) {
            $0.result = ResultPage.State(value: value, stamp: self.stamp, freshness: .current)
        }
        #expect(store.state.summary(parent) == .elements(count: 5))
    }

    @MainActor
    @Test
    func tappingANodeThatHasNotRun_editsIt() async {
        // LTA-21: before any run, tapping a block edits it.
        let chain = Chain(id: UUID(0), name: "F", revision: 1, nodes: [ChainNode(id: countNode, parentID: nil, block: .suffix(100))])
        let store = makeStore(ChainEditor.State(chain: chain, source: source))
        await store.send(.nodeTapped(countNode)) {
            $0.editBlock = BlockParameters.State(kind: .suffix, mode: .edit(nodeID: self.countNode, original: .suffix(100)))
        }
    }

    @MainActor
    @Test
    func aBlockWithoutParameters_hasNothingToEdit() async {
        let store = makeStore(ChainEditor.State(chain: .countOnlyMock, source: source))
        await store.send(.nodeTapped(countNode))
        await store.send(.editTapped(countNode))
    }

    // MARK: - Branches (US4)

    private let filterNode = UUID(30)
    private let leafA = UUID(31)
    private let leafB = UUID(32)

    /// input → suffix(100) → { count, count }, plus a count straight under the input: three leaves.
    private var branched: Chain {
        Chain(
            id: UUID(0), name: "Branches", revision: 3,
            nodes: [
                ChainNode(id: filterNode, parentID: nil, block: .suffix(100)),
                ChainNode(id: leafA, parentID: filterNode, block: .countUniqueElements),
                ChainNode(id: leafB, parentID: filterNode, block: .countUniqueElements),
                ChainNode(id: countNode, parentID: nil, block: .countUniqueElements),
            ]
        )
    }

    @MainActor
    @Test
    func addTapped_underABlock_presentsTheSheetForThatBlocksOutput() async {
        let store = makeStore(ChainEditor.State(chain: branched, source: source))

        await store.send(.addTapped(parent: filterNode)) {
            $0.addBlock = AddBlock.State(parentID: self.filterNode, parent: .block(.suffix(100)), parentOutput: .draws)
        }
    }

    @MainActor
    @Test
    func addingASecondChild_createsABranch() async {
        var state = ChainEditor.State(chain: .countOnlyMock, source: source)
        state.addBlock = AddBlock.State(parentID: nil, parent: .input(sourceName: "MBNet Server"), parentOutput: .draws)
        let store = makeStore(state)

        await store.send(\.addBlock.delegate.added, .suffix(50)) {
            $0.chain.nodes.append(ChainNode(id: UUID(0), parentID: nil, block: .suffix(50)))
            $0.chain.revision = 2
            $0.addBlock = nil
        }
        await store.receive(\.delegate.chainChanged)
        #expect(store.state.chain.children(of: nil).count == 2)
    }

    @MainActor
    @Test
    func oneRun_fillsEveryLeaf() async throws {
        // US4 AS1/AS3: three leaves, one run, three results.
        let value = try countValue
        let draws = BlockValue.draws(ReferenceDraws.threeOfFive)
        let store = makeStore(
            ChainEditor.State(chain: branched, source: source),
            runner: .scripted([
                .nodeFinished(filterNode, .success(draws)),
                .nodeFinished(countNode, .success(value)),
                .nodeFinished(leafA, .success(value)),
                .nodeFinished(leafB, .success(value)),
                .finished,
            ])
        )
        let stamp = RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 3)

        await store.send(.runTapped) { $0.isRunning = true }
        await store.receive(\.gameLoaded) {
            $0.dataStates = ["mbnet": .mbnetMock]
            $0.drawSize = 3
            $0.runStamp = stamp
            $0.results = [self.filterNode: .running, self.leafA: .running, self.leafB: .running, self.countNode: .running]
        }
        await store.receive(\.runEvent) { $0.results[self.filterNode] = .value(draws, stamp) }
        await store.receive(\.runEvent) { $0.results[self.countNode] = .value(value, stamp) }
        await store.receive(\.runEvent) { $0.results[self.leafA] = .value(value, stamp) }
        await store.receive(\.runEvent) { $0.results[self.leafB] = .value(value, stamp) }
        await store.receive(\.runEvent) { $0.isRunning = false }

        let leafResults = store.state.chain.leaves.compactMap { store.state.results[$0.id] }
        #expect(leafResults.count == 3)
        #expect(leafResults.allSatisfy { if case .value = $0 { true } else { false } })
    }

    @MainActor
    @Test
    func collapsingANode_hidesItsSubtree_andCountsWhatItHides() async {
        let store = makeStore(ChainEditor.State(chain: branched, source: source))
        #expect(store.state.outline.map(\.id) == [filterNode, leafA, leafB, countNode])

        await store.send(.toggleCollapsed(filterNode)) { $0.collapsed = [self.filterNode] }
        #expect(store.state.outline.map(\.id) == [filterNode, countNode])
        #expect(store.state.hiddenCount(filterNode) == 2)

        await store.send(.toggleCollapsed(filterNode)) { $0.collapsed = [] }
        #expect(store.state.hiddenCount(filterNode) == 0)
    }

    // MARK: - Only sensible chains (US5)

    @MainActor
    @Test
    func nothingCanBeAddedUnderCountAllElements() async {
        let total = UUID(40)
        let chain = Chain(id: UUID(0), name: "Total", revision: 1, nodes: [ChainNode(id: total, parentID: nil, block: .countAllElements)])
        let store = makeStore(ChainEditor.State(chain: chain, source: source))

        #expect(store.state.canAdd(under: total) == false)
        #expect(store.state.canAdd(under: nil))
        await store.send(.addTapped(parent: total))
    }

    @MainActor
    @Test
    func aRefusedAttach_leavesTheChainUnchanged_andSaysWhy() async {
        var state = ChainEditor.State(chain: .countOnlyMock, source: source)
        state.addBlock = AddBlock.State(parentID: countNode, parent: .block(.countUniqueElements), parentOutput: .counts)
        let store = makeStore(state)

        await store.send(\.addBlock.delegate.added, .sortByDate(.ascending)) {
            $0.addBlock = nil
            $0.alert = .attachRefused(needs: [.draws])
        }
        #expect(store.state.chain == .countOnlyMock)
    }

    // MARK: - Edit, re-run, stop (US6)

    /// input → suffix(100) → count, run at revision 3.
    private func ranChain() throws -> ChainEditor.State {
        let chain = Chain(
            id: UUID(0), name: "Recent", revision: 3,
            nodes: [
                ChainNode(id: filterNode, parentID: nil, block: .suffix(100)),
                ChainNode(id: leafA, parentID: filterNode, block: .countUniqueElements),
            ]
        )
        var state = ChainEditor.State(chain: chain, source: source)
        let stamp = RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 3)
        state.results = [filterNode: .value(.draws(ReferenceDraws.threeOfFive), stamp), leafA: .value(try countValue, stamp)]
        state.dataStates = ["mbnet": .mbnetMock]
        state.runStamp = stamp
        return state
    }

    @MainActor
    @Test
    func editingAParameter_marksEveryResultOutOfDate_withoutRunning() async throws {
        // US6 AS1, SC-005
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([])
        let store = makeStore(try ranChain(), storage: storage)

        await store.send(.editTapped(filterNode)) {
            $0.editBlock = BlockParameters.State(
                kind: .suffix, mode: .edit(nodeID: self.filterNode, original: .suffix(100)),
                context: .init(parentSize: .init(count: 3, unit: .draws), drawSize: nil)
            )
        }
        await store.send(\.editBlock.countTextChanged, "50") { $0.editBlock?.countText = "50" }
        await store.send(\.editBlock.confirmTapped)
        await store.receive(\.editBlock.delegate.confirmed, .suffix(50)) {
            $0.chain.nodes[id: self.filterNode]?.block = .suffix(50)
            $0.chain.revision = 4
            $0.editBlock = nil
        }
        await store.receive(\.delegate.chainChanged)
        await store.finish()

        #expect(store.state.freshness(filterNode) == .outOfDate)
        #expect(store.state.freshness(leafA) == .outOfDate)
        #expect(store.state.isRunning == false)
        #expect(storage.value.first?.revision == 4)
    }

    @MainActor
    @Test
    func aLeafAddedAfterARun_readsNotRun_andTheOthersOutOfDate() async throws {
        // US6 AS2
        var state = try ranChain()
        state.addBlock = AddBlock.State(parentID: filterNode, parent: .block(.suffix(100)), parentOutput: .draws)
        let store = makeStore(state)

        await store.send(\.addBlock.delegate.added, .countAllElements) {
            $0.chain.nodes.append(ChainNode(id: UUID(0), parentID: self.filterNode, block: .countAllElements))
            $0.chain.revision = 4
            $0.addBlock = nil
        }
        await store.receive(\.delegate.chainChanged)
        #expect(store.state.results[UUID(0)] == nil)
        #expect(store.state.freshness(leafA) == .outOfDate)
    }

    @MainActor
    @Test
    func removingABlockWithChildren_asksFirst_thenRemovesTheSubtreeAndItsResults() async throws {
        let store = makeStore(try ranChain())

        await store.send(.removeTapped(filterNode)) {
            $0.alert = .confirmRemove(self.filterNode, removing: 2)
        }
        await store.send(\.alert.confirmRemove, filterNode) {
            $0.alert = nil
            $0.chain.nodes = []
            $0.chain.revision = 4
            $0.results = [:]
        }
        await store.receive(\.delegate.chainChanged)
    }

    @MainActor
    @Test
    func removingALeaf_needsNoConfirmation() async throws {
        let store = makeStore(try ranChain())

        await store.send(.removeTapped(leafA)) {
            $0.chain.nodes.remove(id: self.leafA)
            $0.chain.revision = 4
            $0.results[self.leafA] = nil
        }
        await store.receive(\.delegate.chainChanged)
    }

    @MainActor
    @Test
    func aNewRun_stopsTheOneInProgress() async throws {
        // US6 AS3, FR-020: only the latest run's results land.
        let (runner, streams) = ChainRunner.controlled()
        let value = try countValue
        let store = makeStore(ChainEditor.State(chain: .countOnlyMock, source: source), runner: runner)

        await store.send(.runTapped) { $0.isRunning = true }
        await store.receive(\.gameLoaded) {
            $0.dataStates = ["mbnet": .mbnetMock]
            $0.drawSize = 3
            $0.runStamp = self.stamp
            $0.results = [self.countNode: .running]
        }
        await streams.waitForRuns(1)
        await store.send(.runTapped)
        await store.receive(\.gameLoaded)
        await streams.waitForRuns(2)

        streams.value[0].yield(.nodeFinished(countNode, .success(.number(0))))  // the stopped run: ignored
        streams.value[1].yield(.nodeFinished(countNode, .success(value)))
        await store.receive(\.runEvent) { $0.results[self.countNode] = .value(value, self.stamp) }
        streams.value[1].yield(.finished)
        await store.receive(\.runEvent) { $0.isRunning = false }
        for stream in streams.value { stream.finish() }
        await store.finish()

        #expect(store.state.freshness(countNode) == .current)  // US6 AS4: the re-run clears the marks
    }

    // MARK: - Saved results, leaving, drafts (US8)

    @MainActor
    @Test
    func onAppear_loadsSavedResults_andTheStateOfEverySourceTheyCameFrom() async {
        // R13: each saved result is judged against its own source.
        let lottoState = SourceDataState(recordsCount: 5, latestRecord: nil, contentDigest: "lotto")
        let results = LockIsolated<IdentifiedArrayOf<SavedResult>>([.mock(1), .mock(2, source: "lotto", state: lottoState)])
        var sources = SourcesBLogic.mock
        sources.dataStateFor = { $0 == "lotto" ? lottoState : .mbnetMock }
        let store = makeStore(ChainEditor.State(chain: .countOnlyMock, source: source), results: results, blSources: sources)

        await store.send(.onAppear)
        await store.receive(\.loaded) {
            $0.savedResults = [.mock(1), .mock(2, source: "lotto", state: lottoState)]
            $0.dataStates = ["mbnet": .mbnetMock, "lotto": lottoState]
            $0.drawSize = 3
        }
    }

    @MainActor
    @Test
    func openingASavedResult_showsItsOwnSourcesFreshness_andAChangedChain() async {
        // FR-029, FR-030: saved from lotto, opened while mbnet is chosen; the chain moved on since.
        let lottoState = SourceDataState(recordsCount: 5, latestRecord: nil, contentDigest: "lotto")
        let saved = SavedResult.mock(2, source: "lotto", state: lottoState)
        var chain = Chain.countOnlyMock
        chain.revision = 2
        var state = ChainEditor.State(chain: chain, source: source)
        state.savedResults = [saved]
        state.dataStates = ["mbnet": .mbnetMock, "lotto": lottoState]
        let store = makeStore(state)

        await store.send(.savedResultTapped(saved.id)) {
            $0.result = ResultPage.State(value: saved.value, stamp: saved.stamp, freshness: .current, chainChanged: true)
        }
    }

    @MainActor
    @Test
    func aSavedResultOfAMissingSource_readsUnavailable() async {
        let saved = SavedResult.mock(3, source: "gone")
        var state = ChainEditor.State(chain: .countOnlyMock, source: source)
        state.savedResults = [saved]
        state.dataStates = ["mbnet": .mbnetMock, "gone": nil]
        let store = makeStore(state)

        await store.send(.savedResultTapped(saved.id)) {
            $0.result = ResultPage.State(value: saved.value, stamp: saved.stamp, freshness: .sourceUnavailable)
        }
    }

    @MainActor
    @Test
    func savingAnIntermediateBlocksOutput_keepsItsPathSourceAndStamp() async throws {
        // US8 AS2, FR-027, FR-028
        let results = LockIsolated<IdentifiedArrayOf<SavedResult>>([])
        let store = makeStore(try ranChain(), results: results)
        let stamp = RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 3)
        let expected = SavedResult(
            id: UUID(0), chainID: UUID(0), nodeID: filterNode, path: [.suffix(100)],
            value: .draws(ReferenceDraws.threeOfFive), stamp: stamp, savedAt: now
        )

        await store.send(.saveResultTapped(filterNode)) {
            $0.savedResults = [expected]
            $0.savedNodeIDs = [self.filterNode]
        }
        await store.finish()
        #expect(results.value == [expected])
        #expect(store.state.hasUnsavedResults)  // the leaf is still unsaved
    }

    @MainActor
    @Test
    func deletingASavedResult_removesIt() async {
        // US8 AS5
        let results = LockIsolated<IdentifiedArrayOf<SavedResult>>([.mock(1)])
        var state = ChainEditor.State(chain: .countOnlyMock, source: source)
        state.savedResults = [.mock(1)]
        let store = makeStore(state, results: results)

        await store.send(.deleteSavedResultTapped(UUID(1))) { $0.savedResults = [] }
        await store.finish()
        #expect(results.value.isEmpty)
    }

    @MainActor
    @Test
    func aRunAgainstAnotherSource_isStampedWithThatSource() async throws {
        // US8 AS1: the chain runs unchanged; its results name source B.
        let lotto = ChainSource(id: "lotto", name: "Lotto Server")
        let value = try countValue
        let store = makeStore(
            ChainEditor.State(chain: .countOnlyMock, source: lotto),
            runner: .scripted([.nodeFinished(countNode, .success(value)), .finished])
        )
        let stamp = RunStamp(sourceName: "lotto", sourceDisplayName: "Lotto Server", dataState: .mbnetMock, chainRevision: 1)

        await store.send(.runTapped) { $0.isRunning = true }
        await store.receive(\.gameLoaded) {
            $0.dataStates = ["lotto": .mbnetMock]
            $0.drawSize = 3
            $0.runStamp = stamp
            $0.results = [self.countNode: .running]
        }
        await store.receive(\.runEvent) { $0.results = [self.countNode: .value(value, stamp)] }
        await store.receive(\.runEvent) { $0.isRunning = false }
    }

    @MainActor
    @Test
    func leavingWithNothingUnsaved_leavesAtOnce() async {
        let dismissed = LockIsolated(false)
        let store = makeStore(ChainEditor.State(chain: .countOnlyMock, source: source), dismissed: dismissed)

        await store.send(.backTapped)
        await store.finish()
        #expect(dismissed.value)
    }

    @MainActor
    @Test
    func leavingWithUnsavedResults_asksFirst_andCancelStays() async throws {
        // US8 AS6, FR-032
        let dismissed = LockIsolated(false)
        let store = makeStore(try ranChain(), dismissed: dismissed)

        await store.send(.backTapped) { $0.alert = .leaveWithUnsaved }
        await store.send(\.alert.dismiss) { $0.alert = nil }
        #expect(dismissed.value == false)
    }

    @MainActor
    @Test
    func saveAndLeave_savesEveryUnsavedResult_dropsTheDraft_andLeaves() async throws {
        let results = LockIsolated<IdentifiedArrayOf<SavedResult>>([])
        let drafts = LockIsolated<[Chain.ID: ChainDraft]>([UUID(0): .mock])
        let dismissed = LockIsolated(false)
        var state = try ranChain()
        state.alert = .leaveWithUnsaved
        let store = makeStore(state, results: results, drafts: drafts, dismissed: dismissed)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(\.alert.saveAndLeave)
        await store.finish()
        #expect(Set(results.value.map(\.nodeID)) == [filterNode, leafA])
        #expect(drafts.value[UUID(0)] == nil)
        #expect(dismissed.value)
    }

    @MainActor
    @Test
    func discardAndLeave_dropsTheDraft_andLeaves() async throws {
        let drafts = LockIsolated<[Chain.ID: ChainDraft]>([UUID(0): .mock])
        let dismissed = LockIsolated(false)
        var state = try ranChain()
        state.alert = .leaveWithUnsaved
        let store = makeStore(state, drafts: drafts, dismissed: dismissed)

        await store.send(\.alert.discardAndLeave) { $0.alert = nil }
        await store.finish()
        #expect(drafts.value.isEmpty)
        #expect(dismissed.value)
    }

    @MainActor
    @Test
    func goingToTheBackground_keepsUnsavedResultsAsADraft() async throws {
        // FR-031
        let drafts = LockIsolated<[Chain.ID: ChainDraft]>([:])
        let store = makeStore(try ranChain(), drafts: drafts)

        await store.send(.scenePhaseChanged(.background))
        await store.finish()
        let draft = try #require(drafts.value[UUID(0)])
        #expect(draft.createdAt == now)
        #expect(Set(draft.results.keys) == [filterNode, leafA])
    }

    @MainActor
    @Test
    func goingToTheBackground_withNothingUnsaved_writesNoDraft() async {
        let drafts = LockIsolated<[Chain.ID: ChainDraft]>([:])
        let store = makeStore(ChainEditor.State(chain: .countOnlyMock, source: source), drafts: drafts)

        await store.send(.scenePhaseChanged(.background))
        await store.send(.scenePhaseChanged(.active))
        await store.finish()
        #expect(drafts.value.isEmpty)
    }

    @MainActor
    @Test
    func reopeningAChainWithADraft_offersToRestoreIt() async {
        // US8 AS7
        let drafts = LockIsolated<[Chain.ID: ChainDraft]>([Chain.countOnlyMock.id: .mock])
        let store = makeStore(ChainEditor.State(chain: .countOnlyMock, source: source), drafts: drafts)

        await store.send(.onAppear)
        await store.receive(\.loaded) {
            $0.dataStates = ["mbnet": .mbnetMock]
            $0.drawSize = 3
            $0.pendingDraft = .mock
            $0.alert = .restoreDraft
        }
        await store.send(\.alert.restoreDraft) {
            $0.alert = nil
            $0.pendingDraft = nil
            $0.results = ChainDraft.mock.results
        }
        await store.finish()
        #expect(drafts.value.isEmpty)
        #expect(store.state.freshness(countNode) == .current)  // restored results keep their own stamps
    }

    @MainActor
    @Test
    func decliningTheDraft_deletesIt_andLeavesNotRun() async {
        let drafts = LockIsolated<[Chain.ID: ChainDraft]>([Chain.countOnlyMock.id: .mock])
        var state = ChainEditor.State(chain: .countOnlyMock, source: source)
        state.pendingDraft = .mock
        state.alert = .restoreDraft
        let store = makeStore(state, drafts: drafts)

        await store.send(\.alert.declineDraft) {
            $0.alert = nil
            $0.pendingDraft = nil
        }
        await store.finish()
        #expect(drafts.value.isEmpty)
        #expect(store.state.results.isEmpty)
    }

    // MARK: - Parameter context (spec 006, LTA-33)

    @MainActor
    @Test
    func onAppear_withoutStoredDraws_leavesTheDrawSizeUnknown() async {
        var sources = SourcesBLogic.failing()
        sources.dataStateFor = { _ in .mbnetMock }
        let store = makeStore(ChainEditor.State(chain: .emptyMock, source: source), blSources: sources)

        await store.send(.onAppear)
        await store.receive(\.loaded) {
            $0.dataStates = ["mbnet": .mbnetMock]
        }
        #expect(store.state.drawSize == nil)
    }

    @MainActor
    @Test
    func aFailedRead_leavesTheDrawSizeAsItWas() async throws {
        var state = ChainEditor.State(chain: .countOnlyMock, source: source)
        state.drawSize = 6
        let store = makeStore(state, blSources: .failing(read: .unreadableStoredDraws))

        await store.send(.runTapped) { $0.isRunning = true }
        await store.receive(\.gameLoaded) {
            $0.isRunning = false
            $0.alert = .readFailed(.unreadableStoredDraws, sourceName: "MBNet Server")
        }
    }

    @MainActor
    @Test
    func addingUnderTheSource_passesItsRecordCount_andTheDrawSize() async {
        var state = ChainEditor.State(chain: .emptyMock, source: source)
        state.dataStates = ["mbnet": .mbnetMock]
        state.drawSize = 3
        let store = makeStore(state)

        await store.send(.addTapped(parent: nil)) {
            $0.addBlock = AddBlock.State(
                parentID: nil, parent: .input(sourceName: "MBNet Server"), parentOutput: .draws,
                context: .init(parentSize: .init(count: 3, unit: .draws), drawSize: 3)
            )
        }
    }

    @MainActor
    @Test
    func addingUnderABlockWithDraws_passesHowManyDrawsItKept() async throws {
        var state = try ranChain()
        state.results[filterNode] = .value(.draws(ReferenceDraws.threeOfFive), stamp)
        let store = makeStore(state)

        await store.send(.addTapped(parent: filterNode)) {
            $0.addBlock = AddBlock.State(
                parentID: self.filterNode, parent: .block(.suffix(100)), parentOutput: .draws,
                context: .init(parentSize: .init(count: ReferenceDraws.threeOfFive.entries.count, unit: .draws), drawSize: nil)
            )
        }
    }

    @MainActor
    @Test
    func addingUnderABlockWithCounts_passesHowManyItemsItCounted() async throws {
        let store = makeStore(try ranChain())

        await store.send(.addTapped(parent: leafA)) {
            $0.addBlock = AddBlock.State(
                parentID: self.leafA, parent: .block(.countUniqueElements), parentOutput: .counts,
                context: .init(parentSize: .init(count: 5, unit: .items), drawSize: nil)
            )
        }
    }

    @MainActor
    @Test(arguments: [NodeResult.notRun, .running, .failed(.upstreamFailed, RunStamp(sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .mbnetMock, chainRevision: 3))])
    func addingUnderABlockWithoutAValue_knowsNoParentSize(_ result: NodeResult) async throws {
        var state = try ranChain()
        state.results[filterNode] = result
        let store = makeStore(state)

        await store.send(.addTapped(parent: filterNode)) {
            $0.addBlock = AddBlock.State(parentID: self.filterNode, parent: .block(.suffix(100)), parentOutput: .draws)
        }
    }

    @MainActor
    @Test
    func anOutOfDateParent_stillGivesItsLastKnownSize() async throws {
        var state = try ranChain()
        state.chain = try state.chain.updating(filterNode, to: .suffix(50))  // bumps the revision
        let store = makeStore(state)
        #expect(store.state.freshness(leafA) == .outOfDate)

        await store.send(.addTapped(parent: leafA)) {
            $0.addBlock = AddBlock.State(
                parentID: self.leafA, parent: .block(.countUniqueElements), parentOutput: .counts,
                context: .init(parentSize: .init(count: 5, unit: .items), drawSize: nil)
            )
        }
    }

    @MainActor
    @Test
    func editingABlock_passesItsParentsSize_andTheDrawSize() async throws {
        let chain = Chain(
            id: UUID(0), name: "Z", revision: 1,
            nodes: [
                ChainNode(id: filterNode, parentID: nil, block: .suffix(100)),
                ChainNode(id: leafA, parentID: filterNode, block: .countUniqueSubCombinations(z: 2)),
            ]
        )
        var state = ChainEditor.State(chain: chain, source: source)
        state.results = [filterNode: .value(.draws(ReferenceDraws.threeOfFive), stamp)]
        state.drawSize = 3
        let store = makeStore(state)

        await store.send(.editTapped(leafA)) {
            $0.editBlock = BlockParameters.State(
                kind: .countUniqueSubCombinations, mode: .edit(nodeID: self.leafA, original: .countUniqueSubCombinations(z: 2)),
                context: .init(parentSize: .init(count: ReferenceDraws.threeOfFive.entries.count, unit: .draws), drawSize: 3)
            )
        }
    }

    @MainActor
    @Test
    func aLateLoadWithoutDraws_keepsTheDrawSizeARunFound() async {
        var state = ChainEditor.State(chain: .emptyMock, source: source)
        state.drawSize = 6
        let store = makeStore(state)

        await store.send(.loaded(savedResults: [], draft: nil, dataStates: [:], drawSize: nil))
        #expect(store.state.drawSize == 6)
    }

    @MainActor
    @Test
    func eachRow_hasOneStatus_forItsLookAndItsReading() throws {
        var state = try ranChain()
        #expect(state.rowStatus(filterNode) == .value(.draws(count: 3), isStale: false))
        state.results[leafA] = .running
        #expect(state.rowStatus(leafA) == .running)
        state.results[leafA] = .failed(.upstreamFailed, stamp)
        #expect(state.rowStatus(leafA) == .failed(.upstreamFailed))
        state.results[leafA] = nil
        #expect(state.rowStatus(leafA) == .notRun)
        state.chain = try state.chain.updating(filterNode, to: .suffix(50))
        #expect(state.rowStatus(filterNode) == .value(.draws(count: 3), isStale: true))
    }
}
