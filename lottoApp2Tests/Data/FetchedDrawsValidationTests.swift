//
//  FetchedDrawsValidationTests.swift
//  lottoApp2Tests
//
//  Validating parsed draws against the source's game rules before they are saved (spec 005 R1, R2).
//

import Foundation
import Testing

@testable import lottoApp2

struct FetchedDrawsValidationTests {

    private let lotto = GameType(id: "lotto-6-49", name: "Lotto", combinationType: try! CombinationType(pick: 6, pool: 49))

    private func draw(_ index: Int, _ numbers: [Int]) -> DrawDTO {
        DrawDTO(index: index, date: Date(timeIntervalSince1970: TimeInterval(index) * 86_400), numbers: numbers)
    }

    @Test
    func validDraws_passUnchanged() throws {
        let fetched = FetchedDraws(draws: [draw(1, [1, 2, 3, 4, 5, 6]), draw(2, [49, 7, 20, 31, 38, 43])], skipped: 2)

        let validated = try fetched.validated(against: lotto)

        #expect(validated.draws == fetched.draws)
        #expect(validated.skipped == 2)
        #expect(validated.invalid == 0)
    }

    @Test(arguments: [
        [1, 1, 3, 4, 5, 6],     // a repeated number
        [1, 2, 3, 4, 5],        // too few numbers
        [1, 2, 3, 4, 5, 6, 7],  // too many numbers
        [1, 2, 3, 4, 5, 50],    // outside the pool
        [-1, 2, 3, 4, 5, 6],    // can't be an element at all
    ])
    func aDrawThatBreaksTheRules_isDropped_andCountedAsInvalid(_ numbers: [Int]) throws {
        let fetched = FetchedDraws(draws: [draw(1, [1, 2, 3, 4, 5, 6]), draw(2, numbers)], skipped: 1)

        let validated = try fetched.validated(against: lotto)

        #expect(validated.draws.map(\.index) == [1])
        #expect(validated.skipped == 1)
        #expect(validated.invalid == 1)
        #expect(validated.skippedTotal == 2)
    }

    @Test(arguments: [
        FetchedDraws(draws: [], skipped: 3),
        FetchedDraws(draws: [DrawDTO(index: 1, date: .distantPast, numbers: [1, 1, 2, 3, 4, 5])], skipped: 0),
        FetchedDraws(draws: [DrawDTO(index: 1, date: .distantPast, numbers: [1, 1, 2, 3, 4, 5])], skipped: 2),
    ])
    func rowsButNoValidDraw_isAFormatChange(_ fetched: FetchedDraws) {
        // FR-007: the response had rows, none of them usable — the same outcome as an unreadable body.
        let expected = fetched.skipped + fetched.draws.count
        #expect(throws: RemoteSourceError.unparseableBody(skipped: expected)) {
            try fetched.validated(against: lotto)
        }
    }

    @Test
    func anEmptyResponse_isAnEmptyHistory_notAFailure() throws {
        let validated = try FetchedDraws(draws: [], skipped: 0).validated(against: lotto)

        #expect(validated == FetchedDraws(draws: [], skipped: 0))
    }

    @Test
    func validatingTwice_changesNothing() throws {
        let fetched = FetchedDraws(draws: [draw(1, [1, 2, 3, 4, 5, 6]), draw(2, [5, 5, 6, 7, 8, 9])], skipped: 1)

        let once = try fetched.validated(against: lotto)

        #expect(try once.validated(against: lotto) == once)
    }
}
