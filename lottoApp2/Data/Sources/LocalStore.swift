//
//  LocalStore.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 22/09/2025.
//

import Dependencies
import Foundation

struct LocalStore {
    var save: ([DrawDTO], RemoteSource) -> Date
}

extension LocalStore: DependencyKey {
    static let liveValue = LocalStore(save: { _, _ in Date() })
}

extension LocalStore: TestDependencyKey {
    static let testValue = LocalStore(save: { _, _ in Date() })
    static let previewValue = LocalStore(save: { _, _ in Date() })
}

extension DependencyValues {
  var localStore: LocalStore {
    get { self[LocalStore.self] }
    set { self[LocalStore.self] = newValue }
  }
}
