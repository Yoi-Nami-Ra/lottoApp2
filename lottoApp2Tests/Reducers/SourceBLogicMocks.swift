//
//  SourceBLogicMocks.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 15/10/2025.
//

@testable import lottoApp2

extension SourcesBLogic {
    static let mock = SourcesBLogic(
        knownSources: { [.mbnetMock, .lottoMock] },
        fetchFrom: { _ in .success(.mbnetMock) }
    )
}
