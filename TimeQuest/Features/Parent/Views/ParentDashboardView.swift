import SwiftUI
import SwiftData

struct ParentDashboardView: View {
    @Environment(RoleState.self) private var roleState
    @Environment(\.modelContext) private var modelContext

    @State private var showingNewRoutine = false

    var body: some View {
        NavigationStack {
            RoutineListView()
                .navigationTitle("Setup")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            roleState.exitParentMode()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingNewRoutine = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .navigationDestination(for: PersistentIdentifier.self) { routineID in
                    if let routine = fetchRoutine(id: routineID) {
                        RoutineEditorView(
                            routine: routine,
                            repository: SwiftDataRoutineRepository(modelContext: modelContext),
                            modelContext: modelContext
                        )
                    }
                }
                .sheet(isPresented: $showingNewRoutine) {
                    NavigationStack {
                        RoutineEditorView(
                            routine: nil,
                            repository: SwiftDataRoutineRepository(modelContext: modelContext),
                            modelContext: modelContext
                        )
                    }
                }
        }
    }

    private func fetchRoutine(id: PersistentIdentifier) -> Routine? {
        try? modelContext.fetch(
            FetchDescriptor<Routine>(predicate: #Predicate { $0.persistentModelID == id })
        ).first
    }
}
