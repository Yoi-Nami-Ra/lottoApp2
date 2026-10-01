//
//  DrawCadenceTests.swift
//  lottoApp2Tests
//
//  Spec 009 contracts §1. All dates are UTC midnights, as `MBNetParser` stores them. The reference week:
//  the latest draw is Wednesday 30 Sep 2026, so W0 = Monday 28 Sep and the window is [Mon 14 Sep, Mon 28 Sep).
//

import Foundation
import Testing

@testable import lottoApp2

nonisolated struct DrawCadence_Tests {

    private static func day(_ iso: String) -> Date {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        return Calendar.drawWeeks.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    /// Tuesday / Thursday / Saturday draws: 3 a week, so 6 in the two-week window.
    private static let windowDraws = ["2026-09-15", "2026-09-17", "2026-09-19", "2026-09-22", "2026-09-24", "2026-09-26"]
        .map(day)
    /// Long enough history: one draw before the window opens, the window's six, then the latest week's.
    private static let history = [Self.day("2026-09-10")] + windowDraws + [Self.day("2026-09-29"), Self.day("2026-09-30")]

    // MARK: - measure

    @Test
    func noDraws_haveNoCadence() {
        #expect(DrawCadence.measure(drawDates: [], calendar: .drawWeeks) == nil)
    }

    @Test
    func aFullWindow_countsItsDraws() {
        // FR-001: the two full Monday–Sunday weeks before the latest draw's week.
        let cadence = DrawCadence.measure(drawDates: Self.history, calendar: .drawWeeks)
        #expect(cadence?.drawsInWindow == 6)
        #expect(cadence?.drawsPerDay == 6.0 / 14)
    }

    @Test
    func theOrderOfTheDates_doesNotMatter() {
        #expect(DrawCadence.measure(drawDates: Self.history.reversed(), calendar: .drawWeeks)?.drawsInWindow == 6)
    }

    @Test
    func aDrawOnTheWindowsFirstMonday_countsAndIsEnoughHistory() {
        // Research R3: the start is included, so history reaching exactly back to it is long enough.
        let dates = [Self.day("2026-09-14")] + Self.windowDraws + [Self.day("2026-09-30")]
        #expect(DrawCadence.measure(drawDates: dates, calendar: .drawWeeks)?.drawsInWindow == 7)
    }

    @Test
    func historyStartingInsideTheWindow_isNotEnough() {
        // FR-002: the earliest draw is a day after the window opens.
        let dates = Array(Self.windowDraws) + [Self.day("2026-09-30")]
        #expect(DrawCadence.measure(drawDates: dates, calendar: .drawWeeks) == nil)
    }

    @Test
    func anEmptyWindow_isNotEnough() {
        // FR-002: history reaches back far enough, but nothing was drawn in those two weeks.
        let dates = [Self.day("2026-09-01"), Self.day("2026-09-30")]
        #expect(DrawCadence.measure(drawDates: dates, calendar: .drawWeeks) == nil)
    }

    @Test
    func aDrawOnW0_belongsToTheLatestWeek() {
        // Research R3: the end is excluded — Monday 28 Sep opens the latest week.
        let dates = Self.history + [Self.day("2026-09-28")]
        #expect(DrawCadence.measure(drawDates: dates, calendar: .drawWeeks)?.drawsInWindow == 6)
    }

    @Test
    func aLatestDrawOnSunday_staysInTheSameWeek() {
        // Weeks start on Monday (FR-010): Sunday 4 Oct still belongs to the week of Monday 28 Sep.
        let dates = Self.history + [Self.day("2026-10-04")]
        #expect(DrawCadence.measure(drawDates: dates, calendar: .drawWeeks)?.drawsInWindow == 6)
    }

    @Test
    func aLatestDrawOnMonday_movesTheWindowOn() {
        // Monday 5 Oct opens a new week: the window becomes [21 Sep, 5 Oct) — 3 + 2 (29, 30 Sep) draws.
        let dates = Self.history + [Self.day("2026-10-05")]
        #expect(DrawCadence.measure(drawDates: dates, calendar: .drawWeeks)?.drawsInWindow == 5)
    }

    @Test
    func theCalendarIsMondayFirstUTC() {
        #expect(Calendar.drawWeeks.firstWeekday == 2)
        #expect(Calendar.drawWeeks.timeZone == TimeZone(identifier: "UTC"))
        #expect(Calendar.drawWeeks.identifier == .gregorian)
    }

    // MARK: - missing

    private let sixInWindow = DrawCadence(drawsInWindow: 6)
    private static let latest = Self.day("2026-09-30")

    @Test
    func sevenDaysAtThreeAWeek_isThreeMissing() {
        // US1-AS1: ⌊6/14 × 7⌋ = 3 exactly — kept exact by storing the count (research R2).
        #expect(sixInWindow.missing(since: Self.latest, now: Self.latest.addingTimeInterval(7 * .day)) == 3)
    }

    @Test
    func oneDay_isNothingMissing() {
        // US1-AS2: ⌊6/14 × 1⌋ = 0.
        #expect(sixInWindow.missing(since: Self.latest, now: Self.latest.addingTimeInterval(.day)) == 0)
    }

    @Test
    func theFirstMissingDraw_appearsAt14Over6Days() {
        // US1-AS3: N becomes 1 exactly when 6 × elapsed reaches 14 days, and not a second before.
        let threshold = 14.0 / 6 * .day
        #expect(sixInWindow.missing(since: Self.latest, now: Self.latest.addingTimeInterval(threshold)) == 1)
        #expect(sixInWindow.missing(since: Self.latest, now: Self.latest.addingTimeInterval(threshold - 1)) == 0)
    }

    @Test
    func aLongGap_countsInFull() {
        // Edge "Source left unsynced for weeks": 6/14 × 140 days = 60.
        #expect(sixInWindow.missing(since: Self.latest, now: Self.latest.addingTimeInterval(140 * .day)) == 60)
    }

    @Test
    func aClockBeforeTheLatestDraw_isNothingMissing() {
        // FR-004: a negative interval counts as 0.
        #expect(sixInWindow.missing(since: Self.latest, now: Self.latest.addingTimeInterval(-3 * .day)) == 0)
    }
}

extension TimeInterval {
    fileprivate nonisolated static let day: Self = 86_400
}
