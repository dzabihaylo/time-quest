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
            for: TimeQuestSchemaV6.Routine.self,
                 TimeQuestSchemaV6.RoutineTask.self,
                 TimeQuestSchemaV6.GameSession.self,
                 TimeQuestSchemaV6.TaskEstimation.self,
                 TimeQuestSchemaV6.PlayerProfile.self,
                 TimeQuestSchemaV6.TaskDifficultyState.self,
            migrationPlan: TimeQuestMigrationPlan.self,
            configurations: ModelConfiguration(cloudKitDatabase: .automatic)
        ) {
            container = cloudContainer
        } else {
            // Fall back to local-only — migration still runs, just no CloudKit sync
            do {
                container = try ModelContainer(
                    for: TimeQuestSchemaV6.Routine.self,
                         TimeQuestSchemaV6.RoutineTask.self,
                         TimeQuestSchemaV6.GameSession.self,
                         TimeQuestSchemaV6.TaskEstimation.self,
                         TimeQuestSchemaV6.PlayerProfile.self,
                         TimeQuestSchemaV6.TaskDifficultyState.self,
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
        .preferredColorScheme(.dark)
        .environment(\.designTokens, DesignTokens())
        .onAppear {
            if dependencies == nil {
                dependencies = AppDependencies(modelContext: modelContext)
            }
        }
    }
}
