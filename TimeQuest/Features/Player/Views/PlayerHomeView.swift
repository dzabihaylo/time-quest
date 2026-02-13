import SwiftUI
import SwiftData

struct PlayerHomeView: View {
    @Environment(RoleState.self) private var roleState
    @Environment(\.modelContext) private var modelContext

    @State private var todayQuests: [Routine] = []
    @State private var showOnboarding = false
    @State private var selectedQuest: Routine?

    private var onboardingComplete: Bool {
        UserDefaults.standard.bool(forKey: "onboardingComplete")
    }

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

                // Quest list
                if todayQuests.isEmpty {
                    emptyState
                } else {
                    questList
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(item: $selectedQuest) { routine in
                QuestView(routine: routine)
            }
        }
        .onAppear {
            loadTodayQuests()
            if !onboardingComplete {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onComplete: {
                showOnboarding = false
            })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No quests today")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Quests appear on their scheduled days")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private var questList: some View {
        VStack(spacing: 12) {
            ForEach(todayQuests) { routine in
                questCard(routine)
            }
        }
        .padding(.horizontal, 24)
    }

    private func questCard(_ routine: Routine) -> some View {
        Button {
            selectedQuest = routine
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(routine.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if isCalibrating(routine) {
                            Text("Calibrating")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(routine.orderedTasks.count) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func loadTodayQuests() {
        let repo = SwiftDataRoutineRepository(modelContext: modelContext)
        todayQuests = repo.fetchActiveForToday()
    }

    private func isCalibrating(_ routine: Routine) -> Bool {
        let repo = SwiftDataSessionRepository(modelContext: modelContext)
        let completedCount = repo.fetchSessions(for: routine)
            .filter { $0.completedAt != nil }
            .count
        return CalibrationTracker.isCalibrationSession(completedSessionCount: completedCount)
    }
}

// Make Routine conform to Hashable for navigation
extension Routine: Hashable {
    public static func == (lhs: Routine, rhs: Routine) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(persistentModelID)
    }
}
