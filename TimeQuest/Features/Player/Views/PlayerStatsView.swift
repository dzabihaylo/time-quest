import SwiftUI

struct PlayerStatsView: View {
    let viewModel: ProgressionViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section 1: Accuracy Trend
                VStack(alignment: .leading, spacing: 12) {
                    Text("Accuracy Trend")
                        .font(.headline)
                        .padding(.leading, 4)

                    AccuracyTrendChartView(dataPoints: viewModel.chartDataPoints)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Section 2: Personal Bests
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Bests")
                        .font(.headline)
                        .padding(.leading, 4)

                    if viewModel.personalBests.isEmpty {
                        Text("Complete some quests to see your personal bests here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(viewModel.personalBests, id: \.taskDisplayName) { best in
                            personalBestRow(best)
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
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(TimeFormatting.formatDuration(abs(best.closestDifferenceSeconds))) off")
                    .font(.caption)
                    .foregroundStyle(.teal)
            }

            Spacer()

            Text(best.date, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
