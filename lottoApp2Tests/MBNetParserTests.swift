//
//  MBNetParserTests.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 30/07/2026.
//

import Foundation
import Testing

@testable import lottoApp2

struct MBNetParser_Tests {

    @Test
    func parsesWellFormedLines() {
        let text = """
        1. 27.01.1957 8,12,31,39,43,45
        2. 03.02.1957 5,10,11,22,25,27
        """
        let result = MBNetParser.parse(text)

        #expect(result.skipped == 0)
        #expect(result.draws.count == 2)
        #expect(result.draws[0].index == 1)
        #expect(result.draws[0].numbers == [8, 12, 31, 39, 43, 45])
        #expect(result.draws[0].date == MBNetParser.parseDate("27.01.1957"))
        #expect(result.draws[1].index == 2)
        #expect(result.draws[1].numbers == [5, 10, 11, 22, 25, 27])
    }

    @Test
    func skipsMalformedLinesButKeepsGoodOnes() {
        // FR-007: a malformed row is skipped and counted; the rest still parse.
        let text = """
        1. 27.01.1957 8,12,31,39,43,45
        garbage line
        3. 10.02.1957 18,19,20,26,45,49
        """
        let result = MBNetParser.parse(text)

        #expect(result.skipped == 1)
        #expect(result.draws.map(\.index) == [1, 3])
    }

    @Test
    func emptyBodyYieldsNoDraws() {
        let result = MBNetParser.parse("")
        #expect(result.draws.isEmpty)
        #expect(result.skipped == 0)
    }

    @Test
    func rejectsNumbersOutOfRange() {
        // 50 is outside 1…49 → the whole row is malformed.
        #expect(MBNetParser.parseLine("1. 27.01.1957 8,12,31,39,43,50") == nil)
        // wrong number count (5) → malformed.
        #expect(MBNetParser.parseLine("1. 27.01.1957 8,12,31,39,43") == nil)
        // bad date → malformed.
        #expect(MBNetParser.parseLine("1. 32.01.1957 8,12,31,39,43,45") == nil)
    }

    @Test
    func retainsAllSixNumbersPerDraw() {
        // US3 / FR-003: every drawn number is captured, in order, each within 1…49.
        let text = "7380. 18.07.2026 5,6,12,38,41,43"
        let result = MBNetParser.parse(text)

        let draw = try! #require(result.draws.first)
        #expect(draw.numbers == [5, 6, 12, 38, 41, 43])
        #expect(draw.numbers.count == 6)
        #expect(draw.numbers.allSatisfy { (1...49).contains($0) })
    }

    @Test
    func parsesFullHistorySizedBodyQuickly() {
        // SC-006 (parse portion): parsing ~7,400 rows is well under budget on its own.
        let body = (1...7380).map { "\($0). 01.01.2000 1,2,3,4,5,6" }.joined(separator: "\n")

        let start = ContinuousClock.now
        let result = MBNetParser.parse(body)
        let elapsed = ContinuousClock.now - start

        #expect(result.draws.count == 7380)
        #expect(elapsed < .seconds(1))
    }
}
