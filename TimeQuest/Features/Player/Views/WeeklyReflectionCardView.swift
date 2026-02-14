import SwiftUI

struct WeeklyReflectionCardView: View {
    let reflection: WeeklyReflection
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Header row
            HStack {
                Label("Last Week", systemImage: "calendar")
                    .font(.subheadline.bold())
                    .foregroundStyle(.teal)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // 2. Stat pills row
            HStack(spacing: 0) {
                statPill(
                    value: "\(reflection.questsCompleted)",
                    label: "Quests",
                    valueColor: .primary
                )

                statPill(
                    value: "\(Int(reflection.averageAccuracy))%",
                    label: "Accuracy",
                    valueColor: .primary
                )

                if let change = reflection.accuracyChangeVsPriorWeek,
                   let formatted = reflection.formattedAccuracyChange {
                    statPill(
                        value: formatted,
                        label: "vs Last Week",
                        valueColor: change >= 0 ? .green : .orange
                    )
                }
            }

            // 3. Highlights row (only if at least one highlight exists)
            if reflection.bestEstimateTaskName != nil || reflection.mostImprovedTaskName != nil {
                HStack(spacing: 8) {
                    if let bestName = reflection.bestEstimateTaskName,
                       let bestAcc = reflection.bestEstimateAccuracy {
                        highlightChip(
                            icon: "star.fill",
                            color: .orange,
                            text: "\(bestName) \(Int(bestAcc))%"
                        )
                    }

                    if let improvedName = reflection.mostImprovedTaskName {
                        highlightChip(
                            icon: "arrow.up.right",
                            color: .green,
                            text: improvedName
                        )
                    }
                }
            }

            // 4. Footer row
            HStack {
                Label(reflection.streakContextString, systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let highlight = reflection.patternHighlight {
                    Text(highlight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Private Helpers

    private func statPill(value: String, label: String, valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(valueColor)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func highlightChip(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
