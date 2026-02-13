import SwiftUI

struct AccuracyMeter: View {
    let accuracyPercent: Double
    let rating: AccuracyRating

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)

                // Filled arc
                Circle()
                    .trim(from: 0, to: animatedProgress / 100)
                    .stroke(ratingColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 2) {
                    Text("\(Int(animatedProgress))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()

                    Text(ratingLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = min(accuracyPercent, 100)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Accuracy: \(Int(accuracyPercent)) percent, \(ratingLabel)")
    }

    private var ratingColor: Color {
        switch rating {
        case .spot_on:  Color.orange          // Gold/accent -- achievement
        case .close:    Color.teal            // Positive neutral
        case .off:      Color(.systemGray3)   // Cool neutral
        case .way_off:  Color.purple          // Discovery color
        }
    }

    private var ratingLabel: String {
        switch rating {
        case .spot_on:  "Nailed it"
        case .close:    "Close"
        case .off:      "Interesting"
        case .way_off:  "Discovery"
        }
    }
}
