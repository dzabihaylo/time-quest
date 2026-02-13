import SwiftUI

struct LevelBadgeView: View {
    let level: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.checkmark")
                .foregroundStyle(.teal)

            if level == 0 {
                Text("Time Sense -- New")
            } else {
                Text("Time Sense Lv. \(level)")
            }
        }
        .font(.headline)
    }
}
