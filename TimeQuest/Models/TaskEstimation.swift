import Foundation
import SwiftData

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

    /// Computed rating from stored raw value. Falls back to .way_off if invalid.
    var rating: AccuracyRating {
        AccuracyRating(rawValue: ratingRawValue) ?? .way_off
    }

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
