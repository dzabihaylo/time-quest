import Foundation
import SwiftData

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
