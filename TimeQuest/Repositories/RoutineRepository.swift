import Foundation
import SwiftData

@MainActor
protocol RoutineRepositoryProtocol {
    func fetchAll() -> [Routine]
    func fetchActiveForToday() -> [Routine]
    func fetchParentRoutines() -> [Routine]
    func fetchPlayerRoutines() -> [Routine]
    func save(_ routine: Routine) throws
    func delete(_ routine: Routine) throws
}

@MainActor
final class SwiftDataRoutineRepository: RoutineRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() -> [Routine] {
        let descriptor = FetchDescriptor<Routine>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchActiveForToday() -> [Routine] {
        // SwiftData predicates cannot filter on Codable array contents,
        // so we fetch all active routines and filter in Swift.
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let allActive = (try? modelContext.fetch(descriptor)) ?? []
        let todayWeekday = Calendar.current.component(.weekday, from: Date.now)
        return allActive.filter { $0.activeDays.contains(todayWeekday) }
    }

    func fetchParentRoutines() -> [Routine] {
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.createdBy == "parent" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchPlayerRoutines() -> [Routine] {
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.createdBy == "player" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func save(_ routine: Routine) throws {
        modelContext.insert(routine)
        try modelContext.save()
    }

    func delete(_ routine: Routine) throws {
        modelContext.delete(routine)
        try modelContext.save()
    }
}
