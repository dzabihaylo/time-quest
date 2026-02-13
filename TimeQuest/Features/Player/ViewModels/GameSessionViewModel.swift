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

    private var taskStartedAt: Date?
    private let sessionRepository: SessionRepositoryProtocol
    private let routineRepository: RoutineRepositoryProtocol
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

    init(
        routine: Routine,
        sessionRepository: SessionRepositoryProtocol,
        routineRepository: RoutineRepositoryProtocol,
        modelContext: ModelContext
    ) {
        self.routine = routine
        self.sessionRepository = sessionRepository
        self.routineRepository = routineRepository
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

        let result = TimeEstimationScorer.score(
            estimated: pendingEstimatedSeconds,
            actual: actualSeconds
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

        UserDefaults.standard.removeObject(forKey: activeTaskKey)
        self.taskStartedAt = nil

        currentResult = result
        currentFeedback = feedback
        phase = .revealing(taskIndex: currentTaskIndex)
    }

    func advanceToNextTask() {
        let nextIndex = currentTaskIndex + 1

        if nextIndex < totalTasks {
            currentResult = nil
            currentFeedback = nil
            pendingEstimatedSeconds = 0
            phase = .estimating(taskIndex: nextIndex)
        } else {
            // All tasks done
            session?.completedAt = .now
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
        phase = .selecting
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
