//
//  SyncFailureClassification.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 30/09/2026.
//

import Foundation

nonisolated extension SyncFailure {
    /// Classifies what a source's fetch threw (spec 004 research R3).
    ///
    /// Lives in the Data layer because it knows `URLError`, `NetworkClient.Failure` and `RemoteSourceError`;
    /// the Domain only ever sees the resulting kind. Only the fetch step goes through here — a store failure
    /// can't be told apart by its type, so `SourcesRepoImpl` maps those at the step that failed.
    init(classifying error: any Error) {
        switch error {
        case is CancellationError:
            self = .cancelled
        case let error as URLError:
            self = Self.transport(error.code)
        case let error as NetworkClient.Failure:
            switch error {
            case .badStatus(let status): self = .serverError(status: status)
            case .notHTTP: self = .unknown
            }
        case let error as RemoteSourceError:
            switch error {
            case .unsupportedSource: self = .sourceUnavailable
            case .undecodableBody, .unparseableBody: self = .unreadableData
            }
        default:
            self = .unknown
        }
    }

    /// "Offline" only when the device itself has no usable connection; every other transport failure may be
    /// the server's side, so it reads as unreachable (spec 004 Q3).
    private static func transport(_ code: URLError.Code) -> SyncFailure {
        switch code {
        case .cancelled:
            .cancelled
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            .offline
        default:
            .serverUnreachable
        }
    }
}
