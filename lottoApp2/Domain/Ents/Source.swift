//
//  Source.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 07/07/2025.
//


import ComposableArchitecture
import Dependencies
import SwiftUI

struct Source: Equatable {
    let name: String
    let displayName: String
    let lastSync: Date
    let recordCount: Int
    let latestRecord: Date
    let firstRecrd: Date
}
