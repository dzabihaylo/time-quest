import SwiftUI
import Charts

struct AccuracyTrendChartView: View {
    let dataPoints: [AccuracyDataPoint]
    @Environment(\.designTokens) private var tokens

    var body: some View {
        if dataPoints.isEmpty {
            Text("Complete a few quests to see your accuracy trend")
                .font(tokens.font(.subheadline))
                .foregroundStyle(tokens.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
        } else {
            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Accuracy", point.averageAccuracy)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(tokens.accent)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Accuracy", point.averageAccuracy)
                )
                .foregroundStyle(tokens.accent)
                .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue))%")
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 200)
        }
    }
}
