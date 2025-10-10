//
//  StartPageTests.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 03/10/2025.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import lottoApp2

struct StartPageTests {

    @MainActor
    @Test
    func startPage_Feature_() async throws {
        let store = TestStore(initialState: StartPage.State()) {
            StartPage()
                .dependency(\.blSources, .mock)
        }
        await store.send(.task)
        await store.receive(\.sourcesResponse)
        {
            $0.sources = [
                SourceEntry.State(
                    id: Source.mbnetMock.name,
                    name: Source.mbnetMock.displayName,
                    lastSync: Source.mbnetMock.lastSync,
                    firstRecordDate: Source.mbnetMock.firstRecrd,
                    lastRecordDate: Source.mbnetMock.latestRecord,
                    recordsCount: Source.mbnetMock.recordCount,
                ),
                SourceEntry.State(
                    id: Source.lottoMock.name,
                    name: Source.lottoMock.displayName,
                    lastSync: Source.lottoMock.lastSync,
                    firstRecordDate: Source.lottoMock.firstRecrd,
                    lastRecordDate: Source.lottoMock.latestRecord,
                    recordsCount: Source.lottoMock.recordCount,
                ),
            ]
        }
    }
}

extension SourcesBLogic {
    fileprivate static let mock = SourcesBLogic(
        knownSources: { [.mbnetMock, .lottoMock] },
        fetchFrom: { _ in .success(.mbnetMock) }
    )
}
