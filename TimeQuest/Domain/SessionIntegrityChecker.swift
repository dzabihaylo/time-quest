import Foundation

/// Detects implausible session data that suggests clock manipulation or gaming.
/// Pure Foundation — no UI, no SwiftData.
struct SessionIntegrityChecker {

    /// Minimum seconds a task must take to be considered plausible.
    /// Even the fastest real-world task takes ~3 seconds
    /// when you include the app interaction time.
    static let minimumPlausibleSeconds: Double = 3.0

    /// Maximum ratio of actual-to-estimated time before flagging as implausible.
    /// A task taking 20x longer than estimated suggests the app was left open.
    static let maximumDurationRatio: Double = 20.0

    /// Check if a task duration is plausible given the estimation.
    static func isPlausibleDuration(
        estimatedSeconds: Double,
        actualSeconds: Double
    ) -> Bool {
        guard actualSeconds >= 0 else { return false }
        guard actualSeconds >= minimumPlausibleSeconds else { return false }
        let maxAllowed = max(estimatedSeconds * maximumDurationRatio, 3600)
        guard actualSeconds <= maxAllowed else { return false }
        return true
    }

    /// Flag severity for implausible sessions.
    enum IntegrityFlag: String {
        case clean
        case suspiciouslyFast
        case clockManipulation
        case abandoned
    }

    /// Classify a session's integrity.
    static func classify(
        estimatedSeconds: Double,
        actualSeconds: Double
    ) -> IntegrityFlag {
        if actualSeconds < 0 { return .clockManipulation }
        if actualSeconds < minimumPlausibleSeconds { return .suspiciouslyFast }
        let maxAllowed = max(estimatedSeconds * maximumDurationRatio, 3600)
        if actualSeconds > maxAllowed { return .abandoned }
        return .clean
    }
}
