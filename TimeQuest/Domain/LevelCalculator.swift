import Foundation

struct LevelCalculator {
    private static let baseXP: Double = 100
    private static let exponent: Double = 1.5

    /// Total XP required to reach a given level.
    static func xpRequired(forLevel level: Int) -> Int {
        Int(baseXP * pow(Double(level), exponent))
    }

    /// Current level based on accumulated XP. Returns 0 if xp <= 0.
    static func level(fromTotalXP xp: Int) -> Int {
        guard xp > 0 else { return 0 }
        return max(1, Int(floor(pow(Double(xp) / baseXP, 1.0 / exponent))))
    }

    /// Progress toward the next level as a fraction from 0.0 to 1.0.
    static func progressToNextLevel(totalXP: Int) -> Double {
        let currentLevel = level(fromTotalXP: totalXP)
        let currentLevelXP = xpRequired(forLevel: currentLevel)
        let nextLevelXP = xpRequired(forLevel: currentLevel + 1)

        let range = nextLevelXP - currentLevelXP
        guard range > 0 else { return 0.0 }

        let progress = Double(totalXP - currentLevelXP) / Double(range)
        return min(1.0, max(0.0, progress))
    }
}
