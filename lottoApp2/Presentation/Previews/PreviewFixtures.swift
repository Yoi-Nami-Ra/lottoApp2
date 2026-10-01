//
//  PreviewFixtures.swift
//  lottoApp2
//
//  Sample data for `#Preview`s (Principle V requires previews, and previews compile into the app target).
//  Kept here rather than in Domain so the inner layer carries no UI-support fixtures.
//

import Dependencies
import Foundation
import IdentifiedCollections

extension SourcesBLogic {
    /// Business logic backed by in-memory sample data, for SwiftUI previews.
    static let previewMock = SourcesBLogic(
        knownSources: { Source.mocks },
        fetchFrom: { name in
            guard let source = Source.previewFour.first(where: { $0.name == name })
            else { return .failure(.sourceUnavailable) }
            return .success(source)
        },
        gameFor: { name in
            guard Source.previewFour.contains(where: { $0.name == name }) else { return .failure(.sourceUnavailable) }
            return .success(SourceSnapshot(game: .previewMock, dataState: .previewMock))
        },
        dataStateFor: { name in
            Source.previewFour.contains(where: { $0.name == name }) ? .previewMock : nil
        }
    )
}

nonisolated extension Game {
    /// Twelve 6-of-49 draws, index order = date order.
    static let previewMock: Game = {
        let type = GameType(id: "preview-6-49", name: "Preview Lotto", combinationType: try! CombinationType(pick: 6, pool: 49))
        let rows: [[Element]] = [
            [1, 5, 9, 20, 33, 41], [2, 10, 11, 22, 30, 45], [3, 10, 11, 25, 36, 49], [4, 12, 18, 27, 38, 44],
            [6, 13, 19, 28, 39, 46], [7, 14, 21, 29, 40, 47], [1, 5, 9, 20, 33, 41], [8, 10, 11, 23, 31, 48],
            [2, 15, 24, 32, 42, 43], [3, 16, 26, 34, 35, 37], [4, 6, 12, 22, 30, 49], [8, 15, 24, 38, 44, 45],
        ]
        let entries = rows.enumerated().map { offset, elements in
            GameEntry(
                index: offset + 1,
                date: Date(timeIntervalSince1970: 1_577_836_800 + TimeInterval(offset) * 302_400),
                combination: try! Combination(type: type.combinationType, elements: elements)
            )
        }
        return try! Game(type: type, entries: entries)
    }()
}

nonisolated extension SourceDataState {
    static let previewMock = SourceDataState(
        recordsCount: 12, latestRecord: Date(timeIntervalSince1970: 1_581_163_200), contentDigest: "preview"
    )
}

nonisolated extension Source {
    static let mbnetMock: Source = .init(
        name: "mbnet",
        displayName: "MBNet Server",
        lastSync: .now.addingTimeInterval(-100_000),
        recordsCount: 120,
        latestRecord: .now.addingTimeInterval(-180_000),
        firstRecord: Date(timeIntervalSince1970: 18_223_210),
        // ~2 days since a 3-a-week draw: nothing missing yet, green (spec 009).
        cadence: DrawCadence(drawsInWindow: 6)
    )

    static let lottoMock: Source = .init(
        name: "lotto",
        displayName: "Lotto Server",
        lastSync: .now.addingTimeInterval(-432_000),
        recordsCount: 110,
        latestRecord: .now.addingTimeInterval(-600_000),
        firstRecord: Date(timeIntervalSince1970: 18_223_210),
        // ~7 days at 3 a fortnight: "~1 missing", yellow.
        cadence: DrawCadence(drawsInWindow: 3)
    )

    static let neverSyncedMock: Source = .init(
        name: "eurojackpot",
        displayName: "EuroJackpot Server"
    )

    /// Overdue past the high-severity threshold (spec 007 previews: one source per severity).
    static let staleMock: Source = .init(
        name: "minilotto",
        displayName: "Mini Lotto Mirror",
        lastSync: .now.addingTimeInterval(-800_000),
        recordsCount: 5340,
        latestRecord: .now.addingTimeInterval(-900_000),
        firstRecord: Date(timeIntervalSince1970: 18_223_210),
        // ~10 days at 3 a week: "~4 missing", red.
        cadence: DrawCadence(drawsInWindow: 6)
    )

    static let mocks: [Source] = [.mbnetMock, .lottoMock, .neverSyncedMock]
    /// Four sources, one per severity: what the start page's layouts are checked against (spec 007 SC-001).
    static let previewFour: [Source] = [.mbnetMock, .lottoMock, .staleMock, .neverSyncedMock]
}

