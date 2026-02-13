import Foundation

struct PersonalBestTracker {
    struct PersonalBest {
        let taskDisplayName: String
        let closestDifferenceSeconds: Double
        let date: Date
    }

    /// Find the personal best (closest estimate) for each unique task across all estimations.
    static func findPersonalBests(from estimations: [TaskEstimation]) -> [PersonalBest] {
        let grouped = Dictionary(grouping: estimations) { $0.taskDisplayName }

        return grouped.compactMap { taskName, taskEstimations in
            guard let best = taskEstimations.min(by: { abs($0.differenceSeconds) < abs($1.differenceSeconds) }) else {
                return nil
            }
            return PersonalBest(
                taskDisplayName: taskName,
                closestDifferenceSeconds: best.differenceSeconds,
                date: best.recordedAt
            )
        }
    }

    /// Returns true if this difference is a new personal best for the given task.
    /// Compares against all existing estimations (should exclude the current one).
    static func isNewPersonalBest(
        taskDisplayName: String,
        differenceSeconds: Double,
        existingEstimations: [TaskEstimation]
    ) -> Bool {
        let previousForTask = existingEstimations.filter { $0.taskDisplayName == taskDisplayName }

        // If no previous estimations for this task, it's the first -- always a personal best
        guard !previousForTask.isEmpty else { return true }

        let currentAbsDiff = abs(differenceSeconds)
        let previousBest = previousForTask.map { abs($0.differenceSeconds) }.min() ?? .infinity

        return currentAbsDiff < previousBest
    }
}
