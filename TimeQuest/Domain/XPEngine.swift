import Foundation

struct XPEngine: Sendable {
    /// Shared configuration -- set once at app launch, read everywhere.
    /// Uses nonisolated(unsafe) for Swift 6 strict concurrency (same pattern
    /// as VersionedSchema.versionIdentifier). Safe because the value is set
    /// once before any concurrent reads.
    nonisolated(unsafe) static var configuration = XPConfiguration.default

    /// XP awarded for a single estimation based on accuracy rating.
    /// Rewards accuracy, never speed. Per-estimation XP scales with level multiplier.
    static func xpForEstimation(rating: AccuracyRating, difficultyLevel: Int = 1) -> Int {
        let base: Int
        switch rating {
        case .spot_on: base = configuration.spotOnXP
        case .close:   base = configuration.closeXP
        case .off:     base = configuration.offXP
        case .way_off: base = configuration.wayOffXP
        }
        let multiplier = DifficultyConfiguration.default.xpMultiplier(forLevel: difficultyLevel)
        return Int(Double(base) * multiplier)
    }

    /// Total XP for a completed session: sum of per-task XP + completion bonus.
    /// Completion bonus is NOT multiplied -- only per-estimation XP scales with level.
    static func xpForSession(estimations: [TaskEstimation], difficultyLevel: Int = 1) -> Int {
        let taskXP = estimations.reduce(0) { $0 + xpForEstimation(rating: $1.rating, difficultyLevel: difficultyLevel) }
        return taskXP + configuration.completionBonus
    }
}
