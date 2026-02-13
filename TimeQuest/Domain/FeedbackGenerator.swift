import Foundation

struct FeedbackMessage {
    let headline: String
    let body: String
    let emoji: String  // SF Symbol name
}

struct FeedbackGenerator {
    /// Returns a curiosity-framed message based on estimation accuracy.
    /// NEVER returns judgmental language. Large gaps are "discoveries."
    static func message(for result: EstimationResult, isCalibrationPhase: Bool) -> FeedbackMessage {
        let diffFormatted = formatDuration(result.absDifferenceSeconds)
        let direction = result.differenceSeconds > 0 ? "over" : "under"

        if isCalibrationPhase {
            return calibrationMessage(diffFormatted: diffFormatted, direction: direction)
        }

        switch result.rating {
        case .spot_on:
            return FeedbackMessage(
                headline: "Nailed it!",
                body: "Your time sense was right on.",
                emoji: "bullseye"
            )
        case .close:
            return FeedbackMessage(
                headline: "\(diffFormatted) \(direction)",
                body: "Getting dialed in.",
                emoji: "scope"
            )
        case .off:
            return FeedbackMessage(
                headline: "\(diffFormatted) \(direction)",
                body: "Interesting -- that one felt different than it was.",
                emoji: "magnifyingglass"
            )
        case .way_off:
            return FeedbackMessage(
                headline: "\(diffFormatted) \(direction)!",
                body: "Big discovery! This one's tricky to feel.",
                emoji: "sparkles"
            )
        }
    }

    private static func calibrationMessage(diffFormatted: String, direction: String) -> FeedbackMessage {
        FeedbackMessage(
            headline: "\(diffFormatted) \(direction)",
            body: "Just learning your patterns. Every guess teaches something.",
            emoji: "chart.line.uptrend.xyaxis"
        )
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}
