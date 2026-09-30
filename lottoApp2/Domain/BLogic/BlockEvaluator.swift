//
//  BlockEvaluator.swift
//  lottoApp2
//
//  What each block computes (spec 003 FR-005–FR-012, FR-022; research R7). Pure and deterministic: equal
//  inputs give equal outputs (SC-001).
//

import Foundation

nonisolated enum BlockEvaluator {
    /// The most sub-combinations one leaf may generate (FR-022). One tunable constant.
    static let subCombinationBudget = 5_000_000

    /// How many entries a counting loop processes between cancellation checks.
    private static let cancellationStride = 512

    static func evaluate(_ block: Block, on input: BlockValue) throws(BlockFailure) -> BlockValue {
        switch block {
        case .dropFirst(let x): return try slice(input, .dropFirst(Int(clamping: x)))
        case .dropLast(let x): return try slice(input, .dropLast(Int(clamping: x)))
        case .prefix(let x): return try slice(input, .prefix(Int(clamping: x)))
        case .suffix(let x): return try slice(input, .suffix(Int(clamping: x)))
        case .sortByDate(let direction): return .draws(sortByDate(try draws(input), direction))
        case .sortByIndex(let direction): return .draws(sortByIndex(try draws(input), direction))
        case .sortByCount(let direction): return .counts(sortByCount(try counts(input), direction))
        case .countUniqueElements: return .counts(try countUniqueElements(draws(input)))
        case .countUniqueCombinations: return .counts(try countUniqueCombinations(draws(input)))
        case .countUniqueSubCombinations(let z): return .counts(try countUniqueSubCombinations(draws(input), z: z))
        case .countAllElements: return .number(try countAllElements(draws(input)))
        }
    }

    // MARK: - Filters

    /// What a filter keeps. Swift's own `prefix`/`suffix`/`dropFirst`/`dropLast` already clamp, which is
    /// exactly FR-006: keeping more than there is keeps everything, skipping more leaves nothing.
    private enum Slice {
        case dropFirst(Int), dropLast(Int), prefix(Int), suffix(Int)

        func apply<Item>(_ items: [Item]) -> [Item] {
            switch self {
            case .dropFirst(let x): Array(items.dropFirst(x))
            case .dropLast(let x): Array(items.dropLast(x))
            case .prefix(let x): Array(items.prefix(x))
            case .suffix(let x): Array(items.suffix(x))
            }
        }
    }

    /// Filters draws or counts in their current order, returning the same kind (FR-005).
    private static func slice(_ input: BlockValue, _ slice: Slice) throws(BlockFailure) -> BlockValue {
        switch input {
        case .draws(let game): .draws(game.replacingEntries(slice.apply(game.entries)))
        case .counts(let result): .counts(CountResult(counts: slice.apply(result.counts), ordering: result.ordering))
        case .number: throw .invalidParameter(name: "input")
        }
    }

    // MARK: - Sorts

    /// By date in `direction`; equal dates fall back to index ascending whatever the direction (FR-007).
    private static func sortByDate(_ game: Game, _ direction: SortDirection) -> Game {
        game.replacingEntries(game.entries.sorted { lhs, rhs in
            guard lhs.date != rhs.date else { return lhs.index < rhs.index }
            return direction == .ascending ? lhs.date < rhs.date : lhs.date > rhs.date
        })
    }

    private static func sortByIndex(_ game: Game, _ direction: SortDirection) -> Game {
        game.replacingEntries(game.entries.sorted { lhs, rhs in
            direction == .ascending ? lhs.index < rhs.index : lhs.index > rhs.index
        })
    }

    /// By count in `direction`; equal counts fall back to item ascending whatever the direction (FR-008).
    private static func sortByCount(_ result: CountResult, _ direction: SortDirection) -> CountResult {
        CountResult(
            counts: result.counts.sorted { lhs, rhs in
                guard lhs.count != rhs.count else { return lhs.item < rhs.item }
                return direction == .ascending ? lhs.count < rhs.count : lhs.count > rhs.count
            },
            ordering: .byCount(direction)
        )
    }

    // MARK: - Counting

    private static func countUniqueElements(_ game: Game) throws(BlockFailure) -> CountResult {
        var counts: [CountItem: Int] = [:]
        for (offset, entry) in game.entries.enumerated() {
            try checkCancellation(offset)
            for element in entry.combination.elements {
                counts[.element(element), default: 0] += 1
            }
        }
        return CountResult(unordered: uniqueCounts(counts))
    }

    private static func countUniqueCombinations(_ game: Game) throws(BlockFailure) -> CountResult {
        var counts: [CountItem: Int] = [:]
        for (offset, entry) in game.entries.enumerated() {
            try checkCancellation(offset)
            counts[.combination(entry.combination), default: 0] += 1
        }
        return CountResult(unordered: uniqueCounts(counts))
    }

    /// Every z-element sub-combination of every entry. z must be below x of this game (FR-011), and the work —
    /// entries × C(x, z) — must fit the budget, checked before anything is generated (FR-022).
    private static func countUniqueSubCombinations(_ game: Game, z: Int) throws(BlockFailure) -> CountResult {
        let x = game.type.combinationType.pick
        guard z >= 2, z < x else { throw .invalidParameter(name: "z") }
        guard let work = subCombinationWork(entries: game.entries.count, x: x, z: z), work <= subCombinationBudget else {
            throw .overBudget(limit: subCombinationBudget)
        }
        var counts: [CountItem: Int] = [:]
        for (offset, entry) in game.entries.enumerated() {
            try checkCancellation(offset)
            // z was checked against this game's x above, so the entry's own check can't fail.
            for sub in (try? entry.combination.subCombinations(size: z)) ?? [] {
                counts[.subCombination(sub), default: 0] += 1
            }
        }
        return CountResult(unordered: uniqueCounts(counts))
    }

    /// entries × C(x, z), or `nil` when it overflows (which is over any budget).
    private static func subCombinationWork(entries: Int, x: Int, z: Int) -> Int? {
        var binomial = 1
        for step in 0..<min(z, x - z) {
            // C(x, k+1) = C(x, k) · (x − k) / (k + 1); exact at every step.
            let (product, overflow) = binomial.multipliedReportingOverflow(by: x - step)
            guard !overflow else { return nil }
            binomial = product / (step + 1)
        }
        let (work, overflow) = binomial.multipliedReportingOverflow(by: entries)
        return overflow ? nil : work
    }

    /// Every drawn element across the entries — entries × x for one shape, but counted, so no draws gives 0.
    private static func countAllElements(_ game: Game) throws(BlockFailure) -> Int {
        var total = 0
        for (offset, entry) in game.entries.enumerated() {
            try checkCancellation(offset)
            total += entry.combination.elements.count
        }
        return total
    }

    // MARK: - Helpers

    private static func uniqueCounts(_ counts: [CountItem: Int]) -> [UniqueCount] {
        // Every count in the dictionary is at least 1, so nothing is dropped here.
        counts.compactMap { try? UniqueCount(item: $0.key, count: $0.value) }
    }

    /// A chain built through the attach rule never hands a block an input it doesn't accept; this guards the
    /// evaluator's own contract rather than a reachable state.
    private static func draws(_ input: BlockValue) throws(BlockFailure) -> Game {
        guard case let .draws(game) = input else { throw .invalidParameter(name: "input") }
        return game
    }

    private static func counts(_ input: BlockValue) throws(BlockFailure) -> CountResult {
        guard case let .counts(result) = input else { throw .invalidParameter(name: "input") }
        return result
    }

    private static func checkCancellation(_ offset: Int) throws(BlockFailure) {
        if offset % cancellationStride == 0, Task.isCancelled { throw .cancelled }
    }
}
