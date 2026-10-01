//
//  AddBlockTests.swift
//  lottoApp2Tests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import lottoApp2

struct AddBlock_Tests {

    private func addBlock(parentOutput: ValueKind = .draws) -> AddBlock.State {
        AddBlock.State(parentID: nil, parent: .input(sourceName: "MBNet Server"), parentOutput: parentOutput)
    }

    @MainActor
    @Test
    func theCatalogue_listsEveryKind() {
        #expect(addBlock().catalogue == ProcessingBlockKind.allCases)
    }

    @MainActor
    @Test
    func choosingAKind_opensItsParameterStep_withItsDefaultBlock() async {
        // LTA-22: every block goes through step 2, even one without parameters.
        let store = TestStore(initialState: addBlock()) { AddBlock() }

        await store.send(.kindTapped(.countUniqueElements)) {
            $0.parameters = BlockParameters.State(kind: .countUniqueElements, mode: .add)
        }
    }

    @MainActor
    @Test
    func confirmingTheParameterStep_addsTheBlock() async {
        var state = addBlock()
        state.parameters = BlockParameters.State(kind: .countUniqueElements, mode: .add)
        let store = TestStore(initialState: state) { AddBlock() }

        await store.send(\.parameters.confirmTapped)
        await store.receive(\.parameters.delegate.confirmed, .countUniqueElements)
        await store.receive(\.delegate.added, .countUniqueElements)
    }

    @MainActor
    @Test
    func cancelling_dismissesWithoutAdding() async {
        let dismissed = LockIsolated(false)
        let store = TestStore(initialState: addBlock()) { AddBlock() } withDependencies: {
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.cancelTapped)
        #expect(dismissed.value)
    }

    @MainActor
    @Test
    func aBlockWithoutParameters_isAlwaysValid() {
        let state = BlockParameters.State(kind: .countUniqueElements, mode: .add)
        #expect(state.block == .countUniqueElements)
        #expect(state.isValid)
    }

    // MARK: - Parameters (US2, FR-006, FR-009)

    @MainActor
    @Test
    func aFilter_startsAtItsDefaultX() {
        let state = BlockParameters.State(kind: .suffix, mode: .add)
        #expect(state.countText == "10")
        #expect(state.block == .suffix(10))
        #expect(state.isValid)
    }

    @MainActor
    @Test
    func x_mustBeAWholeNumberOfZeroOrMore() async {
        let store = TestStore(initialState: BlockParameters.State(kind: .suffix, mode: .add)) { BlockParameters() }

        await store.send(.countTextChanged("-1")) { $0.countText = "-1" }
        #expect(store.state.isValid == false)
        await store.send(.confirmTapped)  // refused: nothing is sent

        await store.send(.countTextChanged("2.5")) { $0.countText = "2.5" }
        #expect(store.state.isValid == false)

        await store.send(.countTextChanged("")) { $0.countText = "" }
        #expect(store.state.isValid == false)

        await store.send(.countTextChanged("100")) { $0.countText = "100" }
        await store.send(.confirmTapped)
        await store.receive(\.delegate.confirmed, .suffix(100))
    }

    @MainActor
    @Test
    func theStepper_movesXByOne_andStopsAtZero() async {
        var state = BlockParameters.State(kind: .prefix, mode: .add)
        state.countText = "1"
        let store = TestStore(initialState: state) { BlockParameters() }

        await store.send(.incrementTapped) { $0.countText = "2" }
        await store.send(.decrementTapped) { $0.countText = "1" }
        await store.send(.decrementTapped) { $0.countText = "0" }
        #expect(store.state.canDecrement == false)
        await store.send(.decrementTapped)
    }

    @MainActor
    @Test
    func aSort_takesADirection() async {
        // LTA-22 defaults: date and index ascending.
        let store = TestStore(initialState: BlockParameters.State(kind: .sortByDate, mode: .add)) { BlockParameters() }
        #expect(store.state.block == .sortByDate(.ascending))

        await store.send(.directionChanged(.descending)) { $0.direction = .descending }
        await store.send(.confirmTapped)
        await store.receive(\.delegate.confirmed, .sortByDate(.descending))
    }

    @MainActor
    @Test
    func choosingAFilter_opensItsParameterStep() async {
        let store = TestStore(initialState: addBlock()) { AddBlock() }

        await store.send(.kindTapped(.suffix)) {
            $0.parameters = BlockParameters.State(kind: .suffix, mode: .add)
        }
    }

    // MARK: - Availability (US5, FR-015)

    @MainActor
    @Test
    func underDraws_sortByCountIsUnavailable_needingCounts() {
        let state = addBlock(parentOutput: .draws)
        #expect(state.availability(.sortByCount) == .needs([.counts]))
        #expect(state.availability(.sortByDate) == .available)
        #expect(state.availability(.suffix) == .available)
    }

    @MainActor
    @Test
    func underCounts_drawBlocksAreUnavailable_needingDraws() {
        let state = addBlock(parentOutput: .counts)
        #expect(state.availability(.sortByDate) == .needs([.draws]))
        #expect(state.availability(.countUniqueElements) == .needs([.draws]))
        #expect(state.availability(.sortByCount) == .available)
        #expect(state.availability(.prefix) == .available)
    }

