import Foundation

/// Represents the type of day determined from calendar analysis.
/// Used by CalendarContextEngine to decide which routines to show.
enum DayContext: Sendable {
    /// School events present, no "no school" markers found.
    case schoolDay
    /// Free day: holiday, break, summer, weekend, or no school events found.
    case freeDay(reason: String?)
    /// Calendar access denied or no data -- show everything for backward compatibility.
    case unknown
}

extension DayContext: Equatable {
    static func == (lhs: DayContext, rhs: DayContext) -> Bool {
        switch (lhs, rhs) {
        case (.schoolDay, .schoolDay):
            return true
        case (.freeDay, .freeDay):
            return true
        case (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}
