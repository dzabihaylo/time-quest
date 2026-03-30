import SwiftUI

/// Roblox-style primary button: bold gradient fill with a 3D raised bottom edge.
/// The bottom shadow gives the chunky, tactile "press me" feel that game UIs have.
struct TQPrimaryButtonModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens

    func body(content: Content) -> some View {
        content
            .font(.system(.headline, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                ZStack {
                    // Bottom edge (3D shadow layer)
                    RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                        .fill(Color(red: 0.0, green: 0.45, blue: 0.2))
                        .offset(y: tokens.buttonShadowHeight)

                    // Main button surface
                    RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                        .fill(tokens.accentGradient)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadiusMD))
    }
}

/// Secondary / outline button style for less prominent actions.
struct TQSecondaryButtonModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens

    func body(content: Content) -> some View {
        content
            .font(.system(.subheadline, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(tokens.accent)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                    .strokeBorder(tokens.accent.opacity(0.4), lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                    .fill(tokens.accent.opacity(0.08))
            )
    }
}

/// Gold CTA button for special actions (level-ups, achievements).
struct TQGoldButtonModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens

    func body(content: Content) -> some View {
        content
            .font(.system(.headline, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.black)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                        .fill(Color(red: 0.8, green: 0.5, blue: 0.0))
                        .offset(y: tokens.buttonShadowHeight)

                    RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                        .fill(tokens.goldGradient)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadiusMD))
    }
}

extension View {
    func tqPrimaryButton() -> some View {
        modifier(TQPrimaryButtonModifier())
    }

    func tqSecondaryButton() -> some View {
        modifier(TQSecondaryButtonModifier())
    }

    func tqGoldButton() -> some View {
        modifier(TQGoldButtonModifier())
    }
}
