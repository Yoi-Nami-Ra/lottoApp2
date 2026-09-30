//
//  ResultPage.swift
//  lottoApp2
//
//  One block's full output (spec 003 FR-024–FR-026; LTA-9). It only renders what it was given, so it runs
//  no effects.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ResultPage {
    @ObservableState
    struct State: Equatable {
        let value: BlockValue
        let stamp: RunStamp
        var freshness: ResultFreshness
        /// A saved result whose chain was edited since; information only (FR-030).
        var chainChanged: Bool = false
        /// Counts whose combination group shows everything, not just the first `groupPreviewSize` (LTA-18).
        var expandedGroups: Set<Int> = []

        init(value: BlockValue, stamp: RunStamp, freshness: ResultFreshness, chainChanged: Bool = false) {
            self.value = value
            self.stamp = stamp
            self.freshness = freshness
            self.chainChanged = chainChanged
        }

        /// Only a result sorted by count is a ranking; an unordered one must not look like one (FR-025).
        var isRanked: Bool {
            guard case let .counts(result) = value, case .byCount = result.ordering else { return false }
            return true
        }

        /// A count result's rows, in the result's own order — item ascending when it is unordered (FR-025).
        var rows: [CountRow] {
            guard case let .counts(result) = value else { return [] }
            let ranked = isRanked
            return result.counts.enumerated().map { offset, unique in
                CountRow(item: unique.item, count: unique.count, rank: ranked ? offset + 1 : nil)
            }
        }

        /// Combination counts are split into one group per occurring count, repeats first; each group lists
        /// its combinations ascending and shows the first `groupPreviewSize` until expanded (LTA-18).
        var groups: [CountGroup] {
            guard case let .counts(result) = value, case .combination = result.counts.first?.item else { return [] }
            let byCount = Dictionary(grouping: result.counts, by: \.count)
            return byCount.keys.sorted(by: >).map { count in
                let rows = (byCount[count] ?? []).sorted { $0.item < $1.item }.map {
                    CountRow(item: $0.item, count: $0.count, rank: nil)
                }
                let shown = expandedGroups.contains(count) ? rows : Array(rows.prefix(ResultPage.groupPreviewSize))
                return CountGroup(count: count, shown: shown, total: rows.count)
            }
        }

        var isEmpty: Bool {
            switch value {
            case .draws(let game): game.entries.isEmpty
            case .counts(let result): result.counts.isEmpty
            case .number: false
            }
        }
    }

    /// How many combinations a group shows before "N more" (LTA-18).
    static let groupPreviewSize = 20

    struct CountGroup: Equatable, Identifiable {
        let count: Int
        let shown: [CountRow]
        let total: Int
        var remaining: Int { total - shown.count }
        var id: Int { count }
    }

    struct CountRow: Equatable, Identifiable {
        let item: CountItem
        let count: Int
        /// The row's position in a ranking; `nil` when the result isn't ranked.
        let rank: Int?
        var id: CountItem { item }
    }

    enum Action: Equatable {
        case showAllTapped(count: Int)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .showAllTapped(let count):
                state.expandedGroups.insert(count)
                return .none
            }
        }
    }
}
