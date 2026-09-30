//
//  ChainRunnerTests.swift
//  lottoApp2Tests
//

import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections
import Testing

@testable import lottoApp2

struct ChainRunnerTests {

    private let a = UUID(1)
    private let b = UUID(2)
    private let c = UUID(3)
    private let d = UUID(4)

    private func chain(_ nodes: [(UUID, UUID?)]) -> Chain {
        Chain(
            id: UUID(0), name: "Runner", revision: 1,
            nodes: IdentifiedArray(uniqueElements: nodes.map { ChainNode(id: $0.0, parentID: $0.1, block: .countUniqueElements) })
        )
    }

    /// Records every call and returns `.number(callIndex)`, so a child's input shows which call produced it.
    private final class Spy: Sendable {
        let inputs = LockIsolated<[BlockValue]>([])
        let failOnCall: Int?

        init(failOnCall: Int? = nil) { self.failOnCall = failOnCall }

        var evaluate: ChainRunner.Evaluate {
            { [inputs, failOnCall] _, input throws(BlockFailure) in
                let call = inputs.withValue { calls in
                    calls.append(input)
                    return calls.count - 1
                }
                if call == failOnCall { throw .overBudget(limit: 1) }
                return .number(call)
            }
        }
    }

    private func collect(_ stream: AsyncStream<RunEvent>) async -> [RunEvent] {
        var events: [RunEvent] = []
        for await event in stream { events.append(event) }
        return events
    }

    private func finishedNodes(_ events: [RunEvent]) -> [UUID] {
        events.compactMap { event in
            guard case let .nodeFinished(id, _) = event else { return nil }
            return id
        }
    }

    // MARK: - Order and sharing (FR-018, FR-019, SC-004)

    @Test
    func run_finishesEveryNodeOnceParentsFirst_thenFinishes() async {
        let chain = chain([(a, nil), (b, a), (c, a), (d, nil)])
        let events = await collect(ChainRunner.live(evaluate: Spy().evaluate).run(chain, ReferenceDraws.lotto))

        let finished = finishedNodes(events)
        #expect(Set(finished) == [a, b, c, d])
        #expect(finished.count == 4)
        #expect(finished.firstIndex(of: a)! < finished.firstIndex(of: b)!)
        #expect(finished.firstIndex(of: a)! < finished.firstIndex(of: c)!)
        #expect(events.last == .finished)
    }

    @Test
    func run_evaluatesASharedParentOnce_andGivesItsOutputToEveryChild() async {
        let spy = Spy()
        let chain = chain([(a, nil), (b, a), (c, a)])
        _ = await collect(ChainRunner.live(evaluate: spy.evaluate).run(chain, ReferenceDraws.lotto))

        let inputs = spy.inputs.value
        #expect(inputs.count == 3)  // a once, then b and c
        #expect(inputs[0] == .draws(ReferenceDraws.lotto))  // the input feeds a
        #expect(inputs[1] == .number(0))  // both children receive a's output (call 0)
        #expect(inputs[2] == .number(0))
    }

    // MARK: - Failure isolation (FR-023)

    @Test
    func run_failsTheDescendantsOfAFailedNode_butNotItsSiblings() async {
        // Evaluation order is a, d, b: a fails (call 0), so b is upstream-failed and d still succeeds.
        let chain = chain([(a, nil), (b, a), (d, nil)])
        let events = await collect(ChainRunner.live(evaluate: Spy(failOnCall: 0).evaluate).run(chain, ReferenceDraws.lotto))

        #expect(events.contains(.nodeFinished(a, .failure(.overBudget(limit: 1)))))
        #expect(events.contains(.nodeFinished(b, .failure(.upstreamFailed))))
        #expect(events.contains(.nodeFinished(d, .success(.number(1)))))
        #expect(events.last == .finished)
    }

    // MARK: - Cancellation (FR-020)

    @Test
    func aCancelledRun_evaluatesNothingMore_andEmitsNoFurtherEvents() async {
        // Cancelling the consumer cancels the run's task (the stream's `onTermination`). The evaluator does
        // the same from inside the second node, so the test never blocks a thread: under TCA's main-serial
        // test executor a blocking wait would deadlock the whole suite.
        let calls = LockIsolated(0)
        let evaluate: ChainRunner.Evaluate = { _, _ throws(BlockFailure) in
            let call = calls.withValue { calls in
                calls += 1
                return calls
            }
            if call == 2 { withUnsafeCurrentTask { $0?.cancel() } }
            return .number(call)
        }
        let chain = chain([(a, nil), (b, a), (c, b)])

        let events = await collect(ChainRunner.live(evaluate: evaluate).run(chain, ReferenceDraws.lotto))

        #expect(events == [.nodeFinished(a, .success(.number(1)))])  // nothing for b, no c, no .finished
        #expect(calls.value == 2)
    }

