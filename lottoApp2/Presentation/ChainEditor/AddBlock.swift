//
//  AddBlock.swift
//  lottoApp2
//
//  The add-block sheet (LTA-22): step 1 picks a block from the catalogue, step 2 (`BlockParameters`) sets
//  its parameters and confirms.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AddBlock {
    /// What the new block will sit under, for the sheet's "Under …" line.
    enum Parent: Equatable {
        case input(sourceName: String)
        case block(Block)
    }

    /// Whether a kind can go under this parent (FR-010, FR-015). Unavailable kinds stay listed, with why.
    enum Availability: Equatable {
        case available
        case needs(Set<ValueKind>)
    }

    @ObservableState
    struct State: Equatable {
        let parentID: ChainNode.ID?
        let parent: Parent
        /// What the parent outputs — the kind the new block must take (FR-010).
        let parentOutput: ValueKind
        /// Every kind the app offers, in catalogue order.
        var catalogue: [ProcessingBlockKind] = ProcessingBlockKind.allCases
        @Presents var parameters: BlockParameters.State?

        init(parentID: ChainNode.ID?, parent: Parent, parentOutput: ValueKind) {
            self.parentID = parentID
            self.parent = parent
            self.parentOutput = parentOutput
        }

        func availability(_ kind: ProcessingBlockKind) -> Availability {
            let accepts = kind.defaultBlock.accepts
            return accepts.contains(parentOutput) ? .available : .needs(accepts)
        }
    }

    enum Action {
        case kindTapped(ProcessingBlockKind)
        case cancelTapped
        case parameters(PresentationAction<BlockParameters.Action>)
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case added(Block)
        }
    }

    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .kindTapped(let kind):
                guard state.availability(kind) == .available else { return .none }
                state.parameters = BlockParameters.State(kind: kind, mode: .add)
                return .none

            case .cancelTapped:
                return .run { [dismiss] _ in await dismiss() }

            case .parameters(.presented(.delegate(.confirmed(let block)))):
                // The chain editor attaches the block and closes the sheet.
                return .send(.delegate(.added(block)))

            case .parameters, .delegate:
                return .none
            }
        }
        .ifLet(\.$parameters, action: \.parameters) {
            BlockParameters()
        }
    }
}
