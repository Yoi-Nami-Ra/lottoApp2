//
//  ReferenceDraws.swift
//  lottoApp2Tests
//
//  The hand-computed reference set for spec 003 (SC-001). Every expected answer sits next to its fixture
//  as a literal, so a test compares the pipeline with a hand count rather than with its own output.
//

import Foundation

@testable import lottoApp2

nonisolated enum ReferenceDraws {

    // MARK: - Shapes

    static let threeOfFiveType = try! CombinationType(pick: 3, pool: 5)
    static let sixOfFortyNineType = try! CombinationType(pick: 6, pool: 49)

    static let threeOfFiveGameType = GameType(id: "ref-3-5", name: "Reference 3/5", combinationType: threeOfFiveType)
    static let lottoGameType = GameType(id: "ref-6-49", name: "Reference 6/49", combinationType: sixOfFortyNineType)

    // MARK: - threeOfFive (US1 AS1)

    /// {1, 2, 3}, {2, 3, 4}, {3, 4, 5} at indices 1–3.
    static let threeOfFive: Game = game(threeOfFiveGameType, [
        (1, day(1), [1, 2, 3]),
        (2, day(2), [2, 3, 4]),
        (3, day(3), [3, 4, 5]),
    ])

    /// Count Unique Elements over `threeOfFive`: 1→1, 2→2, 3→3, 4→2, 5→1 and nothing else.
    static let threeOfFiveElementCounts: [Element: Int] = [1: 1, 2: 2, 3: 3, 4: 2, 5: 1]

    // MARK: - lotto (12 draws, 6 of 49)

    /// Properties the tests rely on:
    /// - element 17 is never drawn (US1 AS2);
    /// - draws 5 and 6 share a date (FR-007 tie-break);
    /// - {1, 5, 9, 20, 33, 41} is drawn twice, the second time written in reverse (US7 AS1);
    /// - the pair {10, 11} is drawn in exactly 3 draws (2, 3 and 8) (US7 AS3).
    static let lotto: Game = game(lottoGameType, [
        (1, day(1), [1, 5, 9, 20, 33, 41]),
        (2, day(4), [2, 10, 11, 22, 30, 45]),
        (3, day(8), [3, 10, 11, 25, 36, 49]),
        (4, day(11), [4, 12, 18, 27, 38, 44]),
        (5, day(15), [6, 13, 19, 28, 39, 46]),
        (6, day(15), [7, 14, 21, 29, 40, 47]),
        (7, day(18), [41, 33, 20, 9, 5, 1]),
        (8, day(22), [8, 10, 11, 23, 31, 48]),
        (9, day(25), [2, 15, 24, 32, 42, 43]),
        (10, day(29), [3, 16, 26, 34, 35, 37]),
        (11, day(32), [4, 6, 12, 22, 30, 49]),
        (12, day(36), [8, 15, 24, 38, 44, 45]),
    ])

    /// Count Unique Elements over `lotto`, counted by hand: 48 distinct elements, 72 occurrences.
    static let lottoElementCounts: [Element: Int] = {
        var counts: [Element: Int] = [:]
        for element: Element in [10, 11] { counts[element] = 3 }
        for element: Element in [1, 2, 3, 4, 5, 6, 8, 9, 12, 15, 20, 22, 24, 30, 33, 38, 41, 44, 45, 49] {
            counts[element] = 2
        }
        for element: Element in [
            7, 13, 14, 16, 18, 19, 21, 23, 25, 26, 27, 28, 29, 31, 32, 34, 35, 36, 37, 39, 40, 42, 43, 46, 47, 48,
        ] {
            counts[element] = 1
        }
        return counts
    }()

    static let lottoRepeatedCombination: [Element] = [1, 5, 9, 20, 33, 41]
    static let lottoSharedPair: [Element] = [10, 11]
    static let lottoUniqueCombinations = 11
    static let lottoUniquePairs = 159

    // MARK: - empty

    static let empty: Game = game(lottoGameType, [])

    // MARK: - sequential

    /// `count` 6-of-49 draws whose index order is also their date order (index i on day i). Numbers cycle
    /// through the pool so later draws differ from earlier ones.
    static func sequential(count: Int) -> Game {
        let rows = (0..<count).map { offset -> (Int, Date, [Element]) in
            let index = offset + 1
            let start = Element((index * 7) % 44)  // 0…43, so start + 6 stays within 1…49
            return (index, day(index), (1...6).map { start + Element($0) })
        }
        return game(lottoGameType, rows)
    }

    // MARK: - Builders

    static func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_577_836_800 + TimeInterval(offset) * 86_400)  // 2020-01-01 + offset days
    }

    static func game(_ type: GameType, _ rows: [(Int, Date, [Element])]) -> Game {
        let entries = rows.map { index, date, elements in
            GameEntry(index: index, date: date, combination: try! Combination(type: type.combinationType, elements: elements))
        }
        return try! Game(type: type, entries: entries)
    }
}
