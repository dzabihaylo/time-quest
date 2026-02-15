import Foundation

struct AdaptiveDifficultyEngine {
    /// Compute updated EMA from current accuracy and previous EMA.
    /// EMA = (accuracy * alpha) + (previousEMA * (1 - alpha))
    static func updatedEMA(
        currentAccuracy: Double,
        previousEMA: Double,
        alpha: Double = DifficultyConfiguration.default.emaAlpha
    ) -> Double {
        (currentAccuracy * alpha) + (previousEMA * (1.0 - alpha))
    }

    /// Determine the performance level for a task based on its EMA.
    /// Monotonic: returns max(currentLevel, computed level) -- NEVER decreases.
    /// Requires minimum total estimations before allowing advancement past level 1.
    static func difficultyLevel(
        ema: Double,
        currentLevel: Int,
        totalEstimations: Int,
        config: DifficultyConfiguration = .default
    ) -> Int {
        // Cannot advance beyond level 1 until minimum estimations completed
        guard totalEstimations >= config.minimumSessionsToAdvance else {
            return max(1, currentLevel)
        }
        let computed = config.levelForEMA(ema)
        return max(currentLevel, computed)  // Never decrease
    }

    /// Get accuracy thresholds for a given level.
    static func thresholds(
        forLevel level: Int,
        config: DifficultyConfiguration = .default
    ) -> AccuracyThresholds {
        config.thresholds(forLevel: level)
    }

    /// XP multiplier for a given level.
    static func xpMultiplier(
        forLevel level: Int,
        config: DifficultyConfiguration = .default
    ) -> Double {
        config.xpMultiplier(forLevel: level)
    }
}
