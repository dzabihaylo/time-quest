import SwiftUI

struct LevelBadgeView: View {
    @Environment(\.designTokens) private var tokens

    let level: Int

    var body: some View {
        HStack(spacing: 8) {
            // Level icon with gold gradient background
            ZStack {
                Circle()
                    .fill(tokens.goldGradient)
                    .frame(width: 32, height: 32)
                    .shadow(color: tokens.accentSecondary.opacity(0.4), radius: 4, y: 0)

                Text("\(max(level, 1))")
                    .font(.system(.callout, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("TIME SENSE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(tokens.textTertiary)
                    .tracking(1.5)

                if level == 0 {
                    Text("New Player")
                        .font(.system(.subheadline, weight: .bold, design: .rounded))
                        .foregroundStyle(tokens.textPrimary)
                } else {
                    Text("Level \(level)")
                        .font(.system(.subheadline, weight: .bold, design: .rounded))
                        .foregroundStyle(tokens.textPrimary)
                }
            }
        }
    }
}
