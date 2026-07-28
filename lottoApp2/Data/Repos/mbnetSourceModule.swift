//
//  mbnetSourceModule.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 27/10/2025.
//


protocol SourceModule {
    var name: String { get }
    var displayName: String { get }
}

struct mbNetSource: SourceModule {
    var name: String = "mbnet"
    var displayName: String = "MBNet"
}

struct lottoSource: SourceModule {
    var name: String = "lotto"
    var displayName: String = "Lotto Server"
}
