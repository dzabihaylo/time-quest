import Foundation

struct WeeklyReflection: Sendable {
    let weekStartDate: Date
    let weekEndDate: Date

    // REQ-034: Core metrics
    let questsCompleted: Int
    let averageAccuracy: Double          // 0-100
    let accuracyChangeVsPriorWeek: Double?  // Signed delta; nil if no prior week data

    // REQ-035: Highlights
    let bestEstimateTaskName: String?
    let bestEstimateAccuracy: Double?
    let mostImprovedTaskName: String?
    let mostImprovedDelta: Double?       // Positive = improved

    // REQ-036: Streak context (positive framing)
    let daysPlayedThisWeek: Int          // 0-7
    let totalDaysInWeek: Int             // Always 7

    // REQ-037: Insight highlight
    let patternHighlight: String?

    // REQ-042: Metadata
    let hasGaps: Bool
    let totalEstimations: Int

    var streakContextString: String {
        "\(daysPlayedThisWeek) of \(totalDaysInWeek) days"
    }

    var isMeaningful: Bool {
        questsCompleted > 0
    }

    var formattedAccuracyChange: String? {
        guard let delta = accuracyChangeVsPriorWeek else { return nil }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(Int(delta))%"
    }
}
