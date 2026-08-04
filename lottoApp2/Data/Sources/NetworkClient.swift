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
    private static let requestTimeout: TimeInterval = 15
    private static let resourceTimeout: TimeInterval = 60

    /// One shared session for the process. `URLSession(configuration:)` retains itself until it is
    /// invalidated, so building one per request leaks the session and its delegate queue on every sync.
    ///
    /// Stays `.ephemeral` deliberately: the endpoint sends no validators, so letting `URLCache` apply its
    /// heuristic freshness could serve a stale history back as a "successful" sync.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        return URLSession(configuration: configuration)
    }()

    nonisolated static let liveValue = NetworkClient(
        data: { url in
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw Failure.notHTTP }
            guard (200..<300).contains(http.statusCode) else { throw Failure.badStatus(http.statusCode) }
            return data
        }
    )

    /// No live network in tests: fail fast unless explicitly overridden.
    nonisolated static let testValue = NetworkClient(
        data: unimplemented("NetworkClient.data")
    )

    /// Previews get the same fail-fast value. `DependencyKey.previewValue` otherwise defaults to
    /// `liveValue`, which would let a `#Preview` reach the real network.
    nonisolated static var previewValue: NetworkClient { testValue }
}

extension DependencyValues {
    nonisolated var networkClient: NetworkClient {
        get { self[NetworkClient.self] }
        set { self[NetworkClient.self] = newValue }
    }
}
