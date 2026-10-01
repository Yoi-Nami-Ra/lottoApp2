//
//  DrawCadence.swift
//  lottoApp2
//
//  How often a source publishes draws, and from that how many it has probably published since its latest
//  stored one (spec 009, LTA-4). Pure rules: the Data layer measures the cadence when it writes metadata,
//  and the start page turns it into an estimate with its injected clock.
//

import Foundation

/// The draws a source published in the two full weeks before the week of its latest stored draw.
///
/// The count is stored rather than a rate: multiplying a rounded `Double` rate back out would put the
/// estimate's boundaries a rounding error short — (6 ÷ 14) × 7 is 2.999…, not 3 (research R2).
nonisolated struct DrawCadence: Equatable, Sendable {
    /// At least 1: an empty window is "not enough history", not a cadence of zero.
    let drawsInWindow: Int

    var drawsPerDay: Double { Double(drawsInWindow) / Double(Int.windowDays) }

    /// Counts the draws dated in `[W0 − 14 days, W0)`, where `W0` starts the week holding the latest draw — so
    /// a source left unsynced for weeks is still measured on settled data (FR-001). `nil` when the stored
    /// history doesn't reach back to the window's start, or the window holds no draws (FR-002).
    static func measure(drawDates: [Date], calendar: Calendar) -> DrawCadence? {
        guard
            let earliest = drawDates.min(),
            let latest = drawDates.max(),
            let latestWeek = calendar.dateInterval(of: .weekOfYear, for: latest),
            let windowStart = calendar.date(byAdding: .day, value: -Int.windowDays, to: latestWeek.start),
            earliest <= windowStart
        else { return nil }

        let window = windowStart..<latestWeek.start
        let count = drawDates.count(where: window.contains)
        return count > 0 ? DrawCadence(drawsInWindow: count) : nil
    }

    /// ⌊draws per day × days since `latestRecord`⌋, with days fractional and a clock before the latest draw
    /// counted as no time at all (FR-004).
    func missing(since latestRecord: Date, now: Date) -> Int {
        let elapsed = max(0, now.timeIntervalSince(latestRecord))
        return Int((Double(drawsInWindow) * elapsed / .window).rounded(.down))
    }
}

extension Calendar {
    /// The weeks the cadence is measured in: Gregorian, Monday first, in UTC — the zone draws are dated in
    /// (spec 009 clarification 2), so the estimate doesn't depend on the device's locale or time zone.
    nonisolated static let drawWeeks: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = .monday
        return calendar
    }()
}

// MARK: - Resources
extension Int {
    fileprivate nonisolated static let windowDays = 14
    /// `Calendar.firstWeekday` numbering: Sunday is 1.
    fileprivate nonisolated static let monday = 2
}

extension TimeInterval {
    /// The window's length in seconds.
    fileprivate nonisolated static let window: Self = Double(Int.windowDays) * 86_400
}
