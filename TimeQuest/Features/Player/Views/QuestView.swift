import SwiftUI
import SwiftData

struct QuestView: View {
    let routine: Routine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            EstimationInputView(viewModel: vm)

        case .active:
            TaskActiveView(viewModel: vm)

        case .revealing:
            AccuracyRevealView(viewModel: vm)

        case .summary:
            SessionSummaryView(viewModel: vm) {
                vm.finishQuest()
                dismiss()
            }
        }
    }
}