    @MainActor
    @Test
    func choosingAnUnavailableKind_doesNothing() async {
        let store = TestStore(initialState: addBlock(parentOutput: .draws)) { AddBlock() }
        await store.send(.kindTapped(.sortByCount))
    }

    // MARK: - Edit mode (US6)

    @MainActor
    @Test
    func editMode_startsFromTheBlocksCurrentParameters_andConfirmsTheEdit() async {
        let id = UUID(7)
        let store = TestStore(
            initialState: BlockParameters.State(kind: .suffix, mode: .edit(nodeID: id, original: .suffix(100)))
        ) { BlockParameters() }
        #expect(store.state.countText == "100")

        await store.send(.countTextChanged("50")) { $0.countText = "50" }
        await store.send(.confirmTapped)
        await store.receive(\.delegate.confirmed, .suffix(50))
    }

    @MainActor
    @Test
    func editMode_keepsTheSortDirection() {
        let state = BlockParameters.State(kind: .sortByCount, mode: .edit(nodeID: UUID(7), original: .sortByCount(.ascending)))
        #expect(state.block == .sortByCount(.ascending))
    }

    // MARK: - Sub-combination size (US7)

    @MainActor
    @Test
    func z_startsAtTwo_andMustBeTwoOrMore() async {
        let store = TestStore(initialState: BlockParameters.State(kind: .countUniqueSubCombinations, mode: .add)) {
            BlockParameters()
        }
        #expect(store.state.parameter == .size)
        #expect(store.state.block == .countUniqueSubCombinations(z: 2))

        await store.send(.countTextChanged("1")) { $0.countText = "1" }
        #expect(store.state.isValid == false)
        #expect(store.state.canDecrement == false)

        await store.send(.countTextChanged("3")) { $0.countText = "3" }
        await store.send(.confirmTapped)
        await store.receive(\.delegate.confirmed, .countUniqueSubCombinations(z: 3))
    }

    // MARK: - Parameter context (spec 006, LTA-33)

    @MainActor
    @Test
    func theContext_defaultsToUnknown() {
        let state = BlockParameters.State(kind: .prefix, mode: .add)
        #expect(state.context == .unknown)
        #expect(state.context.parentSize == nil)
        #expect(state.context.drawSize == nil)
    }

    @MainActor
    @Test
    func choosingAKind_passesTheSheetsContextToTheParameterStep() async {
        let context = BlockParameters.Context(parentSize: .init(count: 7012, unit: .draws), drawSize: 6)
        let store = TestStore(
            initialState: AddBlock.State(
                parentID: nil, parent: .input(sourceName: "MBNet Server"), parentOutput: .draws, context: context
            )
        ) { AddBlock() }

        await store.send(.kindTapped(.prefix)) {
            $0.parameters = BlockParameters.State(kind: .prefix, mode: .add, context: context)
        }
    }

    // MARK: - Hints (spec 006 US1)

    private let sevenThousandDraws = BlockParameters.Context(parentSize: .init(count: 7012, unit: .draws), drawSize: 6)

    @MainActor
    @Test
    func aFilter_underAParentOfKnownSize_hintsAtIt() {
        let state = BlockParameters.State(kind: .prefix, mode: .add, context: sevenThousandDraws)
        #expect(state.hint == .parentSize(.init(count: 7012, unit: .draws)))
    }

    @MainActor
    @Test
    func aFilter_underCounts_hintsInItems() {
        let context = BlockParameters.Context(parentSize: .init(count: 49, unit: .items), drawSize: nil)
        let state = BlockParameters.State(kind: .dropFirst, mode: .add, context: context)
        #expect(state.hint == .parentSize(.init(count: 49, unit: .items)))
    }

    @MainActor
    @Test
    func aFilter_underAParentOfUnknownSize_hasNoHint() {
        #expect(BlockParameters.State(kind: .suffix, mode: .add).hint == nil)
    }

    @MainActor
    @Test(arguments: [ProcessingBlockKind.sortByCount, .countUniqueSubCombinations, .countUniqueElements])
    func onlyX_hintsAtTheParentsSize(_ kind: ProcessingBlockKind) {
        #expect(BlockParameters.State(kind: kind, mode: .add, context: sevenThousandDraws).hint == nil)
    }

    @MainActor
    @Test
    func editing_hintsAtTheOriginalValue_whileItChanges() async {
        let store = TestStore(
            initialState: BlockParameters.State(
                kind: .suffix, mode: .edit(nodeID: UUID(7), original: .suffix(100)), context: sevenThousandDraws
            )
        ) { BlockParameters() }
        #expect(store.state.hint == .was(.suffix(100)))

        await store.send(.countTextChanged("50")) { $0.countText = "50" }
        #expect(store.state.hint == .was(.suffix(100)))
    }

    @MainActor
    @Test
    func editingASort_hintsAtTheOriginalDirection() {
        let state = BlockParameters.State(kind: .sortByCount, mode: .edit(nodeID: UUID(7), original: .sortByCount(.descending)))
        #expect(state.hint == .was(.sortByCount(.descending)))
    }

