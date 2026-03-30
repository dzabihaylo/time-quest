import SwiftUI

/// Roblox-style chip/badge: bright color with slight fill, bold rounded text.
struct TQChipModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens

    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(.caption, weight: .bold, design: .rounded))
            .padding(.horizontal, tokens.spacingMD)
            .padding(.vertical, tokens.spacingSM - 1)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func tqChip(color: Color) -> some View {
        modifier(TQChipModifier(color: color))
    }
}
