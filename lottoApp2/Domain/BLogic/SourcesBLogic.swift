//
//  SourcesBLogic.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 07/07/2025.
//

import Dependencies
import Foundation

struct SourcesBLogic {
    enum Error: Swift.Error {
        case somethingWentWrong
    }

    var knownSources: () async -> [Source]
    var fetchFrom: (String) async -> Result<Source, Error>
}

extension SourcesBLogic: DependencyKey {
    static let liveValue = SourcesBLogic(
        knownSources: {
            @Dependency(\.sorcesRepo) var repo
            return await repo.listKnownSources()
        },
        fetchFrom: {
            @Dependency(\.sorcesRepo) var repo
            return await repo.fetchAndSaveDataFrom($0).mapError { _ in .somethingWentWrong } //TODO: re-implement
        }
    )
}

extension DependencyValues {
  var blSources: SourcesBLogic {
    get { self[SourcesBLogic.self] }
    set { self[SourcesBLogic.self] = newValue }
  }
}

extension Source {
    static let mbnetMock: Source = .init(
        name: "mbnet",
        displayName: "MBNet Server",
        lastSync: Date(timeIntervalSinceNow: -100000),
        recordCount: 120,
        latestRecord: Date(timeIntervalSinceNow: -180000),
        firstRecrd: Date(timeIntervalSince1970: 18223210)
    )

    static let lottoMock: Source = .init(
        name: "lotto",
        displayName: "Lotto Server",
        lastSync: Date(timeIntervalSinceNow: -432000),
        recordCount: 110,
        latestRecord: Date(timeIntervalSinceNow: -600000),
        firstRecrd: Date(timeIntervalSince1970: 18223210)
    )
}
