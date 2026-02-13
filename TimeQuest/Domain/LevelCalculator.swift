import Foundation

struct LevelCalculator: Sendable {
    /// Reads level-curve constants from the shared XP configuration.
    private static var configuration: XPConfiguration { XPEngine.configuration }

    /// Total XP required to reach a given level.
    static func xpRequired(forLevel level: Int) -> Int {
        Int(configuration.levelBaseXP * pow(Double(level), configuration.levelExponent))
    }

    /// Current level based on accumulated XP. Returns 0 if xp <= 0.
    static func level(fromTotalXP xp: Int) -> Int {
        guard xp > 0 else { return 0 }
        return max(1, Int(floor(pow(Double(xp) / configuration.levelBaseXP, 1.0 / configuration.levelExponent))))
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
