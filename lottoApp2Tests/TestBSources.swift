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
        // The business logic is a pass-through today: it forwards whatever the repo lists, unchanged.
        let sources = await withDependencies {
            $0.sourcesRepo.listKnownSources = { [.mbnetMock, .partialLottoMock] }
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

    @Test(arguments: [
        SyncFailure.offline, .serverUnreachable, .serverError(status: 503), .unreadableData,
        .sourceUnavailable, .storageFailure, .unknown, .cancelled,
    ])
    @MainActor
    func fetchSourceDataPassesTheRepoFailureThrough(_ failure: SyncFailure) async throws {
        // Spec 004 FR-002: the kind reaches the UI unchanged — no layer widens it.
        let testResult = await withDependencies {
            $0.sourcesRepo.fetchAndSaveDataFrom = { _ in .failure(failure) }
        } operation: {
            await SourcesBLogic.liveValue.fetchFrom("mbnet")
        }

        #expect(testResult == .failure(failure))
    }
}

extension SourceBLogicTests {
    @Test
    @MainActor
    func gameForPassesTheSnapshotThrough() async throws {
        let snapshot = SourceSnapshot(game: ReferenceDraws.threeOfFive, dataState: .mbnetMock)
        let result = await withDependencies {
            $0.sourcesRepo.gameFor = { _ in .success(snapshot) }
        } operation: {
            await SourcesBLogic.liveValue.gameFor("mbnet")
        }

        #expect(result == .success(snapshot))
    }

    @Test(arguments: [SourceReadFailure.sourceUnavailable, .unreadableStoredDraws])
    @MainActor
    func gameForPassesTheRepoFailureThrough(_ failure: SourceReadFailure) async throws {
        let result = await withDependencies {
            $0.sourcesRepo.gameFor = { _ in .failure(failure) }
        } operation: {
            await SourcesBLogic.liveValue.gameFor("nope")
        }

        #expect(result == .failure(failure))
    }

    @Test
    @MainActor
    func dataStateForPassesThrough() async throws {
        let state = await withDependencies {
            $0.sourcesRepo.dataStateFor = { _ in .mbnetMock }
        } operation: {
            await SourcesBLogic.liveValue.dataStateFor("mbnet")
        }

        #expect(state == .mbnetMock)
    }
}

nonisolated extension Source {
    static let partialLottoMock: Self = .init(
        name: "lotto",
        displayName: "Lotto Server",
    )
}
