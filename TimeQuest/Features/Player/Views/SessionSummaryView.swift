import SwiftUI
import SpriteKit

struct SessionSummaryView: View {
    let viewModel: GameSessionViewModel
    let soundManager: SoundManager
    let onFinish: () -> Void

    @State private var summaryAppearTrigger = false
    @State private var showLevelUpCelebration = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Quest Complete")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                // Level-up celebration overlay
                if viewModel.didLevelUp, showLevelUpCelebration {
                    let scene: CelebrationScene = {
                        let s = CelebrationScene()
                        s.celebrationType = .levelUp
                        return s
                    }()
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .frame(width: 250, height: 250)
                        .allowsHitTesting(false)
                }

                // Calibration message
                if viewModel.isCalibration {
                    let remaining = viewModel.calibrationSessionsRemaining
                    VStack(spacing: 4) {
                        Text("Calibration session complete!")
                            .font(.headline)
                        if remaining > 0 {
                            Text("\(remaining) more to go before your baseline is set")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Baseline established -- game on!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // XP earned this session
                if viewModel.sessionXPEarned > 0 {
                    VStack(spacing: 8) {
                        Text("+\(viewModel.sessionXPEarned) XP")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.teal)

                        if viewModel.didLevelUp {
                            Text("Level Up!")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Summary stats
                if let session = viewModel.session {
                    summaryStats(session)
                }

                // Task results
                if let session = viewModel.session {
                    taskResultsList(session)
                }

                // Spotify song count (SPOT-05: invisible without Spotify data per SPOT-06)
                if let songCount = viewModel.session?.spotifySongCount {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("You got through \(songCount)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 20)

                Button {
                    onFinish()
                } label: {
                    Text("Finish")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding(.horizontal)
            .sensoryFeedback(.success, trigger: summaryAppearTrigger)
        }
        .onAppear {
            summaryAppearTrigger.toggle()

            // Play sounds
            if viewModel.didLevelUp {
                soundManager.play("level_up")
                withAnimation(.easeOut.delay(0.3)) {
                    showLevelUpCelebration = true
                }
            } else {
                soundManager.play("session_complete")
            }
        }
    }

    private func summaryStats(_ session: GameSession) -> some View {
        let estimations = session.orderedEstimations

        let avgAccuracy = estimations.isEmpty ? 0.0 :
            estimations.reduce(0.0) { $0 + $1.accuracyPercent } / Double(estimations.count)

        let overCount = estimations.filter { $0.differenceSeconds > 0 }.count
        let underCount = estimations.filter { $0.differenceSeconds < 0 }.count

        let bestTask = estimations.max(by: { $0.accuracyPercent < $1.accuracyPercent })

        return VStack(spacing: 16) {
            HStack(spacing: 24) {
                statCard(
                    value: "\(Int(avgAccuracy))%",
                    label: "Average"
                )

                statCard(
                    value: "\(overCount) over",
                    label: "Overestimates"
                )

                statCard(
                    value: "\(underCount) under",
                    label: "Underestimates"
                )
            }

            if let best = bestTask {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Best: \(best.taskDisplayName) (\(Int(best.accuracyPercent))%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func taskResultsList(_ session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.headline)
                .padding(.leading, 4)

            ForEach(session.orderedEstimations, id: \.recordedAt) { estimation in
                taskResultRow(estimation)
            }
        }
    }

    private func taskResultRow(_ estimation: TaskEstimation) -> some View {
        HStack {
            // Rating icon
            Image(systemName: ratingIcon(estimation.rating))
                .foregroundStyle(ratingColor(estimation.rating))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(estimation.taskDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("Est: \(TimeFormatting.formatDuration(estimation.estimatedSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Act: \(TimeFormatting.formatDuration(estimation.actualSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Difference
            let direction = estimation.differenceSeconds > 0 ? "over" : "under"
            Text("\(TimeFormatting.formatDuration(abs(estimation.differenceSeconds))) \(direction)")
                .font(.caption)
                .foregroundStyle(
                    estimation.differenceSeconds > 0 ? Color.orange.opacity(0.8) : Color.teal.opacity(0.8)
                )
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func ratingIcon(_ rating: AccuracyRating) -> String {
        switch rating {
        case .spot_on:  "bullseye"
        case .close:    "scope"
        case .off:      "magnifyingglass"
        case .way_off:  "sparkles"
        }
    }

    private func ratingColor(_ rating: AccuracyRating) -> Color {
        switch rating {
        case .spot_on:  .orange
        case .close:    .teal
        case .off:      Color(.systemGray3)
        case .way_off:  .purple
        }
    }
}
