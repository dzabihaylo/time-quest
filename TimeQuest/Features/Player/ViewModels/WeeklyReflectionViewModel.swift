import Foundation
import SwiftData

// MARK: - UserDefaults Week Tracking

enum ReflectionDefaults {
    private static let lastShownWeekKey = "reflection_lastShownWeek"
    private static let dismissedWeekKey = "reflection_dismissedWeek"

    static func weekIdentifier(for date: Date) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return "\(year)-W\(String(format: "%02d", week))"
    }

    static var lastShownWeek: String? {
        get { UserDefaults.standard.string(forKey: lastShownWeekKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastShownWeekKey) }
    }

    static var dismissedWeek: String? {
        get { UserDefaults.standard.string(forKey: dismissedWeekKey) }
        set { UserDefaults.standard.set(newValue, forKey: dismissedWeekKey) }
    }

    static func shouldShowReflection(now: Date = .now) -> Bool {
        let (prevWeekStart, _) = WeeklyReflectionEngine.previousWeekBounds(from: now)
        let previousWeekID = weekIdentifier(for: prevWeekStart)
        if lastShownWeek != previousWeekID { return true }
        return dismissedWeek != previousWeekID
    }
}

// MARK: - WeeklyReflectionViewModel

@MainActor
@Observable
final class WeeklyReflectionViewModel {
    var currentReflection: WeeklyReflection?
    var shouldShowCard: Bool = false
    var reflectionHistory: [WeeklyReflection] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Lazily check and compute reflection on app open (REQ-038).
    func refresh() {
        guard ReflectionDefaults.shouldShowReflection() else {
            shouldShowCard = false
            loadHistory()
            return
        }

        let now = Date.now
        let (weekStart, weekEnd) = WeeklyReflectionEngine.previousWeekBounds(from: now)
        let (priorStart, priorEnd) = WeeklyReflectionEngine.weekBounds(weeksBack: 2, from: now)

        // Fetch snapshots covering both weeks
        let allSnapshots = fetchSnapshots(from: priorStart, to: weekEnd)

        // Split snapshots for each week
        let weekSnapshots = allSnapshots.filter { $0.recordedAt >= weekStart && $0.recordedAt < weekEnd }
        let priorSnapshots = allSnapshots.filter { $0.recordedAt >= priorStart && $0.recordedAt < priorEnd }

        // Count completed sessions via GameSession query (not snapshot counting)
        let questCount = countCompletedSessions(from: weekStart, to: weekEnd)

        let reflection = WeeklyReflectionEngine.computeReflection(
            snapshots: weekSnapshots,
            weekStart: weekStart,
            weekEnd: weekEnd,
            priorWeekSnapshots: priorSnapshots.isEmpty ? nil : priorSnapshots,
            completedQuestCount: questCount
        )

        if reflection.isMeaningful {
            currentReflection = reflection
            shouldShowCard = true
            ReflectionDefaults.lastShownWeek = ReflectionDefaults.weekIdentifier(for: weekStart)
        }

        loadHistory()
    }

    /// Dismiss the current reflection card (REQ-039).
    func dismissCurrentReflection() {
        shouldShowCard = false
        if let reflection = currentReflection {
            ReflectionDefaults.dismissedWeek = ReflectionDefaults.weekIdentifier(for: reflection.weekStartDate)
        }
    }

    // MARK: - Private Helpers

    /// Load up to 4 weeks of reflection history for stats view (REQ-040, REQ-042).
    private func loadHistory() {
        let now = Date.now
        var history: [WeeklyReflection] = []

        for weeksBack in 1...4 {
            let (weekStart, weekEnd) = WeeklyReflectionEngine.weekBounds(weeksBack: weeksBack, from: now)

            // Get prior week bounds for comparison
            let (priorStart, priorEnd) = WeeklyReflectionEngine.weekBounds(weeksBack: weeksBack + 1, from: now)

            let allSnapshots = fetchSnapshots(from: priorStart, to: weekEnd)
            let weekSnapshots = allSnapshots.filter { $0.recordedAt >= weekStart && $0.recordedAt < weekEnd }
            let priorSnapshots = allSnapshots.filter { $0.recordedAt >= priorStart && $0.recordedAt < priorEnd }

            let questCount = countCompletedSessions(from: weekStart, to: weekEnd)

            let reflection = WeeklyReflectionEngine.computeReflection(
                snapshots: weekSnapshots,
                weekStart: weekStart,
                weekEnd: weekEnd,
                priorWeekSnapshots: priorSnapshots.isEmpty ? nil : priorSnapshots,
                completedQuestCount: questCount
            )

            if reflection.isMeaningful {
                history.append(reflection)
            }
        }

        reflectionHistory = history
    }

    /// Fetch TaskEstimation records and map to EstimationSnapshot.
    private func fetchSnapshots(from start: Date, to end: Date) -> [EstimationSnapshot] {
        let descriptor = FetchDescriptor<TaskEstimation>(
            predicate: #Predicate { $0.recordedAt >= start && $0.recordedAt < end },
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        let estimations = (try? modelContext.fetch(descriptor)) ?? []
        return estimations.map { EstimationSnapshot(from: $0) }
    }

    /// Count completed non-calibration sessions within a date range.
    /// Uses GameSession query -- not snapshot counting -- for accurate quest counts.
    /// NOTE: completedAt is Date?, so we fetch all completed sessions and filter in-memory.
    private func countCompletedSessions(from start: Date, to end: Date) -> Int {
        let descriptor = FetchDescriptor<GameSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return sessions.filter { session in
            guard let completedAt = session.completedAt else { return false }
            return completedAt >= start && completedAt < end && !session.isCalibration
        }.count
    }
}
