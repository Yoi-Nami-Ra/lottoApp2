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

    static let failureMock = failing()

    /// Every source-reading call fails with the given kinds (spec 004), so a test can pick the one it asserts.
    static func failing(
        sync: SyncFailure = .unknown,
        read: SourceReadFailure = .unreadableStoredDraws
    ) -> SourcesBLogic {
        SourcesBLogic(
            knownSources: { [] },
            fetchFrom: { _ in .failure(sync) },
            gameFor: { _ in .failure(read) },
            dataStateFor: { _ in nil }
        )
    }
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
