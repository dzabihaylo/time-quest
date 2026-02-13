import SwiftUI

struct StreakBadgeView: View {
    let streak: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(isActive ? .orange : .gray)

            Text("\(streak) day streak")
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .font(.callout)
        .fontWeight(.medium)
    }
}
