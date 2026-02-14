import Foundation

// MARK: - WeeklyReflectionEngine

struct WeeklyReflectionEngine {

    // MARK: - Result Types

    struct ImprovementResult: Sendable {
        let taskName: String
        let delta: Double
    }

    // MARK: - Date Helpers

    /// Returns the start and end of the previous completed week relative to the given date.
    /// Uses Calendar for DST-safe date arithmetic.
    static func previousWeekBounds(from date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            // Fallback: should never happen with Calendar.current
            return (date, date)
        }
        let currentWeekStart = weekInterval.start
        guard let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) else {
            return (date, date)
        }
        return (start: prevWeekStart, end: currentWeekStart)
    }

    /// Returns the start and end of a week N weeks back from the given date.
    /// weeksBack = 0 means the current week, weeksBack = 1 means previous week, etc.
    static func weekBounds(weeksBack: Int, from date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return (date, date)
        }
        let currentWeekStart = weekInterval.start
        guard let targetStart = calendar.date(byAdding: .day, value: -7 * weeksBack, to: currentWeekStart),
              let targetEnd = calendar.date(byAdding: .day, value: 7, to: targetStart) else {
            return (date, date)
        }
        return (start: targetStart, end: targetEnd)
    }

    // MARK: - Core Computation

    /// Compute a weekly reflection from estimation snapshots for a given week.
    ///
    /// - Parameters:
    ///   - snapshots: All snapshots covering at least the target week
    ///   - weekStart: Start of the target week (inclusive)
    ///   - weekEnd: End of the target week (exclusive)
    ///   - priorWeekSnapshots: Snapshots from the prior week, or nil if unavailable
    ///   - completedQuestCount: Number of completed game sessions (quests), not snapshot count
    /// - Returns: A WeeklyReflection value containing all computed metrics
    static func computeReflection(
        snapshots: [EstimationSnapshot],
        weekStart: Date,
        weekEnd: Date,
        priorWeekSnapshots: [EstimationSnapshot]?,
        completedQuestCount: Int
    ) -> WeeklyReflection {
        let calendar = Calendar.current

        // Filter to non-calibration entries within [weekStart, weekEnd)
        let weekSnapshots = snapshots.filter { snapshot in
            !snapshot.isCalibration &&
            snapshot.recordedAt >= weekStart &&
            snapshot.recordedAt < weekEnd
        }

        // Core metrics
        let averageAccuracy: Double
        if weekSnapshots.isEmpty {
            averageAccuracy = 0
        } else {
            averageAccuracy = weekSnapshots.map(\.accuracyPercent).reduce(0, +) / Double(weekSnapshots.count)
        }

        // Accuracy change vs prior week
        let accuracyChange: Double?
        if let priorSnapshots = priorWeekSnapshots {
            let eligiblePrior = priorSnapshots.filter { !$0.isCalibration }
            if eligiblePrior.isEmpty {
                accuracyChange = nil
            } else {
                let priorAvg = eligiblePrior.map(\.accuracyPercent).reduce(0, +) / Double(eligiblePrior.count)
                accuracyChange = averageAccuracy - priorAvg
            }
        } else {
            accuracyChange = nil
        }

        // Best estimate: highest single accuracyPercent this week
        let bestSnapshot = weekSnapshots.max(by: { $0.accuracyPercent < $1.accuracyPercent })

        // Most improved task
        let improvement: ImprovementResult?
        if let priorSnapshots = priorWeekSnapshots {
            improvement = findMostImprovedTask(
                thisWeek: weekSnapshots,
                priorWeek: priorSnapshots.filter { !$0.isCalibration }
            )
        } else {
            improvement = nil
        }

        // Days played: unique calendar days from snapshot recordedAt
        let uniqueDays = Set(weekSnapshots.map { calendar.startOfDay(for: $0.recordedAt) })
        let daysPlayed = uniqueDays.count

        // Pattern highlight from InsightEngine
        let weekTaskNames = Set(weekSnapshots.map(\.taskDisplayName))
        let patternHighlight = pickPatternHighlight(
            from: snapshots,
            weekTaskNames: weekTaskNames
        )

        return WeeklyReflection(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            questsCompleted: completedQuestCount,
            averageAccuracy: averageAccuracy,
            accuracyChangeVsPriorWeek: accuracyChange,
            bestEstimateTaskName: bestSnapshot?.taskDisplayName,
            bestEstimateAccuracy: bestSnapshot?.accuracyPercent,
            mostImprovedTaskName: improvement?.taskName,
            mostImprovedDelta: improvement?.delta,
            daysPlayedThisWeek: daysPlayed,
            totalDaysInWeek: 7,
            patternHighlight: patternHighlight,
            hasGaps: daysPlayed < 7,
            totalEstimations: weekSnapshots.count
        )
    }

    // MARK: - Most Improved Task

    /// Find the task with the largest positive accuracy improvement between two weeks.
    /// Only considers tasks present in BOTH weeks with at least 2 estimations per week per task.
    static func findMostImprovedTask(
        thisWeek: [EstimationSnapshot],
        priorWeek: [EstimationSnapshot]
    ) -> ImprovementResult? {
        let thisWeekByTask = Dictionary(grouping: thisWeek) { $0.taskDisplayName }
        let priorWeekByTask = Dictionary(grouping: priorWeek) { $0.taskDisplayName }

        var bestImprovement: ImprovementResult?

        for (taskName, thisWeekSnapshots) in thisWeekByTask {
            guard let priorWeekSnapshots = priorWeekByTask[taskName] else { continue }

            // Require at least 2 estimations per week per task
            guard thisWeekSnapshots.count >= 2, priorWeekSnapshots.count >= 2 else { continue }

            let thisAvg = thisWeekSnapshots.map(\.accuracyPercent).reduce(0, +) / Double(thisWeekSnapshots.count)
            let priorAvg = priorWeekSnapshots.map(\.accuracyPercent).reduce(0, +) / Double(priorWeekSnapshots.count)
            let delta = thisAvg - priorAvg

            // Only consider positive improvements
            guard delta > 0 else { continue }

            if let current = bestImprovement {
                if delta > current.delta {
                    bestImprovement = ImprovementResult(taskName: taskName, delta: delta)
                }
            } else {
                bestImprovement = ImprovementResult(taskName: taskName, delta: delta)
            }
        }

        return bestImprovement
    }

    // MARK: - Pattern Highlight

    /// Pick one pattern highlight from InsightEngine, filtered to tasks played this week.
    /// Priority: (1) improving trend, (2) notable bias, (3) very consistent
    static func pickPatternHighlight(
        from allSnapshots: [EstimationSnapshot],
        weekTaskNames: Set<String>
    ) -> String? {
        guard !weekTaskNames.isEmpty else { return nil }

        let insights = InsightEngine.generateInsights(snapshots: allSnapshots)
        let weekInsights = insights.filter { weekTaskNames.contains($0.taskDisplayName) }

        guard !weekInsights.isEmpty else { return nil }

        // Priority 1: Improving trend
        for insight in weekInsights {
            if let trend = insight.trend, trend.direction == .improving {
                return "Your \(insight.taskDisplayName) estimates are getting closer over time"
            }
        }

        // Priority 2: Notable bias
        for insight in weekInsights {
            if let bias = insight.bias, bias.direction != .balanced {
                let verb = bias.direction == .overestimates ? "overestimate" : "underestimate"
                return "You tend to \(verb) \(insight.taskDisplayName)"
            }
        }

        // Priority 3: Very consistent
        for insight in weekInsights {
            if let consistency = insight.consistency, consistency.level == .veryConsistent {
                return "You read \(insight.taskDisplayName) the same way each time"
            }
        }

        return nil
    }
}
