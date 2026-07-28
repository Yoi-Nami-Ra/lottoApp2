//
//  LocalStore.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 22/09/2025.
//

import Dependencies
import Foundation

nonisolated struct LocalStore {
    var save: @Sendable ([DrawDTO], RemoteSource) -> Date
    var listSourceMetaFor: @Sendable ([String]) async -> [String: SourceMeta]
}

nonisolated struct SourceMeta {
    let name: String
    let displayName: String
    let lastSync: Date
    let recordsCount: Int
    let latestRecord: Date
    let firstRecrd: Date
}

extension LocalStore: DependencyKey {
    static let liveValue = LocalStore(
        save: { _, _ in Date() },
        listSourceMetaFor: { _ in [:] }
    )
}

//extension LocalStore: TestDependencyKey {
//    static let testValue = LocalStore(save: { _, _ in Date() })
//    static let previewValue = LocalStore(save: { _, _ in Date() })
//}

extension DependencyValues {
  nonisolated var localStore: LocalStore {
    get { self[LocalStore.self] }
    set { self[LocalStore.self] = newValue }
  }
}
