//
//  ChainsRepoImpl.swift
//  lottoApp2
//
//  File-backed `ChainsRepo` (spec 003 research R9): one directory per chain under
//  `Application Support/lottoApp2/chains/<chainID>/`, so deleting a chain is one directory removal.
//

import Foundation
import OSLog

nonisolated enum ChainsRepoImpl {
    /// Rooted at `root/chains`. `live` uses Application Support; tests pass a temp directory.
    static func fileBacked(root: URL) -> ChainsRepo {
        let store = ChainStore(root: root.appendingPathComponent("chains", isDirectory: true))
        return ChainsRepo(
            listChains: { ChainsRepo.listed(await store.listChains()) },
            saveChain: { try await store.save($0) },
            deleteChain: { try await store.delete($0) },
            listResults: { ChainsRepo.listed(await store.listResults($0)) },
            saveResult: { try await store.save($0) },
            deleteResult: { try await store.deleteResult($0) },
            draft: { await store.draft($0) },
            putDraft: { try await store.put($0) },
            deleteDraft: { try await store.deleteDraft($0) }
        )
    }

    static let live: ChainsRepo = {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return fileBacked(root: base.appendingPathComponent("lottoApp2", isDirectory: true))
    }()
}

/// Serializes all access to one chains directory.
private actor ChainStore {
    private let root: URL

    init(root: URL) {
        self.root = root
    }

    func listChains() -> [Chain] {
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []
        return dirs.compactMap { dir in
            let url = Self.chainURL(dir)
            guard let data = try? Data(contentsOf: url) else { return nil }
            do {
                return try JSONDecoder().decode(Chain.self, from: data)
            } catch {
                // One unreadable chain must not hide the others.
                Logger.chains.error("skipping unreadable \(url.path, privacy: .public): \(error)")
                return nil
            }
        }
    }

    func save(_ chain: Chain) throws {
        let dir = chainDir(chain.id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode(chain).write(to: Self.chainURL(dir), options: .atomic)
    }

    func delete(_ id: Chain.ID) throws {
        let dir = chainDir(id)
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.removeItem(at: dir)
    }

    // MARK: Saved results — chains/<chainID>/results/<resultID>.json

    func listResults(_ chainID: Chain.ID) -> [SavedResult] {
        let dir = resultsDir(chainID)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []
        return files.compactMap { decode(SavedResult.self, at: $0) }
    }

    func save(_ result: SavedResult) throws {
        let dir = resultsDir(result.chainID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode(result).write(to: Self.resultURL(dir, result.id), options: .atomic)
    }

    /// Results are addressed by id alone, so the chain directory holding it is found by looking.
    func deleteResult(_ id: SavedResult.ID) throws {
        let chains = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []
        for chain in chains {
            let file = Self.resultURL(chain.appendingPathComponent("results", isDirectory: true), id)
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        }
    }

    // MARK: Drafts — chains/<chainID>/draft.json

    func draft(_ chainID: Chain.ID) -> ChainDraft? {
        decode(ChainDraft.self, at: Self.draftURL(chainDir(chainID)))
    }

    func put(_ draft: ChainDraft) throws {
        let dir = chainDir(draft.chainID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: Self.draftURL(dir), options: .atomic)
    }

    func deleteDraft(_ chainID: Chain.ID) throws {
        let file = Self.draftURL(chainDir(chainID))
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try FileManager.default.removeItem(at: file)
    }

    // MARK: Paths

    private func chainDir(_ id: Chain.ID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func resultsDir(_ chainID: Chain.ID) -> URL {
        chainDir(chainID).appendingPathComponent("results", isDirectory: true)
    }

    /// One unreadable file must not hide the others.
    private func decode<Value: Decodable>(_ type: Value.Type, at url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Logger.chains.error("skipping unreadable \(url.path, privacy: .public): \(error)")
            return nil
        }
    }

    private static func chainURL(_ dir: URL) -> URL { dir.appendingPathComponent("chain.json") }
    private static func draftURL(_ dir: URL) -> URL { dir.appendingPathComponent("draft.json") }
    private static func resultURL(_ dir: URL, _ id: SavedResult.ID) -> URL {
        dir.appendingPathComponent("\(id.uuidString).json")
    }
}

extension Logger {
    fileprivate nonisolated static let chains = Logger(subsystem: "com.yois.lottoApp2", category: "chains")
}