nonisolated extension Chain {
    static let previewEmpty = Chain.empty(id: UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE")!, name: "New chain")

    /// input → Count Unique Elements.
    static let previewCountOnly = Chain(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000C0D1")!, name: "Number counts", revision: 1,
        nodes: [ChainNode(id: .previewCountNode, parentID: nil, block: .countUniqueElements)]
    )

    /// input → { last 100 → count → sort by count → first 10, count }.
    static let previewBranches = Chain(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000C0D2")!, name: "Recent vs all time", revision: 5,
        nodes: [
            ChainNode(id: .previewFilterNode, parentID: nil, block: .suffix(100)),
            ChainNode(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!, parentID: .previewFilterNode, block: .countUniqueElements),
            ChainNode(
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!,
                parentID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!, block: .sortByCount(.descending)
            ),
            ChainNode(id: .previewCountNode, parentID: nil, block: .countUniqueElements),
            ChainNode(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B3")!, parentID: nil, block: .countAllElements),
        ]
    )
}

nonisolated extension UUID {
    static let previewCountNode = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    static let previewFilterNode = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
}

nonisolated extension RunStamp {
    static let previewMock = RunStamp(
        sourceName: "mbnet", sourceDisplayName: "MBNet Server", dataState: .previewMock, chainRevision: 1
    )
}

nonisolated extension BlockValue {
    /// Count Unique Elements over `Game.previewMock`.
    static let previewElementCounts: BlockValue =
        (try? BlockEvaluator.evaluate(.countUniqueElements, on: .draws(.previewMock))) ?? .number(0)

    static let previewCombinationCounts: BlockValue =
        (try? BlockEvaluator.evaluate(.countUniqueCombinations, on: .draws(.previewMock))) ?? .number(0)

    static let previewPairCounts: BlockValue =
        (try? BlockEvaluator.evaluate(.countUniqueSubCombinations(z: 2), on: .draws(.previewMock))) ?? .number(0)

    /// The element counts above, sorted by count descending and trimmed to the top 10.
    static let previewRankedCounts: BlockValue = {
        guard let sorted = try? BlockEvaluator.evaluate(.sortByCount(.descending), on: previewElementCounts),
              let top = try? BlockEvaluator.evaluate(.prefix(10), on: sorted)
        else { return .number(0) }
        return top
    }()
}

nonisolated extension Array where Element == SavedResult {
    /// One current, one out-of-date and one from a source that no longer exists.
    static let previewSaved: [SavedResult] = [
        SavedResult(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000005A1")!, chainID: Chain.previewCountOnly.id,
            nodeID: .previewCountNode, path: [.countUniqueElements], value: .previewElementCounts,
            stamp: .previewMock, savedAt: Date(timeIntervalSince1970: 1_790_000_000)
        ),
        SavedResult(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000005A2")!, chainID: Chain.previewCountOnly.id,
            nodeID: .previewCountNode, path: [.suffix(100), .countUniqueElements], value: .previewElementCounts,
            stamp: RunStamp(
                sourceName: "mbnet", sourceDisplayName: "MBNet Server",
                dataState: SourceDataState(recordsCount: 11, latestRecord: nil, contentDigest: "older"), chainRevision: 1
            ),
            savedAt: Date(timeIntervalSince1970: 1_780_000_000)
        ),
        SavedResult(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000005A3")!, chainID: Chain.previewCountOnly.id,
            nodeID: .previewCountNode, path: [.countUniqueElements], value: .previewElementCounts,
            stamp: RunStamp(sourceName: "retired", sourceDisplayName: "Retired Server", dataState: .previewMock, chainRevision: 1),
            savedAt: Date(timeIntervalSince1970: 1_770_000_000)
        ),
    ]
}
