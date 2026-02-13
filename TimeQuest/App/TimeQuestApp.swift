import SwiftUI
import SwiftData

@main
struct TimeQuestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Routine.self,
            RoutineTask.self,
            GameSession.self,
            TaskEstimation.self,
            PlayerProfile.self
        ])
    }
}

/// Intermediate view that has access to modelContext for creating AppDependencies.
private struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dependencies: AppDependencies?

    var body: some View {
        Group {
            if let dependencies {
                RoleRouter()
                    .environment(dependencies)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if dependencies == nil {
                dependencies = AppDependencies(modelContext: modelContext)
            }
        }
    }
}
