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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let isNextEnabled: Bool
    let nextTapped: () -> Void

    var body: some View {
        Button(action: nextTapped) {
            Text(.nextButton)
                .font(.nextLabel)
                .fontWeight(.nextLabel)
                .foregroundStyle(Color.nextForeground(isEnabled: isNextEnabled))
                .frame(maxWidth: isRegularWidth ? nil : .infinity)
                .frame(width: isRegularWidth ? .nextRegularWidth : nil)
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
        // Wide screens keep Next one grid column wide at the trailing edge instead of stretching it across the
        // whole window (spec 007 FR-015).
        .frame(maxWidth: .infinity, alignment: isRegularWidth ? .trailing : .center)
        .background(Color.barBackground)
        .overlay(alignment: .top) { Divider() }
    }

    /// Anything but compact, matching `StartPageView`'s grid branch.
    private var isRegularWidth: Bool { horizontalSizeClass != .compact }
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
    /// One regular-width grid column (`StartPageView`'s minimum column width).
    fileprivate static let nextRegularWidth: Self = 320
    fileprivate static let previewWideWidth: Self = 1180
    fileprivate static let previewWideHeight: Self = 120
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

#Preview("Bottom bar - regular width - light", traits: .fixedLayout(width: .previewWideWidth, height: .previewWideHeight)) {
    BottomActionBar(isNextEnabled: true, nextTapped: {})
        .environment(\.horizontalSizeClass, .regular)
        .preferredColorScheme(.light)
}

#Preview("Bottom bar - regular width - dark", traits: .fixedLayout(width: .previewWideWidth, height: .previewWideHeight)) {
    BottomActionBar(isNextEnabled: true, nextTapped: {})
        .environment(\.horizontalSizeClass, .regular)
        .preferredColorScheme(.dark)
}
