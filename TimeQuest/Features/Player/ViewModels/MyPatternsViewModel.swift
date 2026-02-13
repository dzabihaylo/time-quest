import Foundation
import SwiftData

@MainActor
@Observable
final class MyPatternsViewModel {
    var insightsByRoutine: [(routineName: String, insights: [TaskInsight])] = []
    var isLoaded: Bool = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        // 1. Fetch all TaskEstimations
        let descriptor = FetchDescriptor<TaskEstimation>(
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        let allEstimations = (try? modelContext.fetch(descriptor)) ?? []

        // 2. Convert to snapshots
        let snapshots = allEstimations.map { EstimationSnapshot(from: $0) }

        // 3. Use InsightEngine to generate per-task insights (handles filtering + thresholds)
        let allInsights = InsightEngine.generateInsights(snapshots: snapshots)

        // 4. Group by routine name for display
        let byRoutine = Dictionary(grouping: allInsights) { $0.routineName }

        insightsByRoutine = byRoutine
            .map { routineName, insights in
                (routineName: routineName, insights: insights.sorted { $0.taskDisplayName < $1.taskDisplayName })
            }
            .sorted { $0.routineName < $1.routineName }

        isLoaded = true
    }
}
