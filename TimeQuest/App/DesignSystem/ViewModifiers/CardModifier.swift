import SwiftUI

/// Roblox-inspired card modifier: dark raised panels with subtle bright border
/// and bottom shadow for depth. Game-UI feel without being toy-like.
struct TQCardModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens

    var elevation: CardElevation = .standard

    enum CardElevation {
        case standard
        case nested
    }

    func body(content: Content) -> some View {
        content
            .padding(tokens.spacingLG)
            .background(
                ZStack {
                    // Main fill
                    RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                        .fill(elevation == .standard ? tokens.surfaceSecondary : tokens.surfaceTertiary)

                    // Top highlight edge — subtle light gradient at top for raised feel
                    RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                    .strokeBorder(tokens.cardBorderColor, lineWidth: tokens.cardBorderWidth)
            )
            .shadow(color: .black.opacity(0.5), radius: 1, y: 2)
    }
}

extension View {
    func tqCard(elevation: TQCardModifier.CardElevation = .standard) -> some View {
        modifier(TQCardModifier(elevation: elevation))
    }
}
