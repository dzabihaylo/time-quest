import SwiftUI

/// The task-in-progress screen.
/// CRITICAL: This view shows ZERO time information.
/// No clock. No countdown. No timer. No elapsed time.
/// The player relies entirely on her internal sense of time.
struct TaskActiveView: View {
    let viewModel: GameSessionViewModel
    @Environment(\.designTokens) private var tokens

    @State private var breatheScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.2

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Context label + task name (so a number doesn't look like a countdown)
            VStack(spacing: 8) {
                Text("NOW DOING")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tokens.accent)
                    .tracking(2)

                Text(viewModel.currentTask?.displayName ?? "")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(tokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Ambient breathing ring
            ZStack {
                Circle()
                    .fill(tokens.accent.opacity(glowOpacity))
                    .frame(width: 60, height: 60)
                    .blur(radius: 20)

                Circle()
                    .fill(tokens.accent.opacity(0.4))
                    .frame(width: 16, height: 16)
                    .scaleEffect(breatheScale)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    breatheScale = 1.8
                    glowOpacity = 0.5
                }
            }

            Text("GO!")
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(tokens.accent)
                .tracking(4)

            Spacer()
            Spacer()

            // Done button
            Button {
                viewModel.completeActiveTask()
            } label: {
                Text("I'M DONE")
                    .tqPrimaryButton()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, tokens.spacingXXL)
            .padding(.bottom, 40)
        }
    }
}
