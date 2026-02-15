import Foundation

/// Value type that bridges SwiftData's TaskDifficultyState to the pure domain layer.
/// No SwiftData dependency in this struct definition -- only Foundation.
struct DifficultySnapshot: Sendable {
    let taskDisplayName: String
    let difficultyLevel: Int
    let ema: Double
    let sessionsAtCurrentLevel: Int
    let lastUpdated: Date
}

// MARK: - SwiftData Bridge

import SwiftData

extension DifficultySnapshot {
    /// Map from the SwiftData model to a plain value type for domain logic.
    init(from state: TaskDifficultyState) {
        self.taskDisplayName = state.taskDisplayName
        self.difficultyLevel = state.difficultyLevel
        self.ema = state.ema
        self.sessionsAtCurrentLevel = state.sessionsAtCurrentLevel
        self.lastUpdated = state.lastUpdated
    }
}
