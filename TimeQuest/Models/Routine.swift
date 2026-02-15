import Foundation
import SwiftData

typealias Routine = TimeQuestSchemaV4.Routine

extension Routine {
    /// Always use this for ordered access -- SwiftData does NOT preserve array order.
    var orderedTasks: [RoutineTask] {
        tasks.sorted { $0.orderIndex < $1.orderIndex }
    }
}
