//
//  BlocksPageTests.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import lottoApp2

struct BlocksPage_Tests {

    private let source = ChainSource(id: "mbnet", name: "MBNet Server")

    @MainActor
    private func makeStore(
        _ state: BlocksPage.State = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server"),
        storage: LockIsolated<IdentifiedArrayOf<Chain>>
    ) -> TestStoreOf<BlocksPage> {
        TestStore(initialState: state) { BlocksPage() } withDependencies: {
            $0.chainsRepo = .inMemory(storage)
            $0.uuid = .incrementing
        }
    }

    @MainActor
    @Test
    func initialState_carriesTheChosenSource() {
        let state = BlocksPage.State(sourceID: "lotto", sourceName: "Lotto Server")
        #expect(state.sourceID == "lotto")
        #expect(state.sourceName == "Lotto Server")
        #expect(state.chains.isEmpty)
    }

    @MainActor
    @Test
    func onAppear_listsTheSavedChains() async {
        // FR-017: saved chains are listed.
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([.countOnlyMock])
        let store = makeStore(storage: storage)

        await store.send(.onAppear)
        await store.receive(\.chainsLoaded) {
            $0.chains = [.countOnlyMock]
        }
    }

    @MainActor
    @Test
    func newChain_isCreatedSavedAndOpened() async {
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([])
        let store = makeStore(storage: storage)
        let created = Chain.empty(id: UUID(0), name: BlocksPage.defaultChainName)

        await store.send(.newChainTapped) {
            $0.chains = [created]
            $0.editor = ChainEditor.State(chain: created, source: self.source)
        }
        await store.finish()
        #expect(storage.value[id: created.id] == created)
    }

    @MainActor
    @Test
    func tappingAChain_opensItAgainstTheChosenSource() async {
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.chains = [.countOnlyMock]
        let store = makeStore(state, storage: .init([.countOnlyMock]))

        await store.send(.chainTapped(Chain.countOnlyMock.id)) {
            $0.editor = ChainEditor.State(chain: .countOnlyMock, source: self.source)
        }
    }

    @MainActor
    @Test
    func renamingAChain_savesTheNewName_withoutChangingTheRevision() async {
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.chains = [.countOnlyMock]
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([.countOnlyMock])
        let store = makeStore(state, storage: storage)

        await store.send(.renameChain(Chain.countOnlyMock.id, "Top numbers")) {
            $0.chains[id: Chain.countOnlyMock.id]?.name = "Top numbers"
        }
        await store.finish()
        #expect(storage.value[id: Chain.countOnlyMock.id]?.name == "Top numbers")
        #expect(storage.value[id: Chain.countOnlyMock.id]?.revision == Chain.countOnlyMock.revision)
    }

    @MainActor
    @Test
    func renamingToBlank_isIgnored() async {
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.chains = [.countOnlyMock]
        let store = makeStore(state, storage: .init([.countOnlyMock]))

        await store.send(.renameChain(Chain.countOnlyMock.id, "   "))
    }

    @MainActor
    @Test
    func deletingAChain_asksFirst_thenDeletesIt() async {
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.chains = [.countOnlyMock]
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([.countOnlyMock])
        let store = makeStore(state, storage: storage)

        await store.send(.deleteChainTapped(Chain.countOnlyMock.id))
        await store.receive(\.deleteConfirmationLoaded) {
            $0.alert = .deleteChain(.countOnlyMock, savedCount: 0, hasDraft: false)
        }
        await store.send(\.alert.confirmDelete, Chain.countOnlyMock.id) {
            $0.alert = nil
            $0.chains = []
        }
        await store.finish()
        #expect(storage.value.isEmpty)
    }

    @MainActor
    @Test
    func aChangedChain_replacesItsRow() async {
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.chains = [.emptyMock]
        state.editor = ChainEditor.State(chain: .emptyMock, source: source)
        let store = makeStore(state, storage: .init([.emptyMock]))

        await store.send(\.editor.delegate.chainChanged, .countOnlyMock) {
            $0.chains = [.countOnlyMock]
        }
    }

    @MainActor
    @Test
    func leavingTheChainMidRun_stopsTheRun() async {
        // Spec Edge Cases: a run in progress when the person leaves stops and produces no results. `ifLet`
        // cancels the editor's effects on dismissal (research R11), so there is no cancel code to test elsewhere.
        let (runner, streams) = ChainRunner.controlled()
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.chains = [.countOnlyMock]
        state.editor = ChainEditor.State(chain: .countOnlyMock, source: source)
        let store = TestStore(initialState: state) { BlocksPage() } withDependencies: {
            $0.chainsRepo = .inMemory(.init([.countOnlyMock]))
            $0.chainRunner = runner
            $0.blSources = .mock
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(\.editor.runTapped)
        await store.receive(\.editor.gameLoaded)
        await streams.waitForRuns(1)
        await store.send(\.editor.dismiss) { $0.editor = nil }

        streams.value.first?.yield(.nodeFinished(UUID(10), .success(.number(1))))
        streams.value.first?.finish()
        await store.finish()
        #expect(store.state.editor == nil)
        #expect(store.state.chains == [.countOnlyMock])
    }

    // MARK: - Deleting with saved results and a draft (FR-017, FR-032)

    @MainActor
    @Test
    func theDeleteWarning_namesTheSavedResults_andADraft() async {
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.chains = [.countOnlyMock]
        let results = LockIsolated<IdentifiedArrayOf<SavedResult>>([.mock(1), .mock(2), .mock(3)])
        let drafts = LockIsolated<[Chain.ID: ChainDraft]>([Chain.countOnlyMock.id: .mock])
        let store = TestStore(initialState: state) { BlocksPage() } withDependencies: {
            $0.chainsRepo = .inMemory(.init([.countOnlyMock]), results: results, drafts: drafts)
        }

        await store.send(.deleteChainTapped(Chain.countOnlyMock.id))
        await store.receive(\.deleteConfirmationLoaded) {
            $0.alert = .deleteChain(.countOnlyMock, savedCount: 3, hasDraft: true)
        }
        await store.send(\.alert.dismiss) { $0.alert = nil }  // cancelling keeps everything
        #expect(results.value.count == 3)
        #expect(drafts.value.count == 1)
    }
}
