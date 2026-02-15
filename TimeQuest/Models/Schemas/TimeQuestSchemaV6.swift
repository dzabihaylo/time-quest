import Foundation
@preconcurrency import SwiftData

enum TimeQuestSchemaV6: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Routine.self, RoutineTask.self, GameSession.self,
         TaskEstimation.self, PlayerProfile.self, TaskDifficultyState.self]
    }

    @Model
    final class Routine {
        var cloudID: String = UUID().uuidString
        var name: String = ""
        var displayName: String = ""
        var activeDays: [Int] = []
        var isActive: Bool = true
        var createdBy: String = "parent"
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var calendarModeRaw: String = "always"
        var spotifyPlaylistID: String? = nil
        var spotifyPlaylistName: String? = nil

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV6.RoutineTask.routine)
        var tasks: [RoutineTask] = []

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV6.GameSession.routine)
        var sessions: [GameSession] = []

        init(
            name: String = "",
            displayName: String = "",
            activeDays: [Int] = [],
            isActive: Bool = true,
            createdBy: String = "parent",
            createdAt: Date = .now,
            updatedAt: Date = .now,
            calendarModeRaw: String = "always",
            spotifyPlaylistID: String? = nil,
            spotifyPlaylistName: String? = nil
        ) {
            self.cloudID = UUID().uuidString
            self.name = name
            self.displayName = displayName
            self.activeDays = activeDays
            self.isActive = isActive
            self.createdBy = createdBy
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.calendarModeRaw = calendarModeRaw
            self.spotifyPlaylistID = spotifyPlaylistID
            self.spotifyPlaylistName = spotifyPlaylistName
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
        var difficultyLevel: Int = 1
        var xpMultiplier: Double = 1.0
        var spotifySongCount: String? = nil

        @Relationship(deleteRule: .cascade, inverse: \TimeQuestSchemaV6.TaskEstimation.session)
        var estimations: [TaskEstimation] = []

        init(
            startedAt: Date = .now,
            completedAt: Date? = nil,
            isCalibration: Bool = false,
            xpEarned: Int = 0,
            difficultyLevel: Int = 1,
            xpMultiplier: Double = 1.0,
            spotifySongCount: String? = nil
        ) {
            self.cloudID = UUID().uuidString
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.isCalibration = isCalibration
            self.xpEarned = xpEarned
            self.difficultyLevel = difficultyLevel
            self.xpMultiplier = xpMultiplier
            self.spotifySongCount = spotifySongCount
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

    @Model
    final class TaskDifficultyState {
        var cloudID: String = UUID().uuidString
        var taskDisplayName: String = ""
        var difficultyLevel: Int = 1
        var ema: Double = 0.0
        var sessionsAtCurrentLevel: Int = 0
        var lastUpdated: Date = Date.now

        init(
            taskDisplayName: String = "",
            difficultyLevel: Int = 1,
            ema: Double = 0.0,
            sessionsAtCurrentLevel: Int = 0,
            lastUpdated: Date = .now
        ) {
            self.cloudID = UUID().uuidString
            self.taskDisplayName = taskDisplayName
            self.difficultyLevel = difficultyLevel
            self.ema = ema
            self.sessionsAtCurrentLevel = sessionsAtCurrentLevel
            self.lastUpdated = lastUpdated
        }
    }
}
