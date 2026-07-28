//
//  Source.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 07/07/2025.
//


import ComposableArchitecture
import Dependencies
import SwiftUI

nonisolated struct Source: Equatable {
    let name: String
    let displayName: String
    let lastSync: Date?
    let recordsCount: Int?
    let latestRecord: Date?
    let firstRecrd: Date?

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
        self.firstRecrd = firstRecord
    }
}
