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

    /// What the step knows beyond the block itself, for its hints and bounds (spec 006).
    struct Context: Equatable {
        /// The parent's size in its last run, or the source's record count directly under it; `nil` when unknown.
        var parentSize: ParentSize?
        /// How many elements each draw of the chosen source has; `nil` until its draws have been read.
        var drawSize: Int?

        static let unknown = Context(parentSize: nil, drawSize: nil)
    }

    /// The line under the parameter: the parent's size when adding x, the original value when editing (FR-001, FR-003).
    enum Hint: Equatable {
        case parentSize(ParentSize)
        case was(Block)
    }

    /// What the chosen sort direction means, in words (FR-004).
    enum DirectionPreview: Equatable {
        case mostFrequent
        case leastFrequent
        case oldest
        case newest
        case lowestIndex
        case highestIndex
    }

    /// Why the typed number is refused (FR-005–FR-008).
    enum InvalidReason: Equatable {
        case atLeast(UInt)
        case range(UInt, UInt)
        /// No z fits between 2 and the draw size − 1.
        case drawsTooSmall
    }

    struct ParentSize: Equatable {
        enum Unit: Equatable {
            case draws
            case items
        }

        let count: Int
        let unit: Unit
    }

    @ObservableState
    struct State: Equatable {
        let kind: ProcessingBlockKind
        let mode: Mode
        let context: Context
        /// x for filters, as typed. Kept as text so an invalid entry can be shown and refused (FR-006).
        var countText = ""
        var direction: SortDirection = .ascending

        init(kind: ProcessingBlockKind, mode: Mode, context: Context = .unknown) {
            self.kind = kind
            self.mode = mode
            self.context = context
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

        /// The largest z below the source's draw size, once it is known (FR-005). It can fall below `minimum`,
        /// and then no z fits.
        var maximum: UInt? {
            guard parameter == .size, let drawSize = context.drawSize else { return nil }
            return UInt(max(drawSize - 1, 0))
        }

        /// The typed text as a whole number, in range or not.
        var typed: UInt? { UInt(countText.trimmingCharacters(in: .whitespaces)) }

        /// Whether any value fits between `minimum` and `maximum`.
        private var hasRange: Bool { maximum.map { $0 >= minimum } ?? true }

        /// The typed number when it is whole and within `minimum` … `maximum`, else `nil`.
        var count: UInt? {
            guard let value = typed, value >= minimum else { return nil }
            if let maximum, value > maximum { return nil }
            return value
        }

        /// Why the typed number is refused; `nil` while it is valid or there is no number to type.
        var invalidReason: InvalidReason? {
            guard parameter == .count || parameter == .size, count == nil else { return nil }
            guard let maximum else { return .atLeast(minimum) }
            return maximum < minimum ? .drawsTooSmall : .range(minimum, maximum)
        }

        var hint: Hint? {
            if case .edit(_, let original) = mode { return parameter == .none ? nil : .was(original) }
            guard parameter == .count else { return nil }
            return context.parentSize.map(Hint.parentSize)
        }

        var directionPreview: DirectionPreview? {
            // Exhaustive, so a new sort kind can't compile without its preview.
            switch kind {
            case .sortByCount: direction == .descending ? .mostFrequent : .leastFrequent
            case .sortByDate: direction == .ascending ? .oldest : .newest
            case .sortByIndex: direction == .ascending ? .lowestIndex : .highestIndex
            case .dropFirst, .dropLast, .prefix, .suffix, .countUniqueElements, .countUniqueCombinations,
                 .countUniqueSubCombinations, .countAllElements: nil
            }
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
        /// "−" works from any typed number above the minimum, so a value past `maximum` can step back into range.
        var canDecrement: Bool { hasRange && (typed ?? 0) > minimum }

        /// The stepper's "+" stops at `maximum` (FR-006); an entry that isn't a number restarts from the minimum.
        var canIncrement: Bool {
            guard hasRange else { return false }
            guard let maximum, let typed else { return true }
            return typed < maximum
        }
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
                guard state.canIncrement else { return .none }
                // An entry that isn't a number, or is below the minimum, restarts from the minimum rather than
                // guessing what was meant.
                guard let current = state.count else {
                    state.countText = String(state.minimum)
                    return .none
                }
                let (next, overflow) = current.addingReportingOverflow(1)
                if !overflow { state.countText = String(next) }
                return .none

            case .decrementTapped:
                guard state.canDecrement, let typed = state.typed else { return .none }
                state.countText = String(min(typed - 1, state.maximum ?? .max))
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
