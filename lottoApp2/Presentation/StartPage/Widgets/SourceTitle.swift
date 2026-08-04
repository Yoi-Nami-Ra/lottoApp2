//
//  SourceTitle.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 03/09/2025.
//

import SwiftUI

struct SourceTitle: View {
    let title: String
    
    var body: some View {
        Text(title)
            .modifier(SourceTitleStyle.sourceTitle)
    }
}

struct SourceTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.sourceTitle)
            .fontWeight(.sourceTitle)
            .foregroundStyle(Color.sourceTitle)
    }
}

extension ViewModifier where Self == SourceTitleStyle {
    static var sourceTitle: SourceTitleStyle { .init() }
}

extension Font {
    fileprivate static let sourceTitle: Self = .title
}

extension Font.Weight {
    fileprivate static let sourceTitle: Self = .semibold
}

extension Color {
    fileprivate static let sourceTitle: Self = .primary
}

#Preview("Light Mode") {
    SourceTitle(title: .previewTitle)
        .padding(.previewPadding)
        .background(.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    SourceTitle(title: .previewTitle)
        .padding(.previewPadding)
        .background(.backgroundPrimary)
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - long title") {
    SourceTitle(title: .previewLongTitle)
        .padding(.previewPadding)
        .background(.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("Dark Mode - long title") {
    SourceTitle(title: .previewLongTitle)
        .padding(.previewPadding)
        .background(.backgroundPrimary)
        .preferredColorScheme(.dark)
}

extension String {
    fileprivate static let previewTitle = "MBNet Server"
    fileprivate static let previewLongTitle = "EuroJackpot International Server"
}

extension CGFloat {
    fileprivate static let previewPadding: Self = 10
}
