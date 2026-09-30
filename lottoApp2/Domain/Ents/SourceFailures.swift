//
//  SourceFailures.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 30/09/2026.
//

import Foundation

/// Why a sync of one source did not complete (spec 004 FR-001).
///
/// Produced once, in the Data layer, and passed through unchanged up to the source card (FR-002), so each
/// kind can get a message that tells the user what to do.
nonisolated enum SyncFailure: Error, Equatable, Sendable {
    /// The device reports no connection, or cellular data or roaming is turned off.
    case offline
    /// Any other transport failure: a timeout, a dropped connection, an unknown or refusing host.
    case serverUnreachable
    /// The server answered with a non-2xx status.
    case serverError(status: Int)
    /// The body isn't text, or none of its rows reads as a draw — the source's format changed.
    case unreadableData
    /// No registered source has this id.
    case sourceUnavailable
    /// The draws couldn't be saved on the device, or the saved details couldn't be read back.
    case storageFailure
    /// Anything that fits none of the kinds above.
    case unknown
    /// Not a failure: the sync was cancelled. Never shown to the user (FR-007).
    case cancelled
}

/// Why a source's stored draws couldn't be read for a run (spec 004 FR-008).
nonisolated enum SourceReadFailure: Error, Equatable, Sendable {
    /// No registered source has this id.
    case sourceUnavailable
    /// A stored draw breaks the source's game shape.
    case unreadableStoredDraws
}
