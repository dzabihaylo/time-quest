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

    // MARK: - Private Helpers

    /// Filter to non-calibration snapshots only.
    private static func eligibleSnapshots(from snapshots: [EstimationSnapshot]) -> [EstimationSnapshot] {
        snapshots.filter { !$0.isCalibration }
    }

    // MARK: - Analysis Functions

    /// Detect whether a player tends to overestimate or underestimate a task.
    /// Returns nil if fewer than `minimumSessions` non-calibration snapshots.
    static func detectBias(snapshots: [EstimationSnapshot]) -> BiasResult? {
        let eligible = eligibleSnapshots(from: snapshots)
        guard eligible.count >= minimumSessions else { return nil }

        let meanDifference = eligible.map(\.differenceSeconds).reduce(0, +) / Double(eligible.count)

        let direction: BiasDirection
        if meanDifference > biasThresholdSeconds {
            direction = .overestimates
        } else if meanDifference < -biasThresholdSeconds {
            direction = .underestimates
        } else {
            direction = .balanced
        }

        return BiasResult(
            taskDisplayName: eligible[0].taskDisplayName,
            direction: direction,
            meanDifferenceSeconds: meanDifference,
            sampleCount: eligible.count
        )
    }

    /// Detect accuracy trend (improving, declining, or stable) using linear regression.
    /// Returns nil if fewer than `minimumSessions` non-calibration snapshots.
    static func detectTrend(snapshots: [EstimationSnapshot]) -> TrendResult? {
        let eligible = eligibleSnapshots(from: snapshots)
            .sorted { $0.recordedAt < $1.recordedAt }
        guard eligible.count >= minimumSessions else { return nil }

        // Simple linear regression: y = accuracy, x = index (0, 1, 2, ...)
        let n = Double(eligible.count)
        let xs = (0..<eligible.count).map { Double($0) }
        let ys = eligible.map(\.accuracyPercent)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map(*).reduce(0, +)
        let sumX2 = xs.map { $0 * $0 }.reduce(0, +)

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denominator

        let direction: TrendDirection
        if slope > trendSlopeThreshold {
            direction = .improving
        } else if slope < -trendSlopeThreshold {
            direction = .declining
        } else {
            direction = .stable
        }

        return TrendResult(
            taskDisplayName: eligible[0].taskDisplayName,
            direction: direction,
            slopePerSession: slope,
            sampleCount: eligible.count
        )
    }

    /// Compute estimation consistency using coefficient of variation on absolute differences.
    /// Returns nil if fewer than `minimumSessions` non-calibration snapshots.
    static func computeConsistency(snapshots: [EstimationSnapshot]) -> ConsistencyResult? {
        let eligible = eligibleSnapshots(from: snapshots)
        guard eligible.count >= minimumSessions else { return nil }

        let absDiffs = eligible.map { abs($0.differenceSeconds) }
        let mean = absDiffs.reduce(0, +) / Double(absDiffs.count)

        guard mean > 0 else {
            // Perfect estimates every time -- maximum consistency
            return ConsistencyResult(
                taskDisplayName: eligible[0].taskDisplayName,
                level: .veryConsistent,
                coefficientOfVariation: 0,
                sampleCount: eligible.count
            )
        }

        let variance = absDiffs.map { pow($0 - mean, 2) }.reduce(0, +) / Double(absDiffs.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean

        let level: ConsistencyLevel
        if cv < consistencyLowCV {
            level = .veryConsistent
        } else if cv < consistencyHighCV {
            level = .moderate
        } else {
            level = .variable
        }

        return ConsistencyResult(
            taskDisplayName: eligible[0].taskDisplayName,
            level: level,
            coefficientOfVariation: cv,
            sampleCount: eligible.count
        )
    }

    /// Generate a contextual reference hint like "Last 5 times: ~2m 30s".
    /// Returns nil if fewer than `minimumSessions` non-calibration snapshots for the given task.
    static func contextualHint(taskName: String, snapshots: [EstimationSnapshot]) -> String? {
        let eligible = snapshots
            .filter { $0.taskDisplayName == taskName && !$0.isCalibration }
            .sorted { $0.recordedAt > $1.recordedAt }

        guard eligible.count >= minimumSessions else { return nil }

        let recentN = Array(eligible.prefix(5))
        let avgActual = recentN.map(\.actualSeconds).reduce(0, +) / Double(recentN.count)
        let formatted = TimeFormatting.formatDuration(avgActual)

        return "Last \(recentN.count) times: ~\(formatted)"
    }

    /// Group snapshots by task and generate insights for each task with sufficient data.
    static func generateInsights(snapshots: [EstimationSnapshot]) -> [TaskInsight] {
        let eligible = eligibleSnapshots(from: snapshots)
        let byTask = Dictionary(grouping: eligible) { $0.taskDisplayName }

        return byTask.compactMap { taskName, taskSnapshots in
            guard taskSnapshots.count >= minimumSessions else { return nil }

            let recentActuals = taskSnapshots
                .sorted { $0.recordedAt > $1.recordedAt }
                .prefix(5)
                .map(\.actualSeconds)

            return TaskInsight(
                taskDisplayName: taskName,
                routineName: taskSnapshots[0].routineName,
                bias: detectBias(snapshots: taskSnapshots),
                trend: detectTrend(snapshots: taskSnapshots),
                consistency: computeConsistency(snapshots: taskSnapshots),
                recentActualSeconds: Array(recentActuals)
            )
        }
    }
}
