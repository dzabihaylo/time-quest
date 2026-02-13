import Foundation
@preconcurrency import SwiftData

enum TimeQuestSchemaV1: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Routine.self, RoutineTask.self, GameSession.self,
         TaskEstimation.self, PlayerProfile.self]
    }

    @Model
    final class Routine {
        var name: String
        var displayName: String
        var activeDays: [Int]
        var isActive: Bool
        var createdAt: Date
        var updatedAt: Date

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV1.RoutineTask.routine)
        var tasks: [RoutineTask] = []

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV1.GameSession.routine)
        var sessions: [GameSession] = []

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

    @Model
    final class RoutineTask {
        var name: String
        var displayName: String
        var referenceDurationSeconds: Int?
        var orderIndex: Int
        var routine: Routine?

        init(
            name: String,
            displayName: String,
            referenceDurationSeconds: Int? = nil,
            orderIndex: Int = 0
        ) {
            self.name = name
            self.displayName = displayName
            self.referenceDurationSeconds = referenceDurationSeconds
            self.orderIndex = orderIndex
        }
    }

    @Model
    final class GameSession {
        var routine: Routine?
        var startedAt: Date
        var completedAt: Date?
        var isCalibration: Bool
        var xpEarned: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV1.TaskEstimation.session)
        var estimations: [TaskEstimation] = []

        init(
            startedAt: Date = .now,
            completedAt: Date? = nil,
            isCalibration: Bool = false,
            xpEarned: Int = 0
        ) {
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.isCalibration = isCalibration
            self.xpEarned = xpEarned
        }
    }

    @Model
    final class TaskEstimation {
        var taskDisplayName: String
        var estimatedSeconds: Double
        var actualSeconds: Double
        var differenceSeconds: Double
        var accuracyPercent: Double
        var ratingRawValue: String
        var orderIndex: Int
        var recordedAt: Date
        var session: GameSession?

        init(
            taskDisplayName: String,
            estimatedSeconds: Double,
            actualSeconds: Double,
            differenceSeconds: Double,
            accuracyPercent: Double,
            ratingRawValue: String,
            orderIndex: Int = 0,
            recordedAt: Date = .now
        ) {
            self.taskDisplayName = taskDisplayName
            self.estimatedSeconds = estimatedSeconds
            self.actualSeconds = actualSeconds
            self.differenceSeconds = differenceSeconds
            self.accuracyPercent = accuracyPercent
            self.ratingRawValue = ratingRawValue
            self.orderIndex = orderIndex
            self.recordedAt = recordedAt
        }
    }

    @Model
    final class PlayerProfile {
        var totalXP: Int = 0
        var currentStreak: Int = 0
        var lastPlayedDate: Date?
        var notificationsEnabled: Bool = true
        var notificationHour: Int = 7
        var notificationMinute: Int = 30
        var soundEnabled: Bool = true
        var createdAt: Date = Date.now

        init() {}
    }
}
