import SwiftUI
import SwiftData

@main
struct TimeQuestApp: App {
    let container: ModelContainer

    init() {
        // Try CloudKit-backed container first, fall back to local-only if CloudKit
        // is unavailable (e.g., simulator without iCloud sign-in, no entitlements,
        // or CloudKit container not yet provisioned).
        if let cloudContainer = try? ModelContainer(
            for: TimeQuestSchemaV5.Routine.self,
                 TimeQuestSchemaV5.RoutineTask.self,
                 TimeQuestSchemaV5.GameSession.self,
                 TimeQuestSchemaV5.TaskEstimation.self,
                 TimeQuestSchemaV5.PlayerProfile.self,
                 TimeQuestSchemaV5.TaskDifficultyState.self,
            migrationPlan: TimeQuestMigrationPlan.self,
            configurations: ModelConfiguration(cloudKitDatabase: .automatic)
        ) {
            container = cloudContainer
        } else {
            // Fall back to local-only — migration still runs, just no CloudKit sync
            do {
                container = try ModelContainer(
                    for: TimeQuestSchemaV5.Routine.self,
                         TimeQuestSchemaV5.RoutineTask.self,
                         TimeQuestSchemaV5.GameSession.self,
                         TimeQuestSchemaV5.TaskEstimation.self,
                         TimeQuestSchemaV5.PlayerProfile.self,
                         TimeQuestSchemaV5.TaskDifficultyState.self,
                    migrationPlan: TimeQuestMigrationPlan.self,
                    configurations: ModelConfiguration(cloudKitDatabase: .none)
                )
                print("[TimeQuest] CloudKit unavailable — using local storage only")
            } catch {
                fatalError("Failed to initialize model container: \(error)")
            }
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
