//
//  SyncFailureClassificationTests.swift
//  lottoApp2Tests
//
//  Created by Jarosław Wojtasik on 30/09/2026.
//

import Foundation
import Testing

@testable import lottoApp2

/// One row of spec 004 research R3: what the fetch step threw, and the kind the user is told about.
nonisolated struct ClassificationRow: Sendable, CustomTestStringConvertible {
    let error: any Error & Sendable
    let expected: SyncFailure

    var testDescription: String { "\(error) → \(expected)" }
}

struct SyncFailureClassification_Tests {

    nonisolated static let rows: [ClassificationRow] = [
        // Cancelled — not a failure, never shown (FR-007).
        .init(error: CancellationError(), expected: .cancelled),
        .init(error: URLError(.cancelled), expected: .cancelled),
        // Offline — only when the device itself has no usable connection (Q3).
        .init(error: URLError(.notConnectedToInternet), expected: .offline),
        .init(error: URLError(.dataNotAllowed), expected: .offline),
        .init(error: URLError(.internationalRoamingOff), expected: .offline),
        // Every other transport failure — the server's side may be at fault, so "try again later" (Q3).
        .init(error: URLError(.timedOut), expected: .serverUnreachable),
        .init(error: URLError(.networkConnectionLost), expected: .serverUnreachable),
        .init(error: URLError(.cannotFindHost), expected: .serverUnreachable),
        .init(error: URLError(.cannotConnectToHost), expected: .serverUnreachable),
        // Status codes keep their number; the message picks its wording from it (FR-004, Q2).
        .init(error: NetworkClient.Failure.badStatus(503), expected: .serverError(status: 503)),
        .init(error: NetworkClient.Failure.badStatus(404), expected: .serverError(status: 404)),
        .init(error: NetworkClient.Failure.notHTTP, expected: .unknown),
        // The source module's own failures.
        .init(error: RemoteSourceError.unsupportedSource("x"), expected: .sourceUnavailable),
        .init(error: RemoteSourceError.undecodableBody, expected: .unreadableData),
        .init(error: RemoteSourceError.unparseableBody(skipped: 2), expected: .unreadableData),
        // Anything else is reported, never swallowed (spec Edge Cases → Unrecognised failure).
        .init(error: CocoaError(.fileWriteOutOfSpace), expected: .unknown),
    ]

    @Test(arguments: rows)
    func classifiesTheFetchError(_ row: ClassificationRow) {
        #expect(SyncFailure(classifying: row.error) == row.expected)
    }
}
