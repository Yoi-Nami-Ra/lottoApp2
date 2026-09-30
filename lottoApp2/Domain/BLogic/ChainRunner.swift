//
//  ChainRunner.swift
//  lottoApp2
//
//  Runs a chain against one source's draws (spec 003 FR-018–FR-020, FR-023; research R6).
//

import Dependencies
import Foundation

nonisolated struct ChainRunner: Sendable {
    typealias Evaluate = @Sendable (Block, BlockValue) throws(BlockFailure) -> BlockValue

    /// Streams one `.nodeFinished` per node, every parent before its children, then `.finished`. Ending the
    /// consumer (cancelling its task) stops the run with no further events.
    var run: @Sendable (Chain, Game) -> AsyncStream<RunEvent>
}

nonisolated extension ChainRunner {
    /// Evaluates each node once, off the main actor, and hands its output to all its children (FR-019). A
    /// node whose parent failed finishes `.upstreamFailed`; its siblings are unaffected (FR-023).
    static func live(evaluate: @escaping Evaluate) -> ChainRunner {
        ChainRunner { chain, game in
            let (stream, continuation) = AsyncStream<RunEvent>.makeStream()
            let task = Task.detached(priority: .userInitiated) {
                await RunWorker().evaluateNodes(of: chain, on: game, evaluate: evaluate, into: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
            return stream
        }
    }
}

/// Owns one run. An actor so the evaluation always executes on its own executor, never the caller's: the
/// target defaults to `MainActor`, closure isolation is inferred from that, and evaluation must never block
/// the UI (SC-003).
private actor RunWorker {
    func evaluateNodes(
        of chain: Chain,
        on game: Game,
        evaluate: ChainRunner.Evaluate,
        into continuation: AsyncStream<RunEvent>.Continuation
    ) async {
        var outputs: [ChainNode.ID: BlockValue] = [:]
        for node in chain.evaluationOrder {
            guard !Task.isCancelled else { break }

            let input: BlockValue?
            if let parentID = node.parentID { input = outputs[parentID] } else { input = .draws(game) }
            guard let input else {
                continuation.yield(.nodeFinished(node.id, .failure(.upstreamFailed)))
                continue
            }

            let result: Result<BlockValue, BlockFailure>
            do throws(BlockFailure) {
                result = .success(try evaluate(node.block, input))
            } catch {
                result = .failure(error)
            }
            // A run cancelled mid-node reports nothing for that node.
            guard !Task.isCancelled, result != .failure(.cancelled) else { break }

            if case let .success(value) = result { outputs[node.id] = value }
            continuation.yield(.nodeFinished(node.id, result))
        }
        if !Task.isCancelled { continuation.yield(.finished) }
        continuation.finish()
    }
}

extension ChainRunner: nonisolated DependencyKey {
    nonisolated static let liveValue = ChainRunner.live(evaluate: BlockEvaluator.evaluate)
    nonisolated static let previewValue = liveValue
    nonisolated static let testValue = ChainRunner(
        run: unimplemented("ChainRunner.run", placeholder: AsyncStream { $0.finish() })
    )
}

extension DependencyValues {
    nonisolated var chainRunner: ChainRunner {
        get { self[ChainRunner.self] }
        set { self[ChainRunner.self] = newValue }
    }
}
