import SwiftUI

/// Capsule badge/tag ViewModifier for status chips and labels.
struct TQChipModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens

    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(.caption, design: .rounded, weight: .medium))
            .padding(.horizontal, tokens.spacingMD)
            .padding(.vertical, tokens.spacingSM - 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

extension View {
    /// Applies TimeQuest capsule chip styling with the given accent color.
    func tqChip(color: Color) -> some View {
        modifier(TQChipModifier(color: color))
    }
}
