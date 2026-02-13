import Foundation
import SwiftData

@MainActor
protocol SessionRepositoryProtocol {
    func createSession(for routine: Routine, isCalibration: Bool) -> GameSession
    func fetchSessions(for routine: Routine) -> [GameSession]
    func fetchAllSessions() -> [GameSession]
    func save() throws
}

@MainActor
final class SwiftDataSessionRepository: SessionRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createSession(for routine: Routine, isCalibration: Bool) -> GameSession {
        let session = GameSession(isCalibration: isCalibration)
        modelContext.insert(session)
        session.routine = routine
        return session
    }

    func fetchSessions(for routine: Routine) -> [GameSession] {
        let routineCloudID = routine.cloudID
        let descriptor = FetchDescriptor<GameSession>(
            predicate: #Predicate { $0.routine?.cloudID == routineCloudID },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchAllSessions() -> [GameSession] {
        let descriptor = FetchDescriptor<GameSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func save() throws {
        try modelContext.save()
    }
}
