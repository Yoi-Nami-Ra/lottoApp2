//
//  SourceBLogicMocks.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 15/10/2025.
//

import Foundation

@testable import lottoApp2

nonisolated extension SourcesBLogic {
    static let mock = SourcesBLogic(
        knownSources: { [.mbnetMock, .lottoMock] },
        fetchFrom: { _ in .success(.refreshedMbnetMock) },
        gameFor: { _ in .success(SourceSnapshot(game: ReferenceDraws.threeOfFive, dataState: .mbnetMock)) },
        dataStateFor: { _ in .mbnetMock }
    )

    static let failureMock = SourcesBLogic(
        knownSources: { [] },
        fetchFrom: { _ in .failure(.somethingWentWrong) },
        gameFor: { _ in .failure(.somethingWentWrong) },
        dataStateFor: { _ in nil }
    )
}

nonisolated extension Source {
    /// A fetch result for `mbnet` whose analytics differ from every seeded entry, so a test can distinguish
    /// "the entry was refreshed" from "the entry already looked like this".
    static let refreshedMbnetMock: Source = .init(
        name: "mbnet",
        displayName: "MBNet Server",
        lastSync: .fixedNow,
        recordsCount: 7380,
        latestRecord: Date(timeIntervalSince1970: 1_700_000_000),
        firstRecord: Date(timeIntervalSince1970: 18_223_210)
    )
}

nonisolated extension Date {
    /// Fixed clock for reducer tests, so derived `SyncSeverity` is deterministic.
    static let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
}
