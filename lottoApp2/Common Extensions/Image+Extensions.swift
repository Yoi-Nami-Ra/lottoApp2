//
//  Image+Extensioons.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 24/07/2025.
//

import SwiftUI

enum ImageType {
    case system(String)
    case asset(String)
}

extension Image {
    init(_ imageType: ImageType) {
        switch imageType {
        case .system(let name): self.init(systemName: name)
        case .asset(let name): self.init(name)
        }
    }
}
