//
//  FreshnessTests.swift
//  lottoApp2Tests
//
//  When a shown result is out of date (FR-021, research R13).
//

import Foundation
import IdentifiedCollections
import Testing

@testable import lottoApp2

struct FreshnessTests {

    private let mbnet = SourceDataState(recordsCount: 10, latestRecord: nil, contentDigest: "a")
    private let mbnetSynced = SourceDataState(recordsCount: 11, latestRecord: nil, contentDigest: "b")
    private let lotto = SourceDataState(recordsCount: 99, latestRecord: nil, contentDigest: "z")

    private func stamp(_ source: String, _ state: SourceDataState, revision: Int = 3) -> RunStamp {
        RunStamp(sourceName: source, sourceDisplayName: source, dataState: state, chainRevision: revision)
    }

    @Test
    func aResultIsCurrent_whileNeitherTheChainNorItsSourceChanged() {
        let result = NodeResult.value(.number(1), stamp("mbnet", mbnet))
        #expect(result.freshness(chainRevision: 3, dataStates: ["mbnet": mbnet]) == .current)
    }

    @Test
    func editingTheChain_makesAResultOutOfDate() {
        // SC-005
        let result = NodeResult.value(.number(1), stamp("mbnet", mbnet))
        #expect(result.freshness(chainRevision: 4, dataStates: ["mbnet": mbnet]) == .outOfDate)
    }

    @Test
    func aSyncThatChangedTheSource_makesAResultOutOfDate() {
        let failed = NodeResult.failed(.overBudget(limit: 1), stamp("mbnet", mbnet))
        #expect(failed.freshness(chainRevision: 3, dataStates: ["mbnet": mbnetSynced]) == .outOfDate)
    }

    @Test
    func aResultIsJudgedAgainstItsOwnSource_notAnother() {
        // A result from mbnet stays current however lotto's data looks.
        let result = NodeResult.value(.number(1), stamp("mbnet", mbnet))
        #expect(result.freshness(chainRevision: 3, dataStates: ["mbnet": mbnet, "lotto": lotto]) == .current)
    }

    @Test
    func aMissingSource_readsAsUnavailable_evenIfTheChainAlsoChanged() {
        // data-model: source unavailable takes precedence over out of date.
        let result = NodeResult.value(.number(1), stamp("gone", mbnet))
        #expect(result.freshness(chainRevision: 9, dataStates: ["mbnet": mbnet]) == .sourceUnavailable)
        #expect(result.freshness(chainRevision: 3, dataStates: ["gone": nil]) == .sourceUnavailable)
    }

    @Test
    func notRunAndRunning_areCurrent() {
        #expect(NodeResult.notRun.freshness(chainRevision: 9, dataStates: [:]) == .current)
        #expect(NodeResult.running.freshness(chainRevision: 9, dataStates: [:]) == .current)
    }

    // MARK: - Saved results (FR-030, SC-007)

    private func saved(_ source: String, _ state: SourceDataState, revision: Int = 3) -> SavedResult {
        SavedResult(
            id: UUID(), chainID: UUID(), nodeID: UUID(), path: [.countUniqueElements], value: .number(1),
            stamp: stamp(source, state, revision: revision), savedAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test
    func aSavedResult_goesOutOfDateOnlyWhenItsSourceChanges() {
        let result = saved("mbnet", mbnet)
        #expect(result.freshness(dataStates: ["mbnet": mbnet]) == .current)
        #expect(result.freshness(dataStates: ["mbnet": mbnetSynced]) == .outOfDate)
    }

    @Test
    func aSavedResultWhoseSourceIsGone_readsAsUnavailable() {
        #expect(saved("gone", mbnet).freshness(dataStates: ["mbnet": mbnet]) == .sourceUnavailable)
        #expect(saved("gone", mbnet).freshness(dataStates: ["gone": nil]) == .sourceUnavailable)
    }

    @Test
    func editingTheChain_isInformationOnly_forASavedResult() {
        let chain = Chain(id: UUID(), name: "C", revision: 4, nodes: [])
        let result = saved("mbnet", mbnet, revision: 3)
        #expect(result.chainChanged(since: chain))
        #expect(result.freshness(dataStates: ["mbnet": mbnet]) == .current)
        #expect(saved("mbnet", mbnet, revision: 4).chainChanged(since: chain) == false)
    }

    @Test
    func aSyncOfOneSource_leavesTheOthersSavedResultsCurrent() {
        // SC-007: 100% of mbnet's results go out of date, 0% of lotto's.
        let states: [String: SourceDataState?] = ["mbnet": mbnetSynced, "lotto": lotto]
        #expect(saved("mbnet", mbnet).freshness(dataStates: states) == .outOfDate)
        #expect(saved("lotto", lotto).freshness(dataStates: states) == .current)
    }
}
