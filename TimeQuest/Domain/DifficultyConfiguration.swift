import Foundation

struct AccuracyThresholds: Sendable {
    let spotOn: Double    // Max abs difference ratio for spot_on
    let close: Double     // Max abs difference ratio for close
    let off: Double       // Max abs difference ratio for off
    // Anything beyond `off` is way_off
}

struct DifficultyConfiguration: Sendable {
    /// EMA smoothing factor. 0.3 = recent performance matters ~3x more than old.
    var emaAlpha: Double = 0.3

    /// Minimum completed estimations for a task before difficulty can advance beyond level 1.
    var minimumSessionsToAdvance: Int = 5

    /// EMA thresholds for advancing to each level.
    /// Levels: 1 (default), 2, 3, 4, 5
    var levelEMAThresholds: [Double] = [
        0,    // Level 1: everyone starts here
        65,   // Level 2: consistently above 65% accuracy
        75,   // Level 3: consistently above 75% accuracy
        83,   // Level 4: consistently above 83% accuracy
        90    // Level 5: consistently above 90% accuracy
    ]

    /// Accuracy band thresholds per level.
    /// As level increases, bands tighten (harder to earn top ratings).
    var thresholdsPerLevel: [AccuracyThresholds] = [
        AccuracyThresholds(spotOn: 0.10, close: 0.25, off: 0.50),  // Level 1: generous
        AccuracyThresholds(spotOn: 0.08, close: 0.20, off: 0.40),  // Level 2: slightly tighter
        AccuracyThresholds(spotOn: 0.06, close: 0.15, off: 0.35),  // Level 3: moderate
        AccuracyThresholds(spotOn: 0.05, close: 0.12, off: 0.30),  // Level 4: tight
        AccuracyThresholds(spotOn: 0.04, close: 0.10, off: 0.25),  // Level 5: very tight
    ]

    /// XP multiplier per level. Higher level = more XP reward.
    var xpMultipliers: [Double] = [
        1.0,   // Level 1: baseline
        1.15,  // Level 2: +15%
        1.35,  // Level 3: +35%
        1.60,  // Level 4: +60%
        2.00,  // Level 5: double XP
    ]

    /// Minimum absolute threshold in seconds (floor for very short tasks).
    var minimumAbsoluteThresholdSeconds: Double = 15.0

    static let `default` = DifficultyConfiguration()

    func levelForEMA(_ ema: Double) -> Int {
        var level = 1
        for (i, threshold) in levelEMAThresholds.enumerated() {
            if ema >= threshold { level = i + 1 }
        }
        return level
    }

    func thresholds(forLevel level: Int) -> AccuracyThresholds {
        let index = min(max(level - 1, 0), thresholdsPerLevel.count - 1)
        return thresholdsPerLevel[index]
    }

    func xpMultiplier(forLevel level: Int) -> Double {
        let index = min(max(level - 1, 0), xpMultipliers.count - 1)
        return xpMultipliers[index]
    }
}