    @Test
    func cancellingTheConsumer_endsItsIteration() async {
        let runner = ChainRunner.live(evaluate: Spy().evaluate)
        let stream = runner.run(chain([(a, nil)]), ReferenceDraws.lotto)
        let consumer = Task { await collect(stream) }
        consumer.cancel()
        _ = await consumer.value  // returns rather than hanging
    }

    // MARK: - Empty chain

    @Test
    func run_ofAnEmptyChain_onlyFinishes() async {
        let events = await collect(ChainRunner.live(evaluate: Spy().evaluate).run(chain([]), ReferenceDraws.lotto))
        #expect(events == [.finished])
    }

    // MARK: - With the real evaluator

    @Test
    func keepLast100ThenCount_equalsCountingTheLast100Directly() async throws {
        // US2 independent test.
        let game = ReferenceDraws.sequential(count: 500)
        let chain = Chain(
            id: UUID(0), name: "Recent", revision: 2,
            nodes: [
                ChainNode(id: a, parentID: nil, block: .suffix(100)),
                ChainNode(id: b, parentID: a, block: .countUniqueElements),
            ]
        )
        let events = await collect(ChainRunner.live(evaluate: BlockEvaluator.evaluate).run(chain, game))

        let expected = try BlockEvaluator.evaluate(
            .countUniqueElements, on: .draws(game.replacingEntries(Array(game.entries.suffix(100))))
        )
        #expect(events.contains(.nodeFinished(b, .success(expected))))
    }

    @Test
    func topTenOfTheLast100_matchesAHandRanking() async throws {
        // SC-006 chain: input → keep last 100 → count → sort by count desc → keep first 10.
        let game = ReferenceDraws.sequential(count: 500)
        let chain = Chain(
            id: UUID(0), name: "Top 10", revision: 4,
            nodes: [
                ChainNode(id: a, parentID: nil, block: .suffix(100)),
                ChainNode(id: b, parentID: a, block: .countUniqueElements),
                ChainNode(id: c, parentID: b, block: .sortByCount(.descending)),
                ChainNode(id: d, parentID: c, block: .prefix(10)),
            ]
        )
        let events = await collect(ChainRunner.live(evaluate: BlockEvaluator.evaluate).run(chain, game))

        // Ranked by hand from the last 100 entries: count descending, element ascending on ties.
        var tally: [Element: Int] = [:]
        for entry in game.entries.suffix(100) { for element in entry.combination.elements { tally[element, default: 0] += 1 } }
        let expected = tally.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(10)
        let top = try CountResult(
            counts: expected.map { try UniqueCount(item: .element($0.key), count: $0.value) },
            ordering: .byCount(.descending)
        )
        #expect(events.contains(.nodeFinished(d, .success(.counts(top)))))
    }

    @Test
    func twoBranches_giveTheSameResultsAsTwoStraightChains() async throws {
        // US4 independent test, with a shared parent evaluated once (US4 AS2).
        let game = ReferenceDraws.sequential(count: 300)
        let calls = LockIsolated(0)
        let counting: ChainRunner.Evaluate = { block, input throws(BlockFailure) in
            calls.withValue { $0 += 1 }
            return try BlockEvaluator.evaluate(block, on: input)
        }
        let branched = Chain(
            id: UUID(0), name: "Branches", revision: 1,
            nodes: [
                ChainNode(id: a, parentID: nil, block: .suffix(100)),
                ChainNode(id: b, parentID: a, block: .countUniqueElements),
                ChainNode(id: c, parentID: a, block: .sortByDate(.descending)),
                ChainNode(id: d, parentID: c, block: .prefix(5)),
            ]
        )
        let events = await collect(ChainRunner.live(evaluate: counting).run(branched, game))
        #expect(calls.value == 4)

        let straightCount = try BlockEvaluator.evaluate(.countUniqueElements, on: BlockEvaluator.evaluate(.suffix(100), on: .draws(game)))
        let straightNewest = try BlockEvaluator.evaluate(
            .prefix(5), on: BlockEvaluator.evaluate(.sortByDate(.descending), on: BlockEvaluator.evaluate(.suffix(100), on: .draws(game)))
        )
        #expect(events.contains(.nodeFinished(b, .success(straightCount))))
        #expect(events.contains(.nodeFinished(d, .success(straightNewest))))
    }

    @Test
    func anOverBudgetLeaf_failsAlone() async {
        // US7 AS5, FR-023
        let chain = Chain(
            id: UUID(0), name: "Big", revision: 1,
            nodes: [
                ChainNode(id: a, parentID: nil, block: .countUniqueSubCombinations(z: 10)),
                ChainNode(id: b, parentID: nil, block: .countAllElements),
            ]
        )
        let game = BlockEvaluatorTests.twentyOfEighty(entries: 28)
        let events = await collect(ChainRunner.live(evaluate: BlockEvaluator.evaluate).run(chain, game))

        #expect(events.contains(.nodeFinished(a, .failure(.overBudget(limit: 5_000_000)))))
        #expect(events.contains(.nodeFinished(b, .success(.number(28 * 20)))))
    }
}
