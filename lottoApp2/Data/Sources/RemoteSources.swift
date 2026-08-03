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

nonisolated extension Array where Element == DrawDTO {
    var latest: DrawDTO? { self.max { $0.date < $1.date } }
    var oldest: DrawDTO? { self.min { $0.date < $1.date } }
}

/// Description of a single remote source and how to fetch its draws.
nonisolated struct RemoteSource: Sendable {
    let name: String
    let displayName: String
    var fetchData: @Sendable () async throws -> [DrawDTO]
}

enum RemoteSourceError: Swift.Error, Equatable {
    case unsupportedSource(String)
    case undecodableBody
}

/// The MBNet endpoint (plain HTTP — requires an ATS exception for `www.mbnet.com.pl`).
private let mbnetURL = URL(string: "http://www.mbnet.com.pl/dl.txt")!

nonisolated struct RemoteSourcesManager {
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
            let module = SourceRegistry.module(for: name)
            let displayName = module?.displayName ?? name

            switch name {
            case "mbnet":
                return RemoteSource(name: name, displayName: displayName) {
                    @Dependency(\.networkClient) var networkClient
                    let data = try await networkClient.data(mbnetURL)
                    guard let text = String(data: data, encoding: .utf8) else {
                        throw RemoteSourceError.undecodableBody
                    }
                    return MBNetParser.parse(text).draws
                }
            default:
                return RemoteSource(name: name, displayName: displayName) {
                    throw RemoteSourceError.unsupportedSource(name)
                }
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
