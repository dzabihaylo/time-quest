import Foundation
import SwiftData

@Model
final class Routine {
    var name: String
    var displayName: String
    var activeDays: [Int]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RoutineTask.routine)
    var tasks: [RoutineTask] = []

    @Relationship(deleteRule: .cascade, inverse: \GameSession.routine)
    var sessions: [GameSession] = []

    /// Always use this for ordered access -- SwiftData does NOT preserve array order.
    var orderedTasks: [RoutineTask] {
        tasks.sorted { $0.orderIndex < $1.orderIndex }
    }

    init(
        name: String,
        displayName: String,
        activeDays: [Int] = [],
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.name = name
        self.displayName = displayName
        self.activeDays = activeDays
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
