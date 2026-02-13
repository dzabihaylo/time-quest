import SwiftUI

struct InsightCardView: View {
    let insight: TaskInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Task name header
            Text(insight.taskDisplayName)
                .font(.headline)

            // Bias row
            if let bias = insight.bias {
                switch bias.direction {
                case .overestimates:
                    insightRow(
                        icon: "arrow.up.right",
                        color: .orange,
                        text: "Interesting -- you tend to overestimate by ~\(TimeFormatting.formatDuration(abs(bias.meanDifferenceSeconds)))"
                    )
                case .underestimates:
                    insightRow(
                        icon: "arrow.down.right",
                        color: .teal,
                        text: "Interesting -- you tend to underestimate by ~\(TimeFormatting.formatDuration(abs(bias.meanDifferenceSeconds)))"
                    )
                case .balanced:
                    insightRow(
                        icon: "checkmark.circle",
                        color: .green,
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
                        color: .green,
                        text: "Your estimates are getting closer over time"
                    )
                case .declining:
                    insightRow(
                        icon: "chart.line.downtrend.xyaxis",
                        color: .orange,
                        text: "This one's been harder to read lately"
                    )
                case .stable:
                    insightRow(
                        icon: "equal",
                        color: .secondary,
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
                        color: .green,
                        text: "You read this one the same way each time"
                    )
                case .moderate:
                    insightRow(
                        icon: "waveform.path",
                        color: .secondary,
                        text: "Your estimates vary a bit from time to time"
                    )
                case .variable:
                    insightRow(
                        icon: "waveform.path.ecg",
                        color: .orange,
                        text: "This one's unpredictable -- your estimates vary quite a bit"
                    )
                }
            }

            // Sample count footer
            if let sampleCount = insight.bias?.sampleCount ?? insight.trend?.sampleCount ?? insight.consistency?.sampleCount {
                Text("Based on \(sampleCount) sessions")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
