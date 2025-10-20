//
//  TestBSources.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 17/10/2025.
//

import Testing
import Dependencies

@testable import lottoApp2

struct SourceBLogicTests {

    @Test func knownSources() async throws {
        let sources = await withDependencies {
            $0.sorcesRepo.listKnownSources = { [.mbnetMock, .lottoMock] }
        } operation: {
            await SourcesBLogic.liveValue.knownSources()
        }

        #expect(sources == [.mbnetMock, .lottoMock])
    }

    @Test func fetchSourceData() async throws {
        let testResult = await withDependencies {
            $0.sorcesRepo.fetchAndSaveDataFrom = { _ in .success(.mbnetMock) }
        } operation: {
            await SourcesBLogic.liveValue.fetchFrom("klopik")
        }

        #expect(testResult == .success(Source.mbnetMock))
    }
}
