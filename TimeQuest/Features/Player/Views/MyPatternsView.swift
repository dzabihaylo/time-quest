import SwiftUI
import SwiftData

struct MyPatternsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: MyPatternsViewModel?

    var body: some View {
        Group {
            if let viewModel, viewModel.isLoaded, !viewModel.insightsByRoutine.isEmpty {
                insightsList(viewModel)
            } else {
                emptyState
            }
        }
        .navigationTitle("My Patterns")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            let vm = MyPatternsViewModel(modelContext: modelContext)
            vm.refresh()
            viewModel = vm
        }
    }

    private func insightsList(_ vm: MyPatternsViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(Array(vm.insightsByRoutine.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.routineName)
                            .font(.title3.bold())
                            .padding(.leading, 4)

                        ForEach(Array(group.insights.enumerated()), id: \.offset) { _, insight in
                            InsightCardView(insight: insight)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Patterns appear after 5 sessions per task")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Keep playing -- every quest teaches your time sense something new")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
