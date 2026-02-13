import Foundation

struct CalibrationTracker {
    /// Number of sessions required before a routine exits calibration phase.
    static let calibrationThreshold = 3

    /// Returns true if the routine is still in calibration phase.
    /// Calibration is per-routine: the caller passes the count of completed sessions for that specific routine.
    static func isCalibrationSession(completedSessionCount: Int) -> Bool {
        completedSessionCount < calibrationThreshold
    }

    /// Returns the number of calibration sessions remaining for a routine.
    static func calibrationSessionsRemaining(completedSessionCount: Int) -> Int {
        max(0, calibrationThreshold - completedSessionCount)
    }
}
