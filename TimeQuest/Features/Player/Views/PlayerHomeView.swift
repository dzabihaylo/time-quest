import SwiftUI
import SwiftData

struct PlayerHomeView: View {
    @Environment(\.designTokens) private var tokens
    @Environment(RoleState.self) private var roleState
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies

    @State private var todayQuests: [Routine] = []
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")
    @State private var selectedQuest: Routine?
    @State private var progressionVM: ProgressionViewModel?
    @State private var showingCreateQuest = false
    @State private var reflectionVM: WeeklyReflectionViewModel?
    @State private var showReflectionCard = false
    @State private var dayContext: DayContext = .unknown

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
                        .font(tokens.font(.largeTitle, weight: .bold))
                }
                .onTapGesture(count: 3) {
                    roleState.requestParentAccess()
                }

                // Progression header
                if let vm = progressionVM {
                    VStack(spacing: 12) {
                        LevelBadgeView(level: vm.currentLevel)

                        XPBarView(
                            currentXP: vm.totalXP,
                            xpForNextLevel: vm.xpForNextLevel,
                            progress: vm.xpProgress
                        )
                        .padding(.horizontal, 24)

                        StreakBadgeView(
                            streak: vm.currentStreak,
                            isActive: vm.isStreakActive
                        )
                    }
                }

                Spacer()

                // Weekly reflection card (REQ-039)
                if let reflection = reflectionVM?.currentReflection, showReflectionCard {
                    WeeklyReflectionCardView(reflection: reflection) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showReflectionCard = false
                        }
                        reflectionVM?.dismissCurrentReflection()
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Calendar context chip (passive language only -- CAL-05)
                if dayContext != .unknown && dependencies.calendarService.hasAccess {
                    calendarContextChip
                }

                // Quest list
                if todayQuests.isEmpty {
                    emptyState
                } else {
                    questList
                }

                // Navigation links
                if progressionVM != nil {
                    VStack(spacing: 8) {
                        NavigationLink {
                            MyPatternsView()
                        } label: {
                            HStack(spacing: 4) {
                                Text("My Patterns")
                                Image(systemName: "chevron.right")
                            }
                            .font(tokens.font(.caption))
                            .foregroundStyle(.secondary)
                        }

                        NavigationLink {
                            PlayerStatsView(
                                viewModel: ProgressionViewModel(
                                    playerProfileRepository: SwiftDataPlayerProfileRepository(modelContext: modelContext),
                                    sessionRepository: SwiftDataSessionRepository(modelContext: modelContext),
                                    modelContext: modelContext
                                ),
                                reflectionHistory: reflectionVM?.reflectionHistory ?? []
                            )
                        } label: {
                            HStack(spacing: 4) {
                                Text("View Your Stats")
                                Image(systemName: "chevron.right")
                            }
                            .font(tokens.font(.caption))
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDestination(item: $selectedQuest) { routine in
                QuestView(routine: routine)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        NotificationSettingsView(
                            playerProfileRepository: dependencies.playerProfileRepository,
                            notificationManager: dependencies.notificationManager,
                            syncMonitor: dependencies.syncMonitor,
                            routines: todayQuests
                        )
                    } label: {
                        Image(systemName: "gearshape")
                            .font(tokens.font(.body))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            loadTodayQuests()
            loadProgression()
            loadReflection()
        }
        .sheet(isPresented: $showingCreateQuest, onDismiss: { loadTodayQuests() }) {
            PlayerRoutineCreationView(modelContext: modelContext)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onComplete: {
                showOnboarding = false
            })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("No quests today")
                    .font(tokens.font(.title3))
                    .foregroundStyle(.secondary)

                Text("Quests appear on their scheduled days")
                    .font(tokens.font(.subheadline))
                    .foregroundStyle(.tertiary)
            }

            createQuestButton
        }
        .padding(.horizontal, 24)
    }

    private var questList: some View {
        VStack(spacing: 12) {
            ForEach(todayQuests) { routine in
                questCard(routine)
            }

            createQuestButton
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
                            .font(tokens.font(.headline))
                            .foregroundStyle(.primary)

                        if routine.createdBy == "player" {
                            Image(systemName: "star.fill")
                                .font(tokens.font(.caption2))
                                .foregroundStyle(tokens.accentSecondary)
                        }

                        if isCalibrating(routine) {
                            Text("Calibrating")
                                .tqChip(color: tokens.accentSecondary)
                        }
                    }

                    Text("\(routine.orderedTasks.count) steps")
                        .font(tokens.font(.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(tokens.font(.caption))
                    .foregroundStyle(.tertiary)
            }
            .tqCard()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var calendarContextChip: some View {
        switch dayContext {
        case .schoolDay:
            HStack(spacing: 4) {
                Image(systemName: "backpack.fill")
                Text("School day")
            }
            .tqChip(color: tokens.school)
        case .freeDay(let reason):
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill")
                Text(reason ?? "Free day")
                    .lineLimit(1)
            }
            .tqChip(color: tokens.accentSecondary)
        case .unknown:
            EmptyView()
        }
    }

    private var createQuestButton: some View {
        Button { showingCreateQuest = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(tokens.font(.title3))
                    .foregroundStyle(.tint)
                Text("Create Quest")
                    .font(tokens.font(.headline))
                    .foregroundStyle(.tint)
                Spacer()
            }
            .tqCard()
        }
        .buttonStyle(.plain)
    }

    private func loadTodayQuests() {
        let repo = SwiftDataRoutineRepository(modelContext: modelContext)
        let allToday = repo.fetchActiveForToday()

        if dependencies.calendarService.hasAccess {
            let calendarIDs = dependencies.calendarService.selectedCalendarIDs()
            let events = dependencies.calendarService.fetchTodayEvents(from: calendarIDs)
            let engine = CalendarContextEngine()
            let context = engine.determineContext(events: events, date: .now)
            dayContext = context
            todayQuests = allToday.filter { engine.shouldShow(calendarMode: $0.calendarModeRaw, in: context) }
        } else {
            dayContext = .unknown
            todayQuests = allToday
        }
    }

    private func loadProgression() {
        let vm = ProgressionViewModel(
            playerProfileRepository: SwiftDataPlayerProfileRepository(modelContext: modelContext),
            sessionRepository: SwiftDataSessionRepository(modelContext: modelContext),
            modelContext: modelContext
        )
        vm.refresh()
        progressionVM = vm
    }

    private func loadReflection() {
        let vm = WeeklyReflectionViewModel(modelContext: modelContext)
        vm.refresh()
        reflectionVM = vm
        showReflectionCard = vm.shouldShowCard
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
