import SwiftUI

/// Card-style ViewModifier that applies consistent background, corner radius,
/// and elevation treatment (shadow in light mode, border in dark mode).
struct TQCardModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens
    @Environment(\.colorScheme) private var colorScheme

    var elevation: CardElevation = .standard

    enum CardElevation {
        /// surfaceSecondary background -- top-level cards
        case standard
        /// surfaceTertiary background -- card inside card
        case nested
    }

    func body(content: Content) -> some View {
        content
            .padding(tokens.spacingLG)
            .background(
                elevation == .standard ? tokens.surfaceSecondary : tokens.surfaceTertiary
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .clear : tokens.shadowColor,
                radius: tokens.shadowRadius,
                y: tokens.shadowY
            )
    }
}

extension View {
    /// Applies TimeQuest card styling with dark-mode-aware borders and light-mode shadows.
    func tqCard(elevation: TQCardModifier.CardElevation = .standard) -> some View {
        modifier(TQCardModifier(elevation: elevation))
    }
}
