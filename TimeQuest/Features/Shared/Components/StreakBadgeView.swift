import SwiftUI

struct StreakBadgeView: View {
    @Environment(\.designTokens) private var tokens

    let streak: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(.body, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? tokens.caution : tokens.textTertiary)

            Text("\(streak)")
                .font(.system(.title3, weight: .black, design: .rounded))
                .foregroundStyle(isActive ? tokens.textPrimary : tokens.textTertiary)

            Text("day streak")
                .font(.system(.caption, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? tokens.textSecondary : tokens.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isActive ? tokens.caution.opacity(0.12) : tokens.surfaceTertiary)
        )
        .overlay(
            Capsule()
                .strokeBorder(isActive ? tokens.caution.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
