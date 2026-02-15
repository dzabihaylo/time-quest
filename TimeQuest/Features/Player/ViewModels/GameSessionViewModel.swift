import Foundation
import SwiftData

// MARK: - Quest Phase State Machine

enum QuestPhase: Equatable {
    case selecting
    case estimating(taskIndex: Int)
    case active(taskIndex: Int)
    case revealing(taskIndex: Int)
    case summary
}

// MARK: - Game Session ViewModel

@MainActor
@Observable
final class GameSessionViewModel {
    var phase: QuestPhase = .selecting
    var routine: Routine?
    var session: GameSession?
    var estimatedMinutes: Int = 0
    var estimatedSeconds: Int = 0
    var currentResult: EstimationResult?
    var currentFeedback: FeedbackMessage?
    var isCalibration: Bool = false
    private(set) var sessionXPEarned: Int = 0
    private(set) var isNewPersonalBest: Bool = false
    private(set) var didLevelUp: Bool = false
    private(set) var previousLevel: Int = 0
    private(set) var contextualHints: [String: String] = [:]

    private var taskStartedAt: Date?
    private var sessionMaxDifficultyLevel: Int = 1
    private let sessionRepository: SessionRepositoryProtocol
    private let routineRepository: RoutineRepositoryProtocol
    private let playerProfileRepository: PlayerProfileRepositoryProtocol
    private let modelContext: ModelContext

    private let activeTaskKey = "activeTaskStartedAt"

    var currentTaskIndex: Int {
        switch phase {
        case .estimating(let i), .active(let i), .revealing(let i):
            return i
        default:
            return 0
        }
    }

    var currentTask: RoutineTask? {
        guard let routine else { return nil }
        let tasks = routine.orderedTasks
        guard currentTaskIndex < tasks.count else { return nil }
        return tasks[currentTaskIndex]
    }

    var totalTasks: Int {
        routine?.orderedTasks.count ?? 0
    }

    var estimatedTotalSeconds: Double {
        Double(estimatedMinutes * 60 + estimatedSeconds)
    }

    var currentTaskHint: String? {
        guard !isCalibration, let task = currentTask else { return nil }
        return contextualHints[task.displayName]
    }

    init(
        routine: Routine,
        sessionRepository: SessionRepositoryProtocol,
        routineRepository: RoutineRepositoryProtocol,
        playerProfileRepository: PlayerProfileRepositoryProtocol,
        modelContext: ModelContext
    ) {
        self.routine = routine
        self.sessionRepository = sessionRepository
        self.routineRepository = routineRepository
        self.playerProfileRepository = playerProfileRepository
        self.modelContext = modelContext

        // Crash recovery: clear any interrupted session
        UserDefaults.standard.removeObject(forKey: activeTaskKey)
    }

    // MARK: - State Transitions

    func startQuest() {
        guard let routine else { return }

        let completedSessions = sessionRepository.fetchSessions(for: routine)
            .filter { $0.completedAt != nil }
            .count

        isCalibration = CalibrationTracker.isCalibrationSession(completedSessionCount: completedSessions)
        session = sessionRepository.createSession(for: routine, isCalibration: isCalibration)

        // Preload contextual hints for all tasks (skip during calibration)
        if !isCalibration {
            let descriptor = FetchDescriptor<TaskEstimation>(
                sortBy: [SortDescriptor(\.recordedAt)]
            )
            let allEstimations = (try? modelContext.fetch(descriptor)) ?? []
            let snapshots = allEstimations.map { EstimationSnapshot(from: $0) }

            for task in routine.orderedTasks {
                if let hint = InsightEngine.contextualHint(taskName: task.displayName, snapshots: snapshots) {
                    contextualHints[task.displayName] = hint
                }
            }
        }

        phase = .estimating(taskIndex: 0)
    }

    func submitEstimation() {
        let now = Date.now
        taskStartedAt = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: activeTaskKey)

