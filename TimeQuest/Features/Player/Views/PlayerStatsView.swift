import SwiftUI

struct PlayerStatsView: View {
    @Environment(\.designTokens) private var tokens

    let viewModel: ProgressionViewModel
    var reflectionHistory: [WeeklyReflection] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section 1: Accuracy Trend
                VStack(alignment: .leading, spacing: 12) {
                    Text("Accuracy Trend")
                        .font(tokens.font(.headline))
                        .padding(.leading, 4)

                    AccuracyTrendChartView(dataPoints: viewModel.chartDataPoints)
                        .tqCard()
                }

                // Section 2: Personal Bests
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Bests")
                        .font(tokens.font(.headline))
                        .padding(.leading, 4)

                    if viewModel.personalBests.isEmpty {
                        Text("Complete some quests to see your personal bests here")
                            .font(tokens.font(.subheadline))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .tqCard()
                    } else {
                        ForEach(viewModel.personalBests, id: \.taskDisplayName) { best in
                            personalBestRow(best)
                        }
                    }
                }

                // Section 3: Weekly Recaps (REQ-040)
                if !reflectionHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weekly Recaps")
                            .font(tokens.font(.headline))
                            .padding(.leading, 4)

                        ForEach(reflectionHistory, id: \.weekStartDate) { reflection in
                            miniReflectionRow(reflection)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .navigationTitle("Your Stats")
        .onAppear {
            viewModel.refresh()
        }
    }

    private func personalBestRow(_ best: PersonalBestTracker.PersonalBest) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(best.taskDisplayName)
                    .font(tokens.font(.subheadline, weight: .medium))

                Text("\(TimeFormatting.formatDuration(abs(best.closestDifferenceSeconds))) off")
                    .font(tokens.font(.caption))
                    .foregroundStyle(tokens.accent)
            }

            Spacer()

            Text(best.date, style: .relative)
                .font(tokens.font(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(tokens.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadiusMD))
    }

    private func miniReflectionRow(_ reflection: WeeklyReflection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reflection.weekStartDate, format: .dateTime.month(.abbreviated).day())
                    .font(tokens.font(.subheadline, weight: .medium))

                HStack(spacing: 8) {
                    Label("\(reflection.questsCompleted) quests", systemImage: "checkmark.circle")
                    Label("\(Int(reflection.averageAccuracy))%", systemImage: "target")
                }
                .font(tokens.font(.caption))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(reflection.streakContextString)
                .font(tokens.font(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(tokens.surfaceTertiary)
        .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadiusMD))
    }
}
