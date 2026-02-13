import Foundation

/// Value type that bridges SwiftData's TaskEstimation to the pure domain layer.
/// No SwiftData dependency in this struct definition -- only Foundation.
struct EstimationSnapshot: Sendable {
    let taskDisplayName: String
    let estimatedSeconds: Double
    let actualSeconds: Double
    let differenceSeconds: Double    // Signed: positive = overestimate
    let accuracyPercent: Double      // 0-100, 100 = perfect
    let recordedAt: Date
    let routineName: String
    let isCalibration: Bool
}

// MARK: - SwiftData Bridge

import SwiftData

extension EstimationSnapshot {
    /// Map from the SwiftData model to a plain value type for domain logic.
    init(from estimation: TaskEstimation) {
        self.taskDisplayName = estimation.taskDisplayName
        self.estimatedSeconds = estimation.estimatedSeconds
        self.actualSeconds = estimation.actualSeconds
        self.differenceSeconds = estimation.differenceSeconds
        self.accuracyPercent = estimation.accuracyPercent
        self.recordedAt = estimation.recordedAt
        self.routineName = estimation.session?.routine?.displayName ?? "Unknown"
        self.isCalibration = estimation.session?.isCalibration ?? false
    }
}
