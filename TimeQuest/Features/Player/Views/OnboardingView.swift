import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

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
                            .font(.headline)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
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
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

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
