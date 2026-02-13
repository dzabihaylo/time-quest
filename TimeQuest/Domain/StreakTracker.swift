import Foundation

struct StreakTracker {
    struct StreakState {
        let currentStreak: Int
        let lastPlayedDate: Date?
        let isActive: Bool
    }

    /// Calculate updated streak based on current streak, last played date, and today's date.
    ///
    /// Rules:
    /// - First-ever session (lastPlayedDate nil): returns streak of 1
    /// - Same day: unchanged
    /// - Next consecutive day: increment by 1
    /// - 2+ day gap: PAUSE at current value (never reset, never punish)
    static func updatedStreak(
        currentStreak: Int,
        lastPlayedDate: Date?,
        today: Date = .now
    ) -> StreakState {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)

        guard let lastPlayed = lastPlayedDate else {
            // First-ever session
            return StreakState(currentStreak: 1, lastPlayedDate: todayStart, isActive: true)
        }

        let lastPlayedStart = calendar.startOfDay(for: lastPlayed)

        if todayStart == lastPlayedStart {
            // Same day -- unchanged
            return StreakState(currentStreak: currentStreak, lastPlayedDate: lastPlayedStart, isActive: true)
        }

        let daysBetween = calendar.dateComponents([.day], from: lastPlayedStart, to: todayStart).day ?? 0

        if daysBetween == 1 {
            // Next consecutive day -- increment
            return StreakState(currentStreak: currentStreak + 1, lastPlayedDate: todayStart, isActive: true)
        }

        // 2+ day gap -- pause at current value (no reset)
        return StreakState(currentStreak: currentStreak, lastPlayedDate: todayStart, isActive: false)
    }
}
