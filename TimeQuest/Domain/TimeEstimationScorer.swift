import Foundation

struct EstimationResult {
    let estimatedSeconds: TimeInterval
    let actualSeconds: TimeInterval
    let differenceSeconds: TimeInterval    // Signed: positive = overestimate
    let absDifferenceSeconds: TimeInterval
    let accuracyPercent: Double            // 0-100, 100 = perfect
    let rating: AccuracyRating
}

enum AccuracyRating: String, Codable {
    case spot_on    // Within max(15s, 10%)
    case close      // Within 25%
    case off        // Within 50%
    case way_off    // Beyond 50%
}

struct TimeEstimationScorer {
    /// Score an estimation against actual elapsed time.
    /// Pure function -- no side effects, no framework dependencies.
    /// The `thresholds` parameter controls how generous/tight the rating bands are.
    /// Default = Level 1 bands for backward compatibility with all existing callers.
    /// IMPORTANT: `accuracyPercent` is NEVER affected by thresholds -- only the rating changes.
    static func score(
        estimated: TimeInterval,
        actual: TimeInterval,
        thresholds: AccuracyThresholds = DifficultyConfiguration.default.thresholds(forLevel: 1)
    ) -> EstimationResult {
        let difference = estimated - actual
        let absDiff = abs(difference)

        // For very short tasks (< 60s), use absolute threshold scaled to 60s.
        // For longer tasks, use percentage of actual time.
        // This calculation is difficulty-independent -- keeps charts and insights fair.
        let accuracy: Double
        if actual < 60 {
            accuracy = max(0, 100 - (absDiff / 60 * 100))
        } else {
            accuracy = max(0, 100 - (absDiff / actual * 100))
        }

        let rating: AccuracyRating
        if absDiff <= max(DifficultyConfiguration.default.minimumAbsoluteThresholdSeconds, actual * thresholds.spotOn) {
            rating = .spot_on
        } else if absDiff <= actual * thresholds.close {
            rating = .close
        } else if absDiff <= actual * thresholds.off {
            rating = .off
        } else {
            rating = .way_off
        }

        return EstimationResult(
            estimatedSeconds: estimated,
            actualSeconds: actual,
            differenceSeconds: difference,
            absDifferenceSeconds: absDiff,
            accuracyPercent: accuracy,
            rating: rating
        )
    }
}
