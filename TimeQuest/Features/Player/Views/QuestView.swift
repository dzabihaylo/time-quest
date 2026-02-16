import SwiftUI
import SwiftData

struct QuestView: View {
    let routine: Routine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies

    @Environment(\.designTokens) private var tokens
    @State private var viewModel: GameSessionViewModel?
    @State private var showAbandonConfirm = false

    var body: some View {
        Group {
            if let viewModel {
                questContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(routine.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showAbandonConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(tokens.font(.caption))
                        .foregroundStyle(tokens.textSecondary)
                }
            }
        }
        .confirmationDialog("Leave this quest?", isPresented: $showAbandonConfirm) {
            Button("Leave Quest", role: .destructive) {
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Your progress on this quest won't be saved.")
        }
        .onAppear {
            if viewModel == nil {
                let repo = SwiftDataSessionRepository(modelContext: modelContext)
                let routineRepo = SwiftDataRoutineRepository(modelContext: modelContext)
                let profileRepo = SwiftDataPlayerProfileRepository(modelContext: modelContext)
                let vm = GameSessionViewModel(
                    routine: routine,
                    sessionRepository: repo,
                    routineRepository: routineRepo,
                    playerProfileRepository: profileRepo,
                    modelContext: modelContext
                )
                // Configure Spotify before startQuest so it can launch playlist
                vm.configureSpotify(
                    authManager: dependencies.spotifyAuthManager,
                    apiClient: dependencies.spotifyAPIClient
                )
                vm.startQuest()
                viewModel = vm
            }
        }
    }

    @ViewBuilder
    private func questContent(_ vm: GameSessionViewModel) -> some View {
        switch vm.phase {
        case .selecting:
            EmptyView()

        case .estimating:
            EstimationInputView(viewModel: vm, soundManager: dependencies.soundManager)

        case .active:
            ZStack(alignment: .bottom) {
                TaskActiveView(viewModel: vm)

                if let nowPlaying = vm.nowPlayingInfo {
                    NowPlayingIndicator(info: nowPlaying)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.nowPlayingInfo != nil)

        case .revealing:
            AccuracyRevealView(viewModel: vm, soundManager: dependencies.soundManager)

        case .summary:
            SessionSummaryView(viewModel: vm, soundManager: dependencies.soundManager) {
                vm.finishQuest()
                dismiss()
            }
        }
    }
}
