import SwiftUI

/// A modern heatmap calendar showing daily quest activity and accuracy.
/// Each day is a rounded cell colored by performance — empty days are dim,
/// played days glow from cool to warm based on accuracy.
/// Inspired by GitHub contributions, Apple Fitness, and Duolingo streaks.
struct ActivityHeatmapView: View {
    let dailyData: [Date: DayActivity]
    let weeksToShow: Int

    @Environment(\.designTokens) private var tokens

    /// Number of rows (days of week): Mon-Sun
    private let rows = 7

    init(dailyData: [Date: DayActivity], weeksToShow: Int = 12) {
        self.dailyData = dailyData
        self.weeksToShow = weeksToShow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingSM) {
            // Month labels
            monthLabels

            HStack(alignment: .top, spacing: 3) {
                // Day-of-week labels
                dayLabels

                // The grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(weeks, id: \.self) { weekStart in
                            weekColumn(startingFrom: weekStart)
                        }
                    }
                }
            }

            // Legend
            legend
        }
    }

    // MARK: - Grid

    private func weekColumn(startingFrom weekStart: Date) -> some View {
        VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { dayOffset in
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!
                dayCell(for: date)
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let activity = dailyData[Calendar.current.startOfDay(for: date)]
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Date.now

        return RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(activity: activity, isFuture: isFuture))
            .frame(width: 14, height: 14)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(.white.opacity(0.6), lineWidth: 1)
                }
            }
            .overlay {
                // Spot-on days get a subtle glow
                if let activity, activity.bestRating == .spot_on {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cellColor(activity: activity, isFuture: false))
                        .blur(radius: 3)
                        .opacity(0.5)
                }
            }
    }

    private func cellColor(activity: DayActivity?, isFuture: Bool) -> Color {
        if isFuture {
            return .clear
        }
        guard let activity else {
            // No activity — dim empty cell
            return Color.white.opacity(0.04)
        }

        // Color gradient based on accuracy: purple → teal → green → orange → gold
        let accuracy = activity.averageAccuracy
        return accuracyColor(accuracy)
    }

    /// Maps accuracy (0-100) to a vibrant color spectrum.
    /// Low accuracy = muted purple, medium = teal, high = vibrant green, perfect = gold glow
    private func accuracyColor(_ accuracy: Double) -> Color {
        switch accuracy {
        case 0..<30:
            return Color.purple.opacity(0.3)
        case 30..<50:
            return Color.purple.opacity(0.5)
        case 50..<65:
            return Color(red: 0.3, green: 0.4, blue: 0.8) // Indigo
        case 65..<75:
            return Color.teal.opacity(0.7)
        case 75..<85:
            return Color.teal
        case 85..<93:
            return Color.green
        case 93..<98:
            return Color(red: 0.2, green: 0.9, blue: 0.4) // Bright green
        default:
            return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        }
    }

    // MARK: - Labels

    private var dayLabels: some View {
        VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { index in
                let labels = ["M", "", "W", "", "F", "", ""]
                Text(labels[index])
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(tokens.textTertiary)
                    .frame(width: 14, height: 14)
            }
        }
    }

    private var monthLabels: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 17) // Offset for day labels
            ForEach(monthMarkers, id: \.offset) { marker in
                Text(marker.label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(tokens.textTertiary)
                if marker.offset < monthMarkers.count - 1 {
                    Spacer()
                }
            }
            Spacer()
        }
    }

    private var legend: some View {
        HStack(spacing: tokens.spacingSM) {
            Spacer()
            Text("Less")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(tokens.textTertiary)

            ForEach([20.0, 50.0, 70.0, 85.0, 95.0], id: \.self) { accuracy in
                RoundedRectangle(cornerRadius: 2)
                    .fill(accuracyColor(accuracy))
                    .frame(width: 10, height: 10)
            }

            Text("More")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(tokens.textTertiary)
        }
    }

    // MARK: - Date Computation

    /// Generate week start dates (Mondays) for the display range.
    private var weeks: [Date] {
        let calendar = Calendar.current
        let today = Date.now

        // Find the Monday of the current week
        var currentWeekStart = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: currentWeekStart)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let daysFromMonday = (weekday + 5) % 7 // Mon=0, Tue=1, ... Sun=6
        currentWeekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: currentWeekStart)!

        // Go back `weeksToShow` weeks
        var result: [Date] = []
        for weekOffset in stride(from: -(weeksToShow - 1), through: 0, by: 1) {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) {
                result.append(weekStart)
            }
        }
        return result
    }

    private struct MonthMarker: Identifiable {
        let offset: Int
        let label: String
        var id: Int { offset }
    }

    private var monthMarkers: [MonthMarker] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var markers: [MonthMarker] = []
        var lastMonth = -1

        for (index, weekStart) in weeks.enumerated() {
            let month = calendar.component(.month, from: weekStart)
            if month != lastMonth {
                markers.append(MonthMarker(offset: index, label: formatter.string(from: weekStart)))
                lastMonth = month
            }
        }
        return markers
    }
}

// MARK: - Day Activity Data

struct DayActivity {
    let questsCompleted: Int
    let averageAccuracy: Double
    let bestRating: AccuracyRating
}
