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
            $0.hasLoaded = true
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

    // MARK: - Renaming (spec 006 FR-017, FR-020)

    private var oneChain: BlocksPage.State {
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.chains = [.countOnlyMock]
        return state
    }

    @MainActor
    @Test
    func renamingFromTheSwipe_savesTheNewName_withoutChangingTheRevision() async {
        // The leading swipe, the long-press item and the accessibility action all send `renameTapped`.
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([.countOnlyMock])
        let store = makeStore(oneChain, storage: storage)

        await store.send(.renameTapped(Chain.countOnlyMock.id)) {
            $0.renaming = Chain.countOnlyMock.id
            $0.renameDraft = Chain.countOnlyMock.name
        }
        await store.send(.renameDraftChanged("Top numbers")) { $0.renameDraft = "Top numbers" }
        await store.send(.renameConfirmed) {
            $0.renaming = nil
            $0.renameDraft = ""
            $0.chains[id: Chain.countOnlyMock.id]?.name = "Top numbers"
        }
        await store.finish()
        #expect(storage.value[id: Chain.countOnlyMock.id]?.name == "Top numbers")
        #expect(storage.value[id: Chain.countOnlyMock.id]?.revision == Chain.countOnlyMock.revision)
    }

    @MainActor
    @Test(arguments: ["   ", ""])
    func renamingToBlank_isIgnored(_ draft: String) async {
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([.countOnlyMock])
        var state = oneChain
        state.renaming = Chain.countOnlyMock.id
        state.renameDraft = draft
        let store = makeStore(state, storage: storage)

        await store.send(.renameConfirmed) {
            $0.renaming = nil
            $0.renameDraft = ""
        }
        #expect(storage.value[id: Chain.countOnlyMock.id]?.name == Chain.countOnlyMock.name)
    }

    @MainActor
    @Test
    func renamingToTheSameName_isIgnored() async {
        var state = oneChain
        state.renaming = Chain.countOnlyMock.id
        state.renameDraft = " \(Chain.countOnlyMock.name) "
        let store = makeStore(state, storage: .init([.countOnlyMock]))

        await store.send(.renameConfirmed) {
            $0.renaming = nil
            $0.renameDraft = ""
        }
    }

    @MainActor
    @Test
    func cancellingARename_changesNothing() async {
        var state = oneChain
        state.renaming = Chain.countOnlyMock.id
        state.renameDraft = "Top numbers"
        let store = makeStore(state, storage: .init([.countOnlyMock]))

        await store.send(.renameCancelled) {
            $0.renaming = nil
            $0.renameDraft = ""
        }
    }

    @MainActor
    @Test
    func renamingAnUnknownChain_doesNothing() async {
        let store = makeStore(oneChain, storage: .init([.countOnlyMock]))
        await store.send(.renameTapped(UUID(99)))
    }

    @MainActor
    @Test
    func confirmingARename_afterTheChainWasDeleted_savesNothing() async {
        let storage = LockIsolated<IdentifiedArrayOf<Chain>>([])
        var state = BlocksPage.State(sourceID: "mbnet", sourceName: "MBNet Server")
        state.renaming = Chain.countOnlyMock.id
        state.renameDraft = "Top numbers"
        let store = makeStore(state, storage: storage)

        await store.send(.renameConfirmed) {
            $0.renaming = nil
            $0.renameDraft = ""
        }
        await store.finish()
        #expect(storage.value.isEmpty)
    }

    // MARK: - Empty state (spec 006 FR-016)

    @MainActor
    @Test
    func theEmptyState_waitsForTheList_andShowsOnlyWithoutChains() async {
        let store = makeStore(storage: .init([]))
        #expect(store.state.showsEmptyState == false)  // not before the chains have been read

        await store.send(.chainsLoaded([])) { $0.hasLoaded = true }
        #expect(store.state.showsEmptyState)

        await store.send(.chainsLoaded([.countOnlyMock])) { $0.chains = [.countOnlyMock] }
        #expect(store.state.showsEmptyState == false)
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
        #expect(store.state.showsEmptyState == false)  // this list was never loaded
    }

    @MainActor
    @Test
    func deletingTheLastChain_showsTheEmptyState() async {
        var state = oneChain
        state.hasLoaded = true
        state.alert = .deleteChain(.countOnlyMock, savedCount: 0, hasDraft: false)
        let store = makeStore(state, storage: .init([.countOnlyMock]))

        await store.send(\.alert.confirmDelete, Chain.countOnlyMock.id) {
            $0.alert = nil
            $0.chains = []
        }
        #expect(store.state.showsEmptyState)
        await store.finish()
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
