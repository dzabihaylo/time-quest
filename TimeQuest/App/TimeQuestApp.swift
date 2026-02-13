import SwiftUI
import SwiftData

@main
struct TimeQuestApp: App {
    let container: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(
                cloudKitDatabase: .automatic
            )
            container = try ModelContainer(
                for: TimeQuestSchemaV2.Routine.self,
                     TimeQuestSchemaV2.RoutineTask.self,
                     TimeQuestSchemaV2.GameSession.self,
                     TimeQuestSchemaV2.TaskEstimation.self,
                     TimeQuestSchemaV2.PlayerProfile.self,
                migrationPlan: TimeQuestMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
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
