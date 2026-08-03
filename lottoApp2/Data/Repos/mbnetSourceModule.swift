//
//  mbnetSourceModule.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 27/10/2025.
//


protocol SourceModule: Sendable {
    nonisolated var name: String { get }
    nonisolated var displayName: String { get }
}

nonisolated struct mbNetSource: SourceModule {
    var name: String = "mbnet"
    var displayName: String = "MBNet Server"
}

nonisolated struct lottoSource: SourceModule {
    var name: String = "lotto"
    var displayName: String = "Lotto Server"
}

/// Static registry of the sources the app exposes (FR-001: MBNet is present regardless of sync history).
/// Only MBNet has a real remote implementation today; `lottoSource` stays defined for future wiring but is
/// intentionally not registered so no non-functional card is shown.
enum SourceRegistry {
    nonisolated static let all: [any SourceModule] = [mbNetSource()]

    nonisolated static func module(for name: String) -> (any SourceModule)? {
        all.first { $0.name == name }
    }
}
