import Foundation
import SwiftData

@MainActor
@Observable
final class AppDependencies {
    let routineRepository: RoutineRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol

    init(modelContext: ModelContext) {
        self.routineRepository = SwiftDataRoutineRepository(modelContext: modelContext)
        self.sessionRepository = SwiftDataSessionRepository(modelContext: modelContext)
    }
}
