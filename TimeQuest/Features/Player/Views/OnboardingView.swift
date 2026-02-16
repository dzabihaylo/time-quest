import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.designTokens) private var tokens

    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                // Screen 1: This is your time game
                onboardingPage(
                    icon: "clock.badge.questionmark",
                    title: "TimeQuest",
                    body: "Discover how your brain sees time.\nNo clocks. No pressure.\nJust you and your gut feeling.",
                    tag: 0
                )

                // Screen 2: Guess, do, discover
                onboardingPage(
                    icon: "sparkle.magnifyingglass",
                    title: "How it works",
                    body: "Pick a quest.\nGuess how long each step takes.\nDo it.\nThen see how close you were.",
                    tag: 1
                )

                // Screen 3: Calibration
                onboardingPage(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Calibration mode",
                    body: "Your first few sessions are calibration --\nthe game is learning YOUR patterns.\nEvery guess teaches it something new.",
                    tag: 2
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Bottom buttons
            HStack {
                if currentPage < 2 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .fontWeight(.semibold)
                } else {
                    Spacer()

                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Let's go")
                            .font(tokens.font(.headline))
                            .padding(.horizontal, tokens.spacingXXL)
                            .padding(.vertical, tokens.spacingMD)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func onboardingPage(icon: String, title: String, body: String, tag: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 72, design: .rounded))
                .foregroundStyle(tokens.accent)

            Text(title)
                .font(tokens.font(.largeTitle, weight: .bold))

            Text(body)
                .font(tokens.font(.body))
                .foregroundStyle(tokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, tokens.spacingXXL)

            Spacer()
            Spacer()
        }
        .tag(tag)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        onComplete()
    }
}
