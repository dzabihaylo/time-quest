import SwiftUI

/// Primary call-to-action button ViewModifier.
struct TQPrimaryButtonModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens

    func body(content: Content) -> some View {
        content
            .font(tokens.font(.headline, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tokens.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadiusMD))
    }
}

extension View {
    /// Applies TimeQuest primary button styling -- full-width teal CTA.
    func tqPrimaryButton() -> some View {
        modifier(TQPrimaryButtonModifier())
    }
}
