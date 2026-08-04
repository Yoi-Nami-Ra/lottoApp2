//
//  mbnetSourceModule.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 27/10/2025.
//

import Dependencies
import Foundation

/// A statically registered lottery source: its identity plus how to fetch and parse its own draws.
///
/// Owning `fetchDraws()` here keeps `SourceRegistry` the single place a source is declared — registering a
/// module is enough to make it fetchable, so the registry and the fetch path cannot drift apart.
protocol SourceModule: Sendable {
    nonisolated var name: String { get }
    nonisolated var displayName: String { get }
    /// Fetches the source's published history. Throws on transport/status/decode failure, and when the body
    /// arrives but yields no usable rows (schema drift — `RemoteSourceError.unparseableBody`).
    nonisolated func fetchDraws() async throws -> FetchedDraws
}

nonisolated struct MBNetSource: SourceModule {
    /// Plain HTTP — requires the ATS exception for `www.mbnet.com.pl` (see `Config/Info.plist`).
    private static let endpoint = URL(string: "http://www.mbnet.com.pl/dl.txt")!

    let name = "mbnet"
    let displayName = "MBNet Server"

    func fetchDraws() async throws -> FetchedDraws {
        @Dependency(\.networkClient) var networkClient

        let data = try await networkClient.data(Self.endpoint)
        guard let text = String(data: data, encoding: .utf8) else {
            throw RemoteSourceError.undecodableBody
        }

        let parsed = MBNetParser.parse(text)
        // FR-006 / spec Edge Cases → Schema drift: rows were present but none were usable, so the format
        // changed — fail rather than stamp a successful sync that stored nothing. A genuinely empty body
        // (no rows at all) still succeeds as the "empty history" case.
        guard !(parsed.draws.isEmpty && parsed.skipped > 0) else {
            throw RemoteSourceError.unparseableBody(skipped: parsed.skipped)
        }
        return parsed
    }
}

/// Static registry of the sources the app exposes (FR-001: MBNet is present regardless of sync history).
enum SourceRegistry {
    nonisolated static let all: [any SourceModule] = [MBNetSource()]

    nonisolated static func module(for name: String) -> (any SourceModule)? {
        all.first { $0.name == name }
    }
}
