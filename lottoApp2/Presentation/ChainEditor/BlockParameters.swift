//
//  BlockParameters.swift
//  lottoApp2
//
//  Step 2 of the add-block sheet, and the whole sheet when editing a block (LTA-22). Every block goes
//  through it — one without parameters too — so every add is confirmed the same way.
//

import ComposableArchitecture
import Foundation

@Reducer
struct BlockParameters {
    enum Mode: Equatable {
        case add
        case edit(nodeID: ChainNode.ID, original: Block)
    }

    /// Which parameter a kind takes, so the view knows which control to show.
    enum Parameter: Equatable {
        case none
        /// x for filters: a whole number ≥ 0.
        case count
        /// z for sub-combinations: a whole number ≥ 2.
        case size
        case direction
    }

    @ObservableState
    struct State: Equatable {
        let kind: ProcessingBlockKind
        let mode: Mode
        /// x for filters, as typed. Kept as text so an invalid entry can be shown and refused (FR-006).
        var countText = ""
        var direction: SortDirection = .ascending

        init(kind: ProcessingBlockKind, mode: Mode) {
            self.kind = kind
            self.mode = mode
            let start: Block = switch mode {
            case .add: kind.defaultBlock
            case .edit(_, let original): original
            }
            switch start {
            case .dropFirst(let x), .dropLast(let x), .prefix(let x), .suffix(let x): countText = String(x)
            case .countUniqueSubCombinations(let z): countText = String(z)
            case .sortByDate(let direction), .sortByIndex(let direction), .sortByCount(let direction):
                self.direction = direction
            case .countUniqueElements, .countUniqueCombinations, .countAllElements: break
            }
        }

        var parameter: Parameter {
            switch kind {
            case .dropFirst, .dropLast, .prefix, .suffix: .count
            case .countUniqueSubCombinations: .size
            case .sortByDate, .sortByIndex, .sortByCount: .direction
            case .countUniqueElements, .countUniqueCombinations, .countAllElements: .none
            }
        }

        /// The smallest value the number field accepts: 0 for x, 2 for z (FR-006, FR-011).
        var minimum: UInt { parameter == .size ? 2 : 0 }

        /// The typed number when it is whole and at least `minimum`, else `nil`.
        var count: UInt? {
            guard let value = UInt(countText.trimmingCharacters(in: .whitespaces)), value >= minimum else { return nil }
            return value
        }

        /// The configured block, or `nil` while a parameter is invalid.
        var block: Block? {
            switch kind {
            case .dropFirst: count.map(Block.dropFirst)
            case .dropLast: count.map(Block.dropLast)
            case .prefix: count.map(Block.prefix)
            case .suffix: count.map(Block.suffix)
            case .sortByDate: .sortByDate(direction)
            case .sortByIndex: .sortByIndex(direction)
            case .sortByCount: .sortByCount(direction)
            case .countUniqueElements: .countUniqueElements
            case .countUniqueCombinations: .countUniqueCombinations
            case .countUniqueSubCombinations: count.flatMap { Int(exactly: $0) }.map { .countUniqueSubCombinations(z: $0) }
            case .countAllElements: .countAllElements
            }
        }

        var isValid: Bool { block != nil }
        var canDecrement: Bool { (count ?? 0) > minimum }
    }

    enum Action {
        case countTextChanged(String)
        case incrementTapped
        case decrementTapped
        case directionChanged(SortDirection)
        case confirmTapped
        case cancelTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case confirmed(Block)
        }
    }

    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .countTextChanged(let text):
                state.countText = text
                return .none

            case .incrementTapped:
                // An invalid entry restarts from the minimum rather than guessing what was meant.
                guard let current = state.count else {
                    state.countText = String(state.minimum)
                    return .none
                }
                let (next, overflow) = current.addingReportingOverflow(1)
                if !overflow { state.countText = String(next) }
                return .none

            case .decrementTapped:
                guard state.canDecrement, let count = state.count else { return .none }
                state.countText = String(count - 1)
                return .none

            case .directionChanged(let direction):
                state.direction = direction
                return .none

            case .confirmTapped:
                guard let block = state.block else { return .none }
                return .send(.delegate(.confirmed(block)))
            case .cancelTapped:
                return .run { [dismiss] _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }
}
