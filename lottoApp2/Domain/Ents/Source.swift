//
//  Source.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 07/07/2025.
//

import Foundation

/// A lottery data source and its derived sync analytics. Analytics are `nil` until the first successful sync.
nonisolated struct Source: Equatable, Sendable {
    let name: String
    let displayName: String
    let lastSync: Date?
    let recordsCount: Int?
    let latestRecord: Date?
    let firstRecord: Date?

    init(
        name: String,
        displayName: String,
        lastSync: Date? = nil,
        recordsCount: Int? = nil,
        latestRecord: Date? = nil,
        firstRecord: Date? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.lastSync = lastSync
        self.recordsCount = recordsCount
        self.latestRecord = latestRecord
        self.firstRecord = firstRecord
    }
}
