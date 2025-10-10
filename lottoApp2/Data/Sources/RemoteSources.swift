//
//  RemoteSources.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 22/09/2025.
//

import Dependencies
import Foundation

struct DrawDTO {
    let date: Date
}

extension Array where Element == DrawDTO {
    var latest: DrawDTO? { nil }
    var oldest: DrawDTO? { nil }
}

/// Description of single remote source
struct RemoteSource {
    let name: String
    let displayName: String
    
    func fetchData() async throws -> [DrawDTO] { [] }
}

struct RemoteSourcesManager {
    var sourceFor: (String) async -> RemoteSource
}

extension RemoteSourcesManager: DependencyKey {
    static let liveValue = RemoteSourcesManager(sourceFor: { _ in RemoteSource(name: "a", displayName: "b") })
}

extension RemoteSourcesManager: TestDependencyKey {
    static let testValue = RemoteSourcesManager(sourceFor: { _ in RemoteSource(name: "a", displayName: "b") })
    static let previewValue = RemoteSourcesManager(sourceFor: { _ in RemoteSource(name: "a", displayName: "b") })
}

extension DependencyValues {
  var remoteSourcesManager: RemoteSourcesManager {
    get { self[RemoteSourcesManager.self] }
    set { self[RemoteSourcesManager.self] = newValue }
  }
}
