import SwiftUI

struct XPBarView: View {
    @Environment(\.designTokens) private var tokens

    let currentXP: Int
    let xpForNextLevel: Int
    let progress: Double

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tokens.surfaceTertiary)
                        .frame(height: 8)

                    Capsule()
                        .fill(tokens.accent)
                        .frame(width: max(0, geometry.size.width * progress), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)

            Text("XP: \(currentXP)/\(xpForNextLevel)")
                .font(tokens.font(.caption2))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
