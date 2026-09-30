//
//  LocalStore.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 22/09/2025.
//

import CryptoKit
import Dependencies
import Foundation

nonisolated struct LocalStore: Sendable {
    /// Additively merges `draws` into the stored set for `source` (keyed on ordinal index — never deletes)
    /// and persists them together with the derived `SourceMeta`, stamped `asOf`.
    var save: @Sendable ([DrawDTO], RemoteSource, _ asOf: Date) async throws -> Void
    var listSourceMetaFor: @Sendable ([String]) async -> [String: SourceMeta]
    /// Reads back the persisted draws for a source (used to verify persistence; no UI consumer yet).
    var listDrawsFor: @Sendable (String) async -> [DrawDTO]
}

/// Persisted source-level analytics. Record dates are optional so an empty history (count 0) is representable.
///
/// Deliberately does *not* persist the display name: that is owned by `SourceRegistry` in code, and a stored
/// copy would shadow it forever once a source had synced once.
nonisolated struct SourceMeta: Codable, Equatable, Sendable {
    let name: String
    let lastSync: Date
    let recordsCount: Int
    let latestRecord: Date?
    let firstRecord: Date?
    /// SHA-256 over the stored draws, so results can tell a sync that changed a draw in place (spec 003 R8).
    /// Empty for a `meta.json` written before the digest existed; the next sync writes it.
    let contentDigest: String
}

nonisolated extension SourceMeta {
    private enum CodingKeys: String, CodingKey {
        case name, lastSync, recordsCount, latestRecord, firstRecord, contentDigest
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            lastSync: try container.decode(Date.self, forKey: .lastSync),
            recordsCount: try container.decode(Int.self, forKey: .recordsCount),
            latestRecord: try container.decodeIfPresent(Date.self, forKey: .latestRecord),
            firstRecord: try container.decodeIfPresent(Date.self, forKey: .firstRecord),
            contentDigest: try container.decodeIfPresent(String.self, forKey: .contentDigest) ?? ""
        )
    }
}

extension LocalStore {
    /// Additive union keyed on `index`: existing draws not present in `incoming` are retained; same-index
    /// draws are updated; the result is de-duplicated and sorted by index (FR-008).
    nonisolated static func merged(existing: [DrawDTO], incoming: [DrawDTO]) -> [DrawDTO] {
        var byIndex = Dictionary(existing.map { ($0.index, $0) }, uniquingKeysWith: { _, latest in latest })
        for draw in incoming { byIndex[draw.index] = draw }
        return byIndex.values.sorted { $0.index < $1.index }
    }

