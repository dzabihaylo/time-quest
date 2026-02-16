import SwiftUI

struct LevelBadgeView: View {
    @Environment(\.designTokens) private var tokens

    let level: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.checkmark")
                .foregroundStyle(tokens.accent)

            if level == 0 {
                Text("Time Sense -- New")
            } else {
                Text("Time Sense Lv. \(level)")
            }
        }
        .font(tokens.font(.headline))
    }
}
