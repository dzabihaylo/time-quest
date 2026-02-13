import Foundation

struct XPEngine {
    /// XP awarded for a single estimation based on accuracy rating.
    /// Rewards accuracy, never speed.
    static func xpForEstimation(rating: AccuracyRating) -> Int {
        switch rating {
        case .spot_on: 100
        case .close:    60
        case .off:      25
        case .way_off:  10
        }
    }

    /// Total XP for a completed session: sum of per-task XP + 20 completion bonus.
    static func xpForSession(estimations: [TaskEstimation]) -> Int {
        let taskXP = estimations.reduce(0) { $0 + xpForEstimation(rating: $1.rating) }
        return taskXP + 20
    }
}