        let taskIndex = currentTaskIndex
        estimatedMinutes = 0
        estimatedSeconds = 0
        phase = .active(taskIndex: taskIndex)
    }

    func completeTask() {
        guard let taskStartedAt,
              let session,
              let task = currentTask else { return }

        let completedAt = Date.now
        let actualSeconds = completedAt.timeIntervalSince(taskStartedAt)
        let estimatedSec = estimatedTotalSeconds

        // Score
        let result = TimeEstimationScorer.score(
            estimated: estimatedSec,
            actual: actualSeconds
        )

        // Generate feedback
        let feedback = FeedbackGenerator.message(
            for: result,
            isCalibrationPhase: isCalibration
        )

        // Persist estimation
        let estimation = TaskEstimation(
            taskDisplayName: task.displayName,
            estimatedSeconds: estimatedSec,
            actualSeconds: actualSeconds,
            differenceSeconds: result.differenceSeconds,
            accuracyPercent: result.accuracyPercent,
            ratingRawValue: result.rating.rawValue,
            orderIndex: currentTaskIndex,
            recordedAt: completedAt
        )
        modelContext.insert(estimation)
        estimation.session = session

        try? modelContext.save()

        // Clear crash recovery
        UserDefaults.standard.removeObject(forKey: activeTaskKey)
        self.taskStartedAt = nil

        // Update state
        currentResult = result
        currentFeedback = feedback
        phase = .revealing(taskIndex: currentTaskIndex)
    }

    // Store the estimated seconds before transitioning to active phase
    private var pendingEstimatedSeconds: Double = 0

    func lockInEstimation(minutes: Int, seconds: Int) {
        pendingEstimatedSeconds = Double(minutes * 60 + seconds)

        let now = Date.now
        taskStartedAt = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: activeTaskKey)

        phase = .active(taskIndex: currentTaskIndex)
    }

    func completeActiveTask() {
        guard let taskStartedAt,
              let session,
              let task = currentTask else { return }

        let completedAt = Date.now
        let actualSeconds = completedAt.timeIntervalSince(taskStartedAt)

        // Fetch difficulty state for this task and get level-appropriate thresholds
        let diffState = fetchOrCreateDifficultyState(for: task.displayName)
        let thresholds = AdaptiveDifficultyEngine.thresholds(forLevel: diffState.difficultyLevel)

        let result = TimeEstimationScorer.score(
            estimated: pendingEstimatedSeconds,
            actual: actualSeconds,
            thresholds: thresholds
        )

        let feedback = FeedbackGenerator.message(
            for: result,
            isCalibrationPhase: isCalibration
        )

        let estimation = TaskEstimation(
            taskDisplayName: task.displayName,
            estimatedSeconds: pendingEstimatedSeconds,
            actualSeconds: actualSeconds,
            differenceSeconds: result.differenceSeconds,
            accuracyPercent: result.accuracyPercent,
            ratingRawValue: result.rating.rawValue,
            orderIndex: currentTaskIndex,
            recordedAt: completedAt
        )
        modelContext.insert(estimation)
        estimation.session = session

        try? modelContext.save()

        // Update difficulty state (skip during calibration sessions)
        if !isCalibration {
            let newEMA = AdaptiveDifficultyEngine.updatedEMA(
                currentAccuracy: result.accuracyPercent,
                previousEMA: diffState.ema
            )
            let totalEstimations = totalEstimationsCount(for: task.displayName)
            let newLevel = AdaptiveDifficultyEngine.difficultyLevel(
                ema: newEMA,
                currentLevel: diffState.difficultyLevel,
                totalEstimations: totalEstimations
            )

            diffState.ema = newEMA
            if newLevel > diffState.difficultyLevel {
                diffState.difficultyLevel = newLevel
                diffState.sessionsAtCurrentLevel = 0
            } else {
                diffState.sessionsAtCurrentLevel += 1
            }
            diffState.lastUpdated = completedAt
        }

        sessionMaxDifficultyLevel = max(sessionMaxDifficultyLevel, diffState.difficultyLevel)

        try? modelContext.save()

        // Check for personal best (compare against all previous estimations for this task)
        let allSessions = sessionRepository.fetchAllSessions()
        let previousEstimations = allSessions.flatMap { $0.orderedEstimations }
            .filter { $0.taskDisplayName == task.displayName && $0.recordedAt != completedAt }
        isNewPersonalBest = PersonalBestTracker.isNewPersonalBest(
            taskDisplayName: task.displayName,
            differenceSeconds: result.differenceSeconds,
            existingEstimations: previousEstimations
        )

        UserDefaults.standard.removeObject(forKey: activeTaskKey)
        self.taskStartedAt = nil

        currentResult = result
        currentFeedback = feedback
        phase = .revealing(taskIndex: currentTaskIndex)
    }

    func advanceToNextTask() {
        isNewPersonalBest = false
        let nextIndex = currentTaskIndex + 1

        if nextIndex < totalTasks {
            currentResult = nil
            currentFeedback = nil
            pendingEstimatedSeconds = 0
            phase = .estimating(taskIndex: nextIndex)
        } else {
            // All tasks done
            session?.completedAt = .now

            // Award XP (scaled by max difficulty level across all tasks in session)
            if let session {
                let xp = XPEngine.xpForSession(
                    estimations: session.orderedEstimations,
                    difficultyLevel: sessionMaxDifficultyLevel
                )
                session.xpEarned = xp
                session.difficultyLevel = sessionMaxDifficultyLevel
                session.xpMultiplier = AdaptiveDifficultyEngine.xpMultiplier(
                    forLevel: sessionMaxDifficultyLevel
                )

                let profile = playerProfileRepository.fetchOrCreate()
                previousLevel = LevelCalculator.level(fromTotalXP: profile.totalXP)
                playerProfileRepository.addXP(xp, to: profile)
                didLevelUp = LevelCalculator.level(fromTotalXP: profile.totalXP) > previousLevel
                playerProfileRepository.updateStreak(for: profile, on: .now)
                sessionXPEarned = xp
            }

            try? modelContext.save()
            phase = .summary
        }
    }

    func finishQuest() {
        routine = nil
        session = nil
        currentResult = nil
        currentFeedback = nil
        isCalibration = false
        pendingEstimatedSeconds = 0
        sessionXPEarned = 0
        isNewPersonalBest = false
        didLevelUp = false
        contextualHints = [:]
        sessionMaxDifficultyLevel = 1
        phase = .selecting
    }

    // MARK: - Adaptive Difficulty Helpers

    private func fetchOrCreateDifficultyState(for taskDisplayName: String) -> TaskDifficultyState {
        let descriptor = FetchDescriptor<TaskDifficultyState>(
            predicate: #Predicate { $0.taskDisplayName == taskDisplayName }
        )
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            return existing
        }
        let state = TaskDifficultyState(taskDisplayName: taskDisplayName)
        modelContext.insert(state)
        return state
    }

    private func totalEstimationsCount(for taskDisplayName: String) -> Int {
        let descriptor = FetchDescriptor<TaskEstimation>(
            predicate: #Predicate { $0.taskDisplayName == taskDisplayName }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Calibration Helpers

    var calibrationSessionsRemaining: Int {
        guard let routine else { return 0 }
        let completedCount = sessionRepository.fetchSessions(for: routine)
            .filter { $0.completedAt != nil }
            .count
        return CalibrationTracker.calibrationSessionsRemaining(completedSessionCount: completedCount)
    }
}
