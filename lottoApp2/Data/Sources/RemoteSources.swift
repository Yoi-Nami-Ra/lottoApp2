//
//  RemoteSources.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 22/09/2025.
//

import Dependencies
import Foundation

nonisolated struct DrawDTO {
    let date: Date
}

nonisolated extension Array where Element == DrawDTO {
    var latest: DrawDTO? { nil }
    var oldest: DrawDTO? { nil }
}

/// Description of single remote source
nonisolated struct RemoteSource {
    let name: String
    let displayName: String
    
    func fetchData() async throws -> [DrawDTO] { [] }
}
