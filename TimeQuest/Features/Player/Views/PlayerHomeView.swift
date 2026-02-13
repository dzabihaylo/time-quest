import SwiftUI

struct PlayerHomeView: View {
    @Environment(RoleState.self) private var roleState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // App logo area -- triple-tap triggers hidden access
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    Text("TimeQuest")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .onTapGesture(count: 3) {
                    roleState.requestParentAccess()
                }

                Spacer()

                Text("No quests available")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Check back later for new quests!")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
