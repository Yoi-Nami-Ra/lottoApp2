//
//  RemoteSources.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 22/09/2025.
//

import Dependencies
import Foundation

/// A single parsed draw: ordinal index (de-dup key), date, and the six drawn numbers (each 1…49).
nonisolated struct DrawDTO: Equatable, Codable, Sendable {
    let index: Int
    let date: Date
    let numbers: [Int]
}

/// The outcome of fetching one source: the well-formed draws plus how many rows were unusable.
///
/// `skipped` travels with the draws so the caller can report it (FR-007) instead of it dying at the parser.
nonisolated struct FetchedDraws: Equatable, Sendable {
    var draws: [DrawDTO]
    var skipped: Int
}

/// Description of a single remote source and how to fetch its draws.
nonisolated struct RemoteSource: Sendable {
    let name: String
    let displayName: String
    var fetchData: @Sendable () async throws -> FetchedDraws
}

enum RemoteSourceError: Swift.Error, Equatable {
    case unsupportedSource(String)
    case undecodableBody
    /// The body decoded but every row was malformed — a format change, not an empty history (FR-006).
    case unparseableBody(skipped: Int)
}

nonisolated struct RemoteSourcesManager: Sendable {
    var listAllSources: @Sendable () async -> [String]
    var listDisplayNamesFor: @Sendable ([String]) async -> [String: String]
    var sourceFor: @Sendable (String) async -> RemoteSource
}

extension RemoteSourcesManager: nonisolated DependencyKey {
    nonisolated static let liveValue = RemoteSourcesManagerImp.live
}

nonisolated struct RemoteSourcesManagerImp {
    nonisolated static let live: RemoteSourcesManager = .init(
        listAllSources: {
            SourceRegistry.all.map(\.name)
        },
        listDisplayNamesFor: { names in
            var result: [String: String] = [:]
            for name in names {
                if let module = SourceRegistry.module(for: name) {
                    result[name] = module.displayName
                }
            }
            return result
        },
        sourceFor: { name in
            guard let module = SourceRegistry.module(for: name) else {
                return RemoteSource(name: name, displayName: name) {
                    throw RemoteSourceError.unsupportedSource(name)
                }
            }
            return RemoteSource(name: module.name, displayName: module.displayName) {
                try await module.fetchDraws()
            }
        }
    )
}

extension DependencyValues {
    nonisolated var remoteSourcesManager: RemoteSourcesManager {
        get { self[RemoteSourcesManager.self] }
        set { self[RemoteSourcesManager.self] = newValue }
    }
}
