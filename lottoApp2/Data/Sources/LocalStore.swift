//
//  LocalStore.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 22/09/2025.
//

import Dependencies
import Foundation

nonisolated struct LocalStore {
    /// Additively merges `draws` into the stored set for `source` (keyed on ordinal index — never deletes),
    /// persists them and the derived `SourceMeta`, and returns the sync timestamp.
    var save: @Sendable ([DrawDTO], RemoteSource) async throws -> Date
    var listSourceMetaFor: @Sendable ([String]) async -> [String: SourceMeta]
    /// Reads back the persisted draws for a source (used to verify persistence; no UI consumer yet).
    var listDrawsFor: @Sendable (String) async -> [DrawDTO]
}

/// Persisted source-level analytics. Record dates are optional so an empty history (count 0) is representable.
nonisolated struct SourceMeta: Codable, Equatable, Sendable {
    let name: String
    let displayName: String
    let lastSync: Date
    let recordsCount: Int
    let latestRecord: Date?
    let firstRecrd: Date?
}

extension LocalStore {
    /// Additive union keyed on `index`: existing draws not present in `incoming` are retained; same-index
    /// draws are updated; the result is de-duplicated and sorted by index (FR-008).
    nonisolated static func merged(existing: [DrawDTO], incoming: [DrawDTO]) -> [DrawDTO] {
        var byIndex = Dictionary(existing.map { ($0.index, $0) }, uniquingKeysWith: { _, keep in keep })
        for draw in incoming { byIndex[draw.index] = draw }
        return byIndex.values.sorted { $0.index < $1.index }
    }

    /// File-backed store rooted at `root`. `liveValue` uses Application Support; tests pass a temp directory.
    nonisolated static func fileBacked(root: URL) -> LocalStore {
        LocalStore(
            save: { draws, source in
                @Dependency(\.date) var date
                let now = date.now
                let dir = sourceDir(root: root, name: source.name)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                let merged = merged(existing: loadDraws(root: root, name: source.name), incoming: draws)
                try JSONEncoder().encode(merged).write(to: drawsURL(dir), options: .atomic)

                let meta = SourceMeta(
                    name: source.name,
                    displayName: source.displayName,
                    lastSync: now,
                    recordsCount: merged.count,
                    latestRecord: merged.map(\.date).max(),
                    firstRecrd: merged.map(\.date).min()
                )
                try JSONEncoder().encode(meta).write(to: metaURL(dir), options: .atomic)
                return now
            },
            listSourceMetaFor: { names in
                var result: [String: SourceMeta] = [:]
                for name in names {
                    let url = metaURL(sourceDir(root: root, name: name))
                    if let data = try? Data(contentsOf: url),
                       let meta = try? JSONDecoder().decode(SourceMeta.self, from: data) {
                        result[name] = meta
                    }
                }
                return result
            },
            listDrawsFor: { name in loadDraws(root: root, name: name) }
        )
    }

    private nonisolated static func sourceDir(root: URL, name: String) -> URL {
        root.appendingPathComponent("sources", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }
    private nonisolated static func drawsURL(_ dir: URL) -> URL { dir.appendingPathComponent("draws.json") }
    private nonisolated static func metaURL(_ dir: URL) -> URL { dir.appendingPathComponent("meta.json") }

    private nonisolated static func loadDraws(root: URL, name: String) -> [DrawDTO] {
        let url = drawsURL(sourceDir(root: root, name: name))
        guard let data = try? Data(contentsOf: url),
              let draws = try? JSONDecoder().decode([DrawDTO].self, from: data)
        else { return [] }
        return draws
    }
}

extension LocalStore: nonisolated DependencyKey {
    nonisolated static let liveValue: LocalStore = {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return .fileBacked(root: base.appendingPathComponent("lottoApp2", isDirectory: true))
    }()
}

extension DependencyValues {
    nonisolated var localStore: LocalStore {
        get { self[LocalStore.self] }
        set { self[LocalStore.self] = newValue }
    }
}
