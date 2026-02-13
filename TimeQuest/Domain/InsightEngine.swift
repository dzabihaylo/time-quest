import Foundation

// MARK: - Result Types

enum BiasDirection: String, Sendable {
    case overestimates
    case underestimates
    case balanced
}

struct BiasResult: Sendable {
    let taskDisplayName: String
    let direction: BiasDirection
    let meanDifferenceSeconds: Double
    let sampleCount: Int
}

enum TrendDirection: String, Sendable {
    case improving
    case declining
    case stable
}

struct TrendResult: Sendable {
    let taskDisplayName: String
    let direction: TrendDirection
    let slopePerSession: Double
    let sampleCount: Int
}

enum ConsistencyLevel: String, Sendable {
    case veryConsistent
    case moderate
    case variable
}

struct ConsistencyResult: Sendable {
    let taskDisplayName: String
    let level: ConsistencyLevel
    let coefficientOfVariation: Double
    let sampleCount: Int
}

struct TaskInsight: Sendable {
    let taskDisplayName: String
    let routineName: String
    let bias: BiasResult?
    let trend: TrendResult?
    let consistency: ConsistencyResult?
    let recentActualSeconds: [Double]
}

// MARK: - InsightEngine

struct InsightEngine {

    // MARK: Thresholds

    static let minimumSessions = 5
    static let biasThresholdSeconds = 15.0
    static let trendSlopeThreshold = 0.5
    static let consistencyLowCV = 0.3
    static let consistencyHighCV = 0.6

    // MARK: Analysis Functions (stubs -- TDD RED phase)

    /// Detect whether a player tends to overestimate or underestimate a task.
    /// Returns nil if fewer than `minimumSessions` non-calibration snapshots.
    static func detectBias(snapshots: [EstimationSnapshot]) -> BiasResult? {
        return nil
    }

    /// Detect accuracy trend (improving, declining, or stable) using linear regression.
    /// Returns nil if fewer than `minimumSessions` non-calibration snapshots.
    static func detectTrend(snapshots: [EstimationSnapshot]) -> TrendResult? {
        return nil
    }

    /// Compute estimation consistency using coefficient of variation on absolute differences.
    /// Returns nil if fewer than `minimumSessions` non-calibration snapshots.
    static func computeConsistency(snapshots: [EstimationSnapshot]) -> ConsistencyResult? {
        return nil
    }

    /// Generate a contextual reference hint like "Last 5 times: ~2m 30s".
    /// Returns nil if fewer than `minimumSessions` non-calibration snapshots for the given task.
    static func contextualHint(taskName: String, snapshots: [EstimationSnapshot]) -> String? {
        return nil
    }

    /// Group snapshots by task and generate insights for each task with sufficient data.
    static func generateInsights(snapshots: [EstimationSnapshot]) -> [TaskInsight] {
        return []
    }
}