    @MainActor
    @Test
    func editingABlockWithoutParameters_hasNoHint() {
        let state = BlockParameters.State(kind: .countUniqueElements, mode: .edit(nodeID: UUID(7), original: .countUniqueElements))
        #expect(state.hint == nil)
    }

    // MARK: - Direction preview (spec 006 FR-004)

    @MainActor
    @Test
    func sortByCount_previewsFrequency_andFollowsTheDirection() async {
        let store = TestStore(initialState: BlockParameters.State(kind: .sortByCount, mode: .add)) { BlockParameters() }
        #expect(store.state.directionPreview == .mostFrequent)

        await store.send(.directionChanged(.ascending)) { $0.direction = .ascending }
        #expect(store.state.directionPreview == .leastFrequent)
    }

    @MainActor
    @Test
    func sortByDateAndIndex_previewTheirOrder() {
        var date = BlockParameters.State(kind: .sortByDate, mode: .add)
        #expect(date.directionPreview == .oldest)
        date.direction = .descending
        #expect(date.directionPreview == .newest)

        var index = BlockParameters.State(kind: .sortByIndex, mode: .add)
        #expect(index.directionPreview == .lowestIndex)
        index.direction = .descending
        #expect(index.directionPreview == .highestIndex)
    }

    @MainActor
    @Test
    func nonSorts_haveNoDirectionPreview() {
        #expect(BlockParameters.State(kind: .prefix, mode: .add).directionPreview == nil)
        #expect(BlockParameters.State(kind: .countUniqueElements, mode: .add).directionPreview == nil)
    }

    // MARK: - z bound (spec 006 US2)

    private func zStep(drawSize: Int?, text: String) -> BlockParameters.State {
        var state = BlockParameters.State(
            kind: .countUniqueSubCombinations, mode: .add, context: .init(parentSize: nil, drawSize: drawSize)
        )
        state.countText = text
        return state
    }

    @MainActor
    @Test
    func z_belowTheDrawSize_isValid_andCapsTheStepper() {
        let state = zStep(drawSize: 6, text: "5")
        #expect(state.isValid)
        #expect(state.invalidReason == nil)
        #expect(state.canIncrement == false)
    }

    @MainActor
    @Test(arguments: ["6", "7", "1", ""])
    func z_outsideTwoToDrawSizeMinusOne_isRefused(_ text: String) async {
        let store = TestStore(initialState: zStep(drawSize: 6, text: text)) { BlockParameters() }
        #expect(store.state.isValid == false)
        #expect(store.state.invalidReason == .range(2, 5))
        await store.send(.confirmTapped)  // refused: nothing is sent
    }

    @MainActor
    @Test
    func theZStepper_stopsBelowTheDrawSize() async {
        let store = TestStore(initialState: zStep(drawSize: 6, text: "4")) { BlockParameters() }
        #expect(store.state.canIncrement)

        await store.send(.incrementTapped) { $0.countText = "5" }
        #expect(store.state.canIncrement == false)
        await store.send(.incrementTapped)
    }

    @MainActor
    @Test
    func withAnUnknownDrawSize_onlyTwoOrMoreIsChecked() {
        let large = zStep(drawSize: nil, text: "6")
        #expect(large.isValid)
        #expect(large.canIncrement)
        #expect(zStep(drawSize: nil, text: "1").invalidReason == .atLeast(2))
    }

    @MainActor
    @Test(arguments: ["2", "1", "3"])
    func withDrawsOfTwo_noZFits(_ text: String) {
        let state = zStep(drawSize: 2, text: text)
        #expect(state.isValid == false)
        #expect(state.invalidReason == .drawsTooSmall)
        #expect(state.canIncrement == false)
    }

    @MainActor
    @Test
    func editingAZAboveTheBound_opensRefused() {
        let state = BlockParameters.State(
            kind: .countUniqueSubCombinations, mode: .edit(nodeID: UUID(7), original: .countUniqueSubCombinations(z: 7)),
            context: .init(parentSize: nil, drawSize: 6)
        )
        #expect(state.countText == "7")
        #expect(state.invalidReason == .range(2, 5))
    }

    @MainActor
    @Test
    func x_ignoresTheDrawSize() {
        var state = BlockParameters.State(kind: .prefix, mode: .add, context: sevenThousandDraws)
        state.countText = "-3"
        #expect(state.invalidReason == .atLeast(0))
        state.countText = "10000"
        #expect(state.isValid)
        #expect(state.canIncrement)
    }

    @MainActor
    @Test
    func aZAboveTheBound_stepsDownIntoRange_andPlusStaysDisabled() async {
        let store = TestStore(initialState: zStep(drawSize: 6, text: "7")) { BlockParameters() }
        #expect(store.state.canIncrement == false)
        #expect(store.state.canDecrement)

        await store.send(.incrementTapped)
        await store.send(.decrementTapped) { $0.countText = "5" }
        #expect(store.state.isValid)
    }
}
