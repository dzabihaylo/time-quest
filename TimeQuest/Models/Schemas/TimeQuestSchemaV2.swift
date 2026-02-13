import Foundation
@preconcurrency import SwiftData

enum TimeQuestSchemaV2: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Routine.self, RoutineTask.self, GameSession.self,
         TaskEstimation.self, PlayerProfile.self]
    }

    @Model
    final class Routine {
        var cloudID: String = UUID().uuidString
        var name: String = ""
        var displayName: String = ""
        var activeDays: [Int] = []
        var isActive: Bool = true
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV2.RoutineTask.routine)
        var tasks: [RoutineTask] = []

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV2.GameSession.routine)
        var sessions: [GameSession] = []

        init(
            name: String = "",
            displayName: String = "",
            activeDays: [Int] = [],
            isActive: Bool = true,
            createdAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.cloudID = UUID().uuidString
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
        var cloudID: String = UUID().uuidString
        var name: String = ""
        var displayName: String = ""
        var referenceDurationSeconds: Int?
        var orderIndex: Int = 0
        var routine: Routine?

        init(
            name: String = "",
            displayName: String = "",
            referenceDurationSeconds: Int? = nil,
            orderIndex: Int = 0
        ) {
            self.cloudID = UUID().uuidString
            self.name = name
            self.displayName = displayName
            self.referenceDurationSeconds = referenceDurationSeconds
            self.orderIndex = orderIndex
        }
    }

    @Model
    final class GameSession {
        var cloudID: String = UUID().uuidString
        var routine: Routine?
        var startedAt: Date = Date.now
        var completedAt: Date?
        var isCalibration: Bool = false
        var xpEarned: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV2.TaskEstimation.session)
        var estimations: [TaskEstimation] = []

        init(
            startedAt: Date = .now,
            completedAt: Date? = nil,
            isCalibration: Bool = false,
            xpEarned: Int = 0
        ) {
            self.cloudID = UUID().uuidString
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.isCalibration = isCalibration
            self.xpEarned = xpEarned
        }
    }

    @Model
    final class TaskEstimation {
        var cloudID: String = UUID().uuidString
        var taskDisplayName: String = ""
        var estimatedSeconds: Double = 0
        var actualSeconds: Double = 0
        var differenceSeconds: Double = 0
        var accuracyPercent: Double = 0
        var ratingRawValue: String = "way_off"
        var orderIndex: Int = 0
        var recordedAt: Date = Date.now
        var session: GameSession?

        init(
            taskDisplayName: String = "",
            estimatedSeconds: Double = 0,
            actualSeconds: Double = 0,
            differenceSeconds: Double = 0,
            accuracyPercent: Double = 0,
            ratingRawValue: String = "way_off",
            orderIndex: Int = 0,
            recordedAt: Date = .now
        ) {
            self.cloudID = UUID().uuidString
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
        var cloudID: String = UUID().uuidString
        var totalXP: Int = 0
        var currentStreak: Int = 0
        var lastPlayedDate: Date?
        var notificationsEnabled: Bool = true
        var notificationHour: Int = 7
        var notificationMinute: Int = 30
        var soundEnabled: Bool = true
        var createdAt: Date = Date.now

        init() {
            self.cloudID = UUID().uuidString
        }
    }
}
