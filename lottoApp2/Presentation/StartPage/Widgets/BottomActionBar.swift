//
//  BottomActionBar.swift
//  lottoApp2
//
//  Created by Jarosław Wojtasik on 16/08/2026.
//

import SwiftUI

/// The bar pinned below the source list, carrying the single action that moves the flow forward.
///
/// It owns no state: enablement is decided by the reducer (`StartPage.State.isNextEnabled`) and the tap is
/// forwarded straight back, so there is nothing here for a `@Reducer` to hold.
struct BottomActionBar: View {
    let isNextEnabled: Bool
    let nextTapped: () -> Void

    var body: some View {
        Button(action: nextTapped) {
            Text(.nextButton)
                .font(.nextLabel)
                .fontWeight(.nextLabel)
                .foregroundStyle(Color.nextForeground(isEnabled: isNextEnabled))
                .frame(maxWidth: .infinity)
                .padding(.vertical, .nextVPadding)
                .background(Color.nextBackground(isEnabled: isNextEnabled))
                .cornerRadius(.nextCorners)
        }
        .buttonStyle(PlainButtonStyle())
        // Carries the not-enabled trait to assistive technology, so "why can't I continue?" is
        // answerable without sight of the dimmed colour.
        .disabled(isNextEnabled == false)
        .padding(.horizontal, .barHPadding)
        .padding(.vertical, .barVPadding)
        .frame(maxWidth: .infinity)
        .background(Color.barBackground)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Resources
extension Color {
    /// A `switch`-free pair of functions rather than inline ternaries, so both states are named.
    fileprivate static func nextForeground(isEnabled: Bool) -> Self {
        isEnabled ? .nextEnabledForeground : .nextDisabledForeground
    }

    fileprivate static func nextBackground(isEnabled: Bool) -> Self {
        isEnabled ? .nextEnabledBackground : .nextDisabledBackground
    }

    fileprivate static let nextEnabledForeground: Self = .backgroundPrimary
    fileprivate static let nextDisabledForeground: Self = .textTertiary
    fileprivate static let nextEnabledBackground: Self = .primaryBlue
    fileprivate static let nextDisabledBackground: Self = .undefinedGrey.opacity(.disabledBackground)
    fileprivate static let barBackground: Self = .backgroundPrimary
}

extension Font {
    fileprivate static let nextLabel: Self = .headline
}

extension Font.Weight {
    fileprivate static let nextLabel: Self = .semibold
}

extension CGFloat {
    fileprivate static let nextVPadding: Self = 14
    fileprivate static let nextCorners: Self = 12
    fileprivate static let barHPadding: Self = 16
    fileprivate static let barVPadding: Self = 12
}

extension Double {
    fileprivate static let disabledBackground: Self = 0.2
}

extension LocalizedStringKey {
    fileprivate static let nextButton: Self = "Next"
}

#Preview("Bottom bar - enabled - light") {
    BottomActionBar(isNextEnabled: true, nextTapped: {})
        .preferredColorScheme(.light)
}

#Preview("Bottom bar - enabled - dark") {
    BottomActionBar(isNextEnabled: true, nextTapped: {})
        .preferredColorScheme(.dark)
}

#Preview("Bottom bar - disabled - light") {
    BottomActionBar(isNextEnabled: false, nextTapped: {})
        .preferredColorScheme(.light)
}

#Preview("Bottom bar - disabled - dark") {
    BottomActionBar(isNextEnabled: false, nextTapped: {})
        .preferredColorScheme(.dark)
}
