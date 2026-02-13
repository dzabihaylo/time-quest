import SwiftUI

struct SchedulePickerView: View {
    @Binding var activeDays: [Int]

    /// Weekday symbols: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    /// Calendar weekday values: 1=Sun, 2=Mon, ..., 7=Sat
    private let weekdayValues = Array(1...7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day buttons
            HStack(spacing: 6) {
                ForEach(Array(zip(weekdayValues, weekdaySymbols)), id: \.0) { day, symbol in
                    dayButton(day: day, symbol: String(symbol.prefix(3)))
                }
            }

            // Quick-select shortcuts
            HStack(spacing: 12) {
                quickSelectButton("Weekdays", days: [2, 3, 4, 5, 6])
                quickSelectButton("Weekend", days: [1, 7])
                quickSelectButton("Every day", days: Array(1...7))
            }
            .font(.caption)
        }
    }

    private func dayButton(day: Int, symbol: String) -> some View {
        Button {
            toggleDay(day)
        } label: {
            Text(symbol)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 40, height: 40)
                .background(
                    activeDays.contains(day) ? Color.accentColor : Color(.systemGray5)
                )
                .foregroundStyle(
                    activeDays.contains(day) ? .white : .primary
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func quickSelectButton(_ label: String, days: [Int]) -> some View {
        Button {
            activeDays = days
        } label: {
            Text(label)
                .foregroundColor(activeDays.sorted() == days.sorted() ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func toggleDay(_ day: Int) {
        if activeDays.contains(day) {
            activeDays.removeAll { $0 == day }
        } else {
            activeDays.append(day)
            activeDays.sort()
        }
    }
}
