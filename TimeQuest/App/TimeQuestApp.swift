import SwiftUI
import SwiftData

@main
struct TimeQuestApp: App {
    var body: some Scene {
        WindowGroup {
            RoleRouter()
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
