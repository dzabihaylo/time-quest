import SwiftUI

struct XPBarView: View {
    @Environment(\.designTokens) private var tokens

    let currentXP: Int
    let xpForNextLevel: Int
    let progress: Double

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(tokens.surfaceTertiary)
                        .frame(height: 12)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        )

                    // Fill — gradient bar with glow
                    Capsule()
                        .fill(tokens.accentGradient)
                        .frame(width: max(0, geometry.size.width * progress), height: 12)
                        .shadow(color: tokens.accent.opacity(0.5), radius: 4, y: 0)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(currentXP) XP")
                    .font(.system(.caption, weight: .bold, design: .rounded))
                    .foregroundStyle(tokens.accent)

                Spacer()

                Text("\(xpForNextLevel) to level up")
                    .font(.system(.caption2, weight: .medium, design: .rounded))
                    .foregroundStyle(tokens.textTertiary)
            }
        }
    }
}
