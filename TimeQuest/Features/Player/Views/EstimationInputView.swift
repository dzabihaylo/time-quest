import SwiftUI

struct EstimationInputView: View {
    @Bindable var viewModel: GameSessionViewModel
    let soundManager: SoundManager
    @Environment(\.designTokens) private var tokens

    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var lockInHapticTrigger = false

    var body: some View {
        VStack(spacing: 24) {
            // Step indicator
            Text("Step \(viewModel.currentTaskIndex + 1) of \(viewModel.totalTasks)")
                .font(tokens.font(.caption))
                .foregroundStyle(tokens.textSecondary)
                .padding(.top, 8)

            Spacer()

            // Calibration banner
            if viewModel.isCalibration {
                calibrationBanner
            }

            // Contextual hint (only for tasks with known patterns)
            if let hint = viewModel.currentTaskHint {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(tokens.font(.caption))
                        .foregroundStyle(tokens.accentSecondary)
                    Text(hint)
                        .font(tokens.font(.caption))
                        .foregroundStyle(tokens.textSecondary)
                }
                .padding(.horizontal, tokens.spacingMD)
                .padding(.vertical, tokens.spacingSM - 2)
                .background(tokens.surfaceSecondary)
                .clipShape(Capsule())
            }

            // Task name
            Text(viewModel.currentTask?.displayName ?? "")
                .font(tokens.font(.title, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("How long will this take?")
                .font(tokens.font(.title3))
                .foregroundStyle(tokens.textSecondary)

            // Duration picker
            HStack(spacing: 0) {
                Picker("Minutes", selection: $minutes) {
                    ForEach(0...59, id: \.self) { m in
                        Text("\(m) min").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 140)

                Picker("Seconds", selection: $seconds) {
                    ForEach(0...59, id: \.self) { s in
                        Text("\(s) sec").tag(s)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 140)
            }
            .frame(height: 150)

            Spacer()

            // Lock it in
            Button {
                lockInHapticTrigger.toggle()
                soundManager.play("estimate_lock")
                viewModel.lockInEstimation(minutes: minutes, seconds: seconds)
                minutes = 0
                seconds = 0
            } label: {
                Text("Lock It In")
                    .font(tokens.font(.headline))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(minutes == 0 && seconds == 0)
            .padding(.horizontal, tokens.spacingXXL)
            .padding(.bottom, tokens.spacingXXL)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.6), trigger: lockInHapticTrigger)
        }
    }

    private var calibrationBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(tokens.font(.caption))
            Text("Calibration -- just learning your patterns")
                .font(tokens.font(.caption))
        }
        .padding(.horizontal, tokens.spacingMD)
        .padding(.vertical, tokens.spacingSM - 2)
        .background(tokens.surfaceSecondary)
        .clipShape(Capsule())
    }
}