    /// A digest of the draws' content: one canonical line per draw, index-sorted, numbers ascending, so the
    /// order draws or their numbers arrive in doesn't change it but any changed draw does.
    nonisolated static func digest(of draws: [DrawDTO]) -> String {
        let canonical = draws
            .sorted { $0.index < $1.index }
            .map { "\($0.index)|\($0.date.timeIntervalSince1970)|\($0.numbers.sorted().map(String.init).joined(separator: ","))" }
            .joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// File-backed store rooted at `root`. `liveValue` uses Application Support; tests pass a temp directory.
    nonisolated static func fileBacked(root: URL) -> LocalStore {
        let store = FileStore(root: root)
        return LocalStore(
            save: { draws, source, asOf in try await store.save(draws, source, asOf: asOf) },
            listSourceMetaFor: { await store.listSourceMetaFor($0) },
            listDrawsFor: { await store.listDrawsFor($0) }
        )
    }

    /// In-memory store for `#Preview`s, so rendering a card never touches Application Support.
    nonisolated static func inMemory() -> LocalStore {
        let store = MemoryStore()
        return LocalStore(
            save: { draws, source, asOf in await store.save(draws, source, asOf: asOf) },
            listSourceMetaFor: { await store.listSourceMetaFor($0) },
            listDrawsFor: { await store.listDrawsFor($0) }
        )
    }

    /// Derives the persisted analytics from the *merged* set, so the card reflects everything stored for the
    /// source rather than just the rows this fetch happened to return (FR-005/SC-002).
    fileprivate nonisolated static func meta(name: String, draws: [DrawDTO], asOf: Date) -> SourceMeta {
        SourceMeta(
            name: name,
            lastSync: asOf,
            recordsCount: draws.count,
            latestRecord: draws.map(\.date).max(),
            firstRecord: draws.map(\.date).min(),
            contentDigest: digest(of: draws)
        )
    }
}

/// Serializes all access to one root directory.
///
/// `save` is a read-modify-write over `draws.json`, so two overlapping saves for the same source would
/// otherwise interleave and drop draws — exactly what FR-008 forbids.
private actor FileStore {
    private let root: URL

    init(root: URL) {
        self.root = root
    }

    func save(_ draws: [DrawDTO], _ source: RemoteSource, asOf: Date) throws {
        let dir = Self.sourceDir(root: root, name: source.name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let merged = LocalStore.merged(existing: loadDraws(source.name), incoming: draws)
        // Draws first, then meta: a crash between the two leaves meta *behind* the stored draws, which the
        // next sync corrects. The reverse order would leave meta claiming records that were never written.
        try JSONEncoder().encode(merged).write(to: Self.drawsURL(dir), options: .atomic)
        let meta = LocalStore.meta(name: source.name, draws: merged, asOf: asOf)
        try JSONEncoder().encode(meta).write(to: Self.metaURL(dir), options: .atomic)
    }

    func listSourceMetaFor(_ names: [String]) -> [String: SourceMeta] {
        var result: [String: SourceMeta] = [:]
        for name in names {
            let url = Self.metaURL(Self.sourceDir(root: root, name: name))
            if let data = try? Data(contentsOf: url),
               let meta = try? JSONDecoder().decode(SourceMeta.self, from: data) {
                result[name] = meta
            }
        }
        return result
    }

    func listDrawsFor(_ name: String) -> [DrawDTO] { loadDraws(name) }

    private func loadDraws(_ name: String) -> [DrawDTO] {
        let url = Self.drawsURL(Self.sourceDir(root: root, name: name))
        guard let data = try? Data(contentsOf: url),
              let draws = try? JSONDecoder().decode([DrawDTO].self, from: data)
        else { return [] }
        return draws
    }

    private static func sourceDir(root: URL, name: String) -> URL {
        root.appendingPathComponent("sources", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }
    private static func drawsURL(_ dir: URL) -> URL { dir.appendingPathComponent("draws.json") }
    private static func metaURL(_ dir: URL) -> URL { dir.appendingPathComponent("meta.json") }
}

/// Preview-only sibling of `FileStore` with the same merge semantics and no I/O.
private actor MemoryStore {
    private var draws: [String: [DrawDTO]] = [:]
    private var meta: [String: SourceMeta] = [:]

    func save(_ incoming: [DrawDTO], _ source: RemoteSource, asOf: Date) {
        let merged = LocalStore.merged(existing: draws[source.name] ?? [], incoming: incoming)
        draws[source.name] = merged
        meta[source.name] = LocalStore.meta(name: source.name, draws: merged, asOf: asOf)
    }

    func listSourceMetaFor(_ names: [String]) -> [String: SourceMeta] {
        meta.filter { names.contains($0.key) }
    }

    func listDrawsFor(_ name: String) -> [DrawDTO] { draws[name] ?? [] }
}

extension LocalStore: nonisolated DependencyKey {
    nonisolated static let liveValue: LocalStore = {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return .fileBacked(root: base.appendingPathComponent("lottoApp2", isDirectory: true))
    }()

    /// Disk-backed live value, so tests must opt in explicitly (Principle IV: never real I/O in a test).
    nonisolated static let testValue = LocalStore(
        save: unimplemented("LocalStore.save"),
        listSourceMetaFor: unimplemented("LocalStore.listSourceMetaFor", placeholder: [:]),
        listDrawsFor: unimplemented("LocalStore.listDrawsFor", placeholder: [])
    )

    nonisolated static var previewValue: LocalStore { .inMemory() }
}

extension DependencyValues {
    nonisolated var localStore: LocalStore {
        get { self[LocalStore.self] }
        set { self[LocalStore.self] = newValue }
    }
}
