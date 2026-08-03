//
//  NetworkClient.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 30/07/2026.
//

import Dependencies
import Foundation

/// Minimal injectable HTTP GET seam so the Data layer can fetch over the network without reducers/repos
/// constructing `URLSession` directly (Constitution Principle IV). Overridden with canned data in tests.
nonisolated struct NetworkClient: Sendable {
    /// Performs a GET for `url`, returning the raw body. Throws on transport failure or a non-2xx status.
    var data: @Sendable (_ url: URL) async throws -> Data
}

extension NetworkClient {
    enum Failure: Swift.Error, Equatable {
        case badStatus(Int)
        case notHTTP
    }
}

extension NetworkClient: nonisolated DependencyKey {
    nonisolated static let liveValue = NetworkClient(
        data: { url in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            let session = URLSession(configuration: configuration)
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw Failure.notHTTP }
            guard (200..<300).contains(http.statusCode) else { throw Failure.badStatus(http.statusCode) }
            return data
        }
    )

    /// No live network in tests/previews: fail fast unless explicitly overridden.
    nonisolated static let testValue = NetworkClient(
        data: unimplemented("NetworkClient.data")
    )
}

extension DependencyValues {
    nonisolated var networkClient: NetworkClient {
        get { self[NetworkClient.self] }
        set { self[NetworkClient.self] = newValue }
    }
}
