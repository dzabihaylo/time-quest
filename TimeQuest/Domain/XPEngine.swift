import Foundation

struct XPEngine: Sendable {
    /// Shared configuration -- set once at app launch, read everywhere.
    /// Uses nonisolated(unsafe) for Swift 6 strict concurrency (same pattern
    /// as VersionedSchema.versionIdentifier). Safe because the value is set
    /// once before any concurrent reads.
    nonisolated(unsafe) static var configuration = XPConfiguration.default

    /// XP awarded for a single estimation based on accuracy rating.
    /// Rewards accuracy, never speed.
    static func xpForEstimation(rating: AccuracyRating) -> Int {
        switch rating {
        case .spot_on: configuration.spotOnXP
        case .close:   configuration.closeXP
        case .off:     configuration.offXP
        case .way_off: configuration.wayOffXP
        }
    }

    /// Total XP for a completed session: sum of per-task XP + completion bonus.
    static func xpForSession(estimations: [TaskEstimation]) -> Int {
        let taskXP = estimations.reduce(0) { $0 + xpForEstimation(rating: $1.rating) }
        return taskXP + configuration.completionBonus
    }
}
