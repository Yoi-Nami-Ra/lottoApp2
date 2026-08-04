//
//  MBNetParser.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 30/07/2026.
//

import Foundation

/// Pure parser for the MBNet data file (`http://www.mbnet.com.pl/dl.txt`).
///
/// Line format (see specs/001-mbnet-source/contracts/mbnet-file-format.md):
/// `<index>. DD.MM.YYYY n,n,n,n,n,n` — 6 numbers, each 1…49 (Polish Lotto 6/49).
///
/// Never performs I/O and never throws: malformed lines are skipped and counted so a partial response still
/// yields the well-formed draws (FR-007). Transport/status failures are the caller's concern.
nonisolated enum MBNetParser {
    /// A calendar fixed to UTC so `DD.MM.YYYY` maps to a stable, DST-free `Date` (parsed once, per FR-012).
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    static func parse(_ text: String) -> FetchedDraws {
        var draws: [DrawDTO] = []
        var skipped = 0

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if let draw = parseLine(line) {
                draws.append(draw)
            } else {
                skipped += 1
            }
        }

        return FetchedDraws(draws: draws, skipped: skipped)
    }

    /// Parses one line into a `DrawDTO`, or `nil` if malformed.
    static func parseLine(_ line: String) -> DrawDTO? {
        // "<index>." " DD.MM.YYYY" " n,n,n,n,n,n"
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count == 3 else { return nil }

        guard fields[0].hasSuffix("."),
              let index = Int(fields[0].dropLast()), index >= 1
        else { return nil }

        guard let date = parseDate(fields[1]) else { return nil }

        let numberTokens = fields[2].split(separator: ",", omittingEmptySubsequences: false)
        guard numberTokens.count == 6 else { return nil }
        var numbers: [Int] = []
        numbers.reserveCapacity(6)
        for token in numberTokens {
            guard let value = Int(token), (1...49).contains(value) else { return nil }
            numbers.append(value)
        }

        return DrawDTO(index: index, date: date, numbers: numbers)
    }

    /// Parses `DD.MM.YYYY` by integer split (no `DateFormatter`) into a UTC `Date`, validating the calendar date.
    static func parseDate(_ token: some StringProtocol) -> Date? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]),
              (1...31).contains(day), (1...12).contains(month), year >= 1900
        else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12 // noon UTC — avoids midnight/DST boundary drift
        guard let date = utcCalendar.date(from: components),
              utcCalendar.dateComponents([.year, .month, .day], from: date)
                == DateComponents(year: year, month: month, day: day)
        else { return nil }
        return date
    }
}
