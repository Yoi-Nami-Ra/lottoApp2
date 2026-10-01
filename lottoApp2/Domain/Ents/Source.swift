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
    /// Records the last successful sync skipped, because they couldn't be read or broke the game rules
    /// (spec 005). `nil` until the first successful sync, like the other analytics.
    let lastSyncSkipped: Int?
    /// How often the source publishes, measured at its last successful sync (spec 009). `nil` before the first
    /// sync, for metadata written before the cadence existed, and when the history is too short to measure.
    let cadence: DrawCadence?

    init(
        name: String,
        displayName: String,
        lastSync: Date? = nil,
        recordsCount: Int? = nil,
        latestRecord: Date? = nil,
        firstRecord: Date? = nil,
        lastSyncSkipped: Int? = nil,
        cadence: DrawCadence? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.lastSync = lastSync
        self.recordsCount = recordsCount
        self.latestRecord = latestRecord
        self.firstRecord = firstRecord
        self.lastSyncSkipped = lastSyncSkipped
        self.cadence = cadence
    }
}
