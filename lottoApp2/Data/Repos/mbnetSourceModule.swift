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
    /// The shape of the source's draws, which every stored draw is read into (spec 003 FR-002).
    nonisolated var gameType: GameType { get }
    /// Fetches and parses the source's published history. Throws on transport/status/decode failure. A body
    /// whose rows yield no usable draw is rejected by the shared fetch step (`FetchedDraws.validated(against:)`),
    /// which also drops draws that break `gameType`'s rules — so a module only parses.
    nonisolated func fetchDraws() async throws -> FetchedDraws
}

nonisolated struct MBNetSource: SourceModule {
    /// Plain HTTP — requires the ATS exception for `www.mbnet.com.pl` (see `Config/Info.plist`).
    private static let endpoint = URL(string: "http://www.mbnet.com.pl/dl.txt")!

    let name = "mbnet"
    let displayName = "MBNet Server"
    // A literal, known-valid shape: 6 of 49.
    let gameType = GameType(id: "lotto-6-49", name: "Lotto", combinationType: try! CombinationType(pick: 6, pool: 49))

    func fetchDraws() async throws -> FetchedDraws {
        @Dependency(\.networkClient) var networkClient

        let data = try await networkClient.data(Self.endpoint)
        guard let text = String(data: data, encoding: .utf8) else {
            throw RemoteSourceError.undecodableBody
        }

        // Schema drift (rows present, none usable) is caught after validation, in the shared fetch step.
        return MBNetParser.parse(text)
    }
}

/// Static registry of the sources the app exposes (FR-001: MBNet is present regardless of sync history).
enum SourceRegistry {
    nonisolated static let all: [any SourceModule] = [MBNetSource()]

    nonisolated static func module(for name: String) -> (any SourceModule)? {
        all.first { $0.name == name }
    }
}
