import Foundation
import SwiftData

@Model
final class GameSession {
    var routine: Routine?
    var startedAt: Date
    var completedAt: Date?
    var isCalibration: Bool
    var xpEarned: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \TaskEstimation.session)
    var estimations: [TaskEstimation] = []

    /// Always use this for ordered access -- SwiftData does NOT preserve array order.
    var orderedEstimations: [TaskEstimation] {
        estimations.sorted { $0.orderIndex < $1.orderIndex }
    }

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
