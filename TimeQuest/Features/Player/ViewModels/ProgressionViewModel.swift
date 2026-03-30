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
    var heatmapData: [Date: DayActivity] = [:]

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

    func loadHeatmapData() {
        let allSessions = sessionRepository.fetchAllSessions()
        let completedSessions = allSessions.filter { $0.completedAt != nil }

        let calendar = Calendar.current
        var dailyMap: [Date: (quests: Int, accuracies: [Double], ratings: [AccuracyRating])] = [:]

        for session in completedSessions {
            guard let completedAt = session.completedAt else { continue }
            let dayStart = calendar.startOfDay(for: completedAt)

            var entry = dailyMap[dayStart] ?? (quests: 0, accuracies: [], ratings: [])
            entry.quests += 1
            for estimation in session.orderedEstimations {
                entry.accuracies.append(estimation.accuracyPercent)
                entry.ratings.append(estimation.rating)
            }
            dailyMap[dayStart] = entry
        }

        heatmapData = dailyMap.reduce(into: [:]) { result, pair in
            let (date, data) = pair
            let avgAccuracy = data.accuracies.isEmpty ? 0.0 :
                data.accuracies.reduce(0.0, +) / Double(data.accuracies.count)

            // Best rating: spot_on > close > off > way_off
            let bestRating = data.ratings.min { ratingOrder($0) < ratingOrder($1) } ?? .way_off

            result[date] = DayActivity(
                questsCompleted: data.quests,
                averageAccuracy: avgAccuracy,
                bestRating: bestRating
            )
        }
    }

    private func ratingOrder(_ rating: AccuracyRating) -> Int {
        switch rating {
        case .spot_on: return 0
        case .close: return 1
        case .off: return 2
        case .way_off: return 3
        }
    }

    func refresh() {
        loadProfile()
        loadPersonalBests()
        loadChartData()
        loadHeatmapData()
    }
}
