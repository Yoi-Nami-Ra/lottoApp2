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

    @Test
    @MainActor
    func knownSources() async throws {
        let sources = await withDependencies {
            // mbnet, lotto as known sources
            $0.sourcesRepo.listKnownSources = { [.mbnetMock, .partialLottoMock] }
            // mbnet as saved source
        } operation: {
            await SourcesBLogic.liveValue.knownSources()
        }

        #expect(sources == [.mbnetMock, .partialLottoMock])
    }

    @Test
    @MainActor
    func fetchSourceData() async throws {
        let testResult = await withDependencies {
            $0.sourcesRepo.fetchAndSaveDataFrom = { _ in .success(.mbnetMock) }
        } operation: {
            await SourcesBLogic.liveValue.fetchFrom("klopik")
        }

        #expect(testResult == .success(Source.mbnetMock))
    }
}

extension Source {
    static let partialMbnetMock: Self = .init(
        name: "mbnet",
        displayName: "MBNet Server",
    )
    static let partialLottoMock: Self = .init(
        name: "lotto",
        displayName: "Lotto Server",
    )
}
