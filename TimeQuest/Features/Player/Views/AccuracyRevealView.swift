import SwiftUI
import SpriteKit

struct AccuracyRevealView: View {
    let viewModel: GameSessionViewModel

    @State private var showActual = false
    @State private var showFeedback = false
    @State private var showCelebration = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                // Celebration overlay for spot-on results
                if let result = viewModel.currentResult, result.rating == .spot_on, showCelebration {
                    SpriteView(scene: AccuracyRevealScene(), options: [.allowsTransparency])
                        .frame(width: 200, height: 200)
                        .allowsHitTesting(false)
                }

                // Estimated time
                if let result = viewModel.currentResult {
                    VStack(spacing: 4) {
                        Text("You estimated")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(TimeFormatting.formatDuration(result.estimatedSeconds))
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                    }

                    // Actual time (revealed with delay)
                    if showActual {
                        VStack(spacing: 4) {
                            Text("It actually took")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(TimeFormatting.formatDuration(result.actualSeconds))
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))

                        // Difference with direction
                        differenceView(result)
                            .transition(.opacity)

                        // Accuracy meter
                        AccuracyMeter(
                            accuracyPercent: result.accuracyPercent,
                            rating: result.rating
                        )
                        .padding(.vertical, 8)
                    }

                    // Feedback message
                    if showFeedback, let feedback = viewModel.currentFeedback {
                        feedbackCard(feedback)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Calibration info
                    if viewModel.isCalibration, showFeedback {
                        let remaining = viewModel.calibrationSessionsRemaining
                        Text("Calibration: \(remaining) session\(remaining == 1 ? "" : "s") to go")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 20)

                // Continue button
                Button {
                    viewModel.advanceToNextTask()
                } label: {
                    Text(viewModel.currentTaskIndex + 1 < viewModel.totalTasks ? "Next Step" : "See Results")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding()
        }
        .onAppear {
            // Staggered reveal
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                showActual = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
                showFeedback = true
            }
            if viewModel.currentResult?.rating == .spot_on {
                withAnimation(.easeOut.delay(0.6)) {
                    showCelebration = true
                }
            }
        }
    }

    private func differenceView(_ result: EstimationResult) -> some View {
        let direction = result.differenceSeconds > 0 ? "over" : "under"
        let directionColor: Color = result.differenceSeconds > 0
            ? Color.orange.opacity(0.8)   // Warm for over
            : Color.teal.opacity(0.8)     // Cool for under

        return HStack(spacing: 6) {
            Image(systemName: result.differenceSeconds > 0 ? "arrow.up.right" : "arrow.down.right")
                .foregroundStyle(directionColor)
            Text("\(TimeFormatting.formatDuration(result.absDifferenceSeconds)) \(direction)")
                .fontWeight(.medium)
                .foregroundStyle(directionColor)
        }
        .font(.title3)
    }

    private func feedbackCard(_ feedback: FeedbackMessage) -> some View {
        VStack(spacing: 8) {
            Image(systemName: feedback.emoji)
                .font(.title)
                .foregroundStyle(.tint)

            Text(feedback.headline)
                .font(.title3)
                .fontWeight(.semibold)

            Text(feedback.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
