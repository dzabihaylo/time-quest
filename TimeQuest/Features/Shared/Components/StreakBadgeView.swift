import SwiftUI

struct StreakBadgeView: View {
    @Environment(\.designTokens) private var tokens

    let streak: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(isActive ? tokens.accentSecondary : tokens.textTertiary)

            Text("\(streak) day streak")
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .font(tokens.font(.callout, weight: .medium))
    }
}
