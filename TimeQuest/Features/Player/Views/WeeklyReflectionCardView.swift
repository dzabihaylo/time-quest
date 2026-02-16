import SwiftUI

struct WeeklyReflectionCardView: View {
    let reflection: WeeklyReflection
    let onDismiss: () -> Void
    @Environment(\.designTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingMD) {
            // 1. Header row
            HStack {
                Label("Last Week", systemImage: "calendar")
                    .font(tokens.font(.subheadline, weight: .bold))
                    .foregroundStyle(tokens.accent)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(tokens.textSecondary)
                        .font(tokens.font(.title3))
                }
                .buttonStyle(.plain)
            }

            // 2. Stat pills row
            HStack(spacing: 0) {
                statPill(
                    value: "\(reflection.questsCompleted)",
                    label: "Quests",
                    valueColor: tokens.textPrimary
                )

                statPill(
                    value: "\(Int(reflection.averageAccuracy))%",
                    label: "Accuracy",
                    valueColor: tokens.textPrimary
                )

                if let change = reflection.accuracyChangeVsPriorWeek,
                   let formatted = reflection.formattedAccuracyChange {
                    statPill(
                        value: formatted,
                        label: "vs Last Week",
                        valueColor: change >= 0 ? tokens.positive : tokens.caution
                    )
                }
            }

            // 3. Highlights row (only if at least one highlight exists)
            if reflection.bestEstimateTaskName != nil || reflection.mostImprovedTaskName != nil {
                HStack(spacing: tokens.spacingSM) {
                    if let bestName = reflection.bestEstimateTaskName,
                       let bestAcc = reflection.bestEstimateAccuracy {
                        highlightChip(
                            icon: "star.fill",
                            color: tokens.accentSecondary,
                            text: "\(bestName) \(Int(bestAcc))%"
                        )
                    }

                    if let improvedName = reflection.mostImprovedTaskName {
                        highlightChip(
                            icon: "arrow.up.right",
                            color: tokens.positive,
                            text: improvedName
                        )
                    }
                }
            }

            // 4. Footer row
            HStack {
                Label(reflection.streakContextString, systemImage: "flame.fill")
                    .font(tokens.font(.caption))
                    .foregroundStyle(tokens.textSecondary)

                Spacer()

                if let highlight = reflection.patternHighlight {
                    Text(highlight)
                        .font(tokens.font(.caption))
                        .foregroundStyle(tokens.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .tqCard()
    }

    // MARK: - Private Helpers

    private func statPill(value: String, label: String, valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(tokens.font(.title2, weight: .bold))
                .foregroundStyle(valueColor)

            Text(label)
                .font(tokens.font(.caption))
                .foregroundStyle(tokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func highlightChip(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: tokens.spacingXS) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .lineLimit(1)
        }
        .font(tokens.font(.caption))
        .padding(.horizontal, tokens.spacingSM)
        .padding(.vertical, tokens.spacingXS)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
