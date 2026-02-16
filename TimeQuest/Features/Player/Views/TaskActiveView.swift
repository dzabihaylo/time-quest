import SwiftUI

/// The task-in-progress screen.
/// CRITICAL: This view shows ZERO time information.
/// No clock. No countdown. No timer. No elapsed time.
/// The player relies entirely on her internal sense of time.
struct TaskActiveView: View {
    let viewModel: GameSessionViewModel
    @Environment(\.designTokens) private var tokens

    @State private var breatheScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Ambient breathing dot -- indicates app is alive without showing time
            Circle()
                .fill(tokens.accent.opacity(0.3))
                .frame(width: 12, height: 12)
                .scaleEffect(breatheScale)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        breatheScale = 1.8
                    }
                }

            // Task name
            Text(viewModel.currentTask?.displayName ?? "")
                .font(tokens.font(.largeTitle, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Go!")
                .font(tokens.font(.title2))
                .foregroundStyle(tokens.textSecondary)

            Spacer()
            Spacer()

            // Done button
            Button {
                viewModel.completeActiveTask()
            } label: {
                Text("I'm Done")
                    .font(tokens.font(.headline))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}
