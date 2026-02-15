import Foundation
import SwiftData

typealias GameSession = TimeQuestSchemaV4.GameSession

extension GameSession {
    /// Always use this for ordered access -- SwiftData does NOT preserve array order.
    var orderedEstimations: [TaskEstimation] {
        estimations.sorted { $0.orderIndex < $1.orderIndex }
    }
}
