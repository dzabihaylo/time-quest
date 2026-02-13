import Foundation
import SwiftData

// MARK: - Chart Data Point

struct AccuracyDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let averageAccuracy: Double
}

// MARK: - Progression ViewModel

@MainActor
@Observable
final class ProgressionViewModel {
    var currentLevel: Int = 0
    var totalXP: Int = 0
    var xpProgress: Double = 0.0
    var xpForNextLevel: Int = 0
    var currentStreak: Int = 0
    var isStreakActive: Bool = false
    var personalBests: [PersonalBestTracker.PersonalBest] = []
    var chartDataPoints: [AccuracyDataPoint] = []

    private let playerProfileRepository: PlayerProfileRepositoryProtocol
    private let sessionRepository: SessionRepositoryProtocol
    private let modelContext: ModelContext

    init(
        playerProfileRepository: PlayerProfileRepositoryProtocol,
        sessionRepository: SessionRepositoryProtocol,
        modelContext: ModelContext
    ) {
        self.playerProfileRepository = playerProfileRepository
        self.sessionRepository = sessionRepository
        self.modelContext = modelContext
    }

    func loadProfile() {
        let profile = playerProfileRepository.fetchOrCreate()

        totalXP = profile.totalXP
        currentLevel = LevelCalculator.level(fromTotalXP: profile.totalXP)
        xpProgress = LevelCalculator.progressToNextLevel(totalXP: profile.totalXP)
        xpForNextLevel = LevelCalculator.xpRequired(forLevel: currentLevel + 1)
        currentStreak = profile.currentStreak

        // Determine if streak is active (played today)
        if let lastPlayed = profile.lastPlayedDate {
            let calendar = Calendar.current
            isStreakActive = calendar.isDateInToday(lastPlayed)
        } else {
            isStreakActive = false
        }
    }

    func loadPersonalBests() {
        let descriptor = FetchDescriptor<TaskEstimation>(
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        let allEstimations = (try? modelContext.fetch(descriptor)) ?? []
        personalBests = PersonalBestTracker.findPersonalBests(from: allEstimations)
    }

    func loadChartData() {
        let allSessions = sessionRepository.fetchAllSessions()
        let completedSessions = allSessions.filter { $0.completedAt != nil }

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: .now) ?? .now

        // Group estimations by calendar day
        var dailyAccuracies: [Date: [Double]] = [:]

        for session in completedSessions {
            guard let completedAt = session.completedAt, completedAt >= thirtyDaysAgo else { continue }
            let dayStart = calendar.startOfDay(for: completedAt)

            for estimation in session.orderedEstimations {
                dailyAccuracies[dayStart, default: []].append(estimation.accuracyPercent)
            }
        }

        // Compute average per day, sorted by date
        chartDataPoints = dailyAccuracies
            .map { day, accuracies in
                let avg = accuracies.reduce(0.0, +) / Double(accuracies.count)
                return AccuracyDataPoint(date: day, averageAccuracy: avg)
            }
            .sorted { $0.date < $1.date }
    }

    func refresh() {
        loadProfile()
        loadPersonalBests()
        loadChartData()
    }
}
