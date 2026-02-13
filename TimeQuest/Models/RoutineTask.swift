import Foundation
import SwiftData

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
