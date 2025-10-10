//
//  SourcesRepo.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 19/09/2025.
//

import Foundation
import Dependencies

struct SorcesRepo {
    enum Error: Swift.Error {
        case weFailed
        case failedToFetchData /// general fail to fetch current data from given server
    }

    var fetchAndSaveDataFrom: (String) async -> Result<Source, Error>
}

extension DependencyValues {
  var sorcesRepo: SorcesRepo {
    get { self[SorcesRepo.self] }
    set { self[SorcesRepo.self] = newValue }
  }
}

extension SorcesRepo: TestDependencyKey { // TODO: Implement
    static let testValue = SorcesRepo(fetchAndSaveDataFrom: { _ in
            .success(.mbnetMock)
    })
    static let previewValue = SorcesRepo(fetchAndSaveDataFrom: { _ in
            .success(.mbnetMock)
    })
}
