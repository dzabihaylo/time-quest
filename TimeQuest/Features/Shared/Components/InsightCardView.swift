import SwiftUI

struct InsightCardView: View {
    @Environment(\.designTokens) private var tokens

    let insight: TaskInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Task name header
            Text(insight.taskDisplayName)
                .font(tokens.font(.headline))

            // Bias row
            if let bias = insight.bias {
                switch bias.direction {
                case .overestimates:
                    insightRow(
                        icon: "arrow.up.right",
                        color: tokens.accentSecondary,
                        text: "Interesting -- you tend to overestimate by ~\(TimeFormatting.formatDuration(abs(bias.meanDifferenceSeconds)))"
                    )
                case .underestimates:
                    insightRow(
                        icon: "arrow.down.right",
                        color: tokens.accent,
                        text: "Interesting -- you tend to underestimate by ~\(TimeFormatting.formatDuration(abs(bias.meanDifferenceSeconds)))"
                    )
                case .balanced:
                    insightRow(
                        icon: "checkmark.circle",
                        color: tokens.positive,
                        text: "Your estimates are well-balanced"
                    )
                }
            }

            // Trend row
            if let trend = insight.trend {
                switch trend.direction {
                case .improving:
                    insightRow(
                        icon: "chart.line.uptrend.xyaxis",
                        color: tokens.positive,
                        text: "Your estimates are getting closer over time"
                    )
                case .declining:
                    insightRow(
                        icon: "chart.line.downtrend.xyaxis",
                        color: tokens.accentSecondary,
                        text: "This one's been harder to read lately"
                    )
                case .stable:
                    insightRow(
                        icon: "equal",
                        color: tokens.textSecondary,
                        text: "Steady -- your feel for this hasn't changed much"
                    )
                }
            }

            // Consistency row
            if let consistency = insight.consistency {
                switch consistency.level {
                case .veryConsistent:
                    insightRow(
                        icon: "waveform.path",
                        color: tokens.positive,
                        text: "You read this one the same way each time"
                    )
                case .moderate:
                    insightRow(
                        icon: "waveform.path",
                        color: tokens.textSecondary,
                        text: "Your estimates vary a bit from time to time"
                    )
                case .variable:
                    insightRow(
                        icon: "waveform.path.ecg",
                        color: tokens.accentSecondary,
                        text: "This one's unpredictable -- your estimates vary quite a bit"
                    )
                }
            }

            // Sample count footer
            if let sampleCount = insight.bias?.sampleCount ?? insight.trend?.sampleCount ?? insight.consistency?.sampleCount {
                Text("Based on \(sampleCount) sessions")
                    .font(tokens.font(.caption2))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tqCard(elevation: .nested)
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(tokens.font(.caption))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(tokens.font(.subheadline))
                .foregroundStyle(.primary)
        }
    }
}
