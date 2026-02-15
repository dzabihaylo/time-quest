import Foundation

/// Lightweight value type representing a calendar event, bridging EventKit data
/// into a pure Foundation type for testability. Created by the EventKit service
/// layer (Plan 02), consumed here.
struct CalendarEvent: Sendable {
    let title: String
    let isAllDay: Bool
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
}

/// Pure domain engine that determines day context from calendar events.
/// No EventKit dependency -- operates on CalendarEvent value types.
/// Follows the same pattern as InsightEngine and AdaptiveDifficultyEngine.
struct CalendarContextEngine: Sendable {

    /// Keywords that indicate a "no school" day when found in event titles.
    static let noSchoolKeywords: [String] = [
        "no school",
        "school closed",
        "holiday",
        "break",
        "vacation",
        "teacher workday",
        "professional day",
        "snow day",
        "day off",
        "inservice",
        "in-service",
        "early release",
        "conference day",
        "pd day"
    ]

    /// Determines the day context from a set of calendar events and a date.
    ///
    /// Logic:
    /// 1. If events is empty: weekends (Sun=1, Sat=7) -> .freeDay, weekdays -> .unknown
    /// 2. Check all event titles against noSchoolKeywords. If any match -> .freeDay(reason:)
    /// 3. If events exist but none match -> .schoolDay
    func determineContext(events: [CalendarEvent], date: Date) -> DayContext {
        if events.isEmpty {
            let weekday = Calendar.current.component(.weekday, from: date)
            // Sunday = 1, Saturday = 7
            if weekday == 1 || weekday == 7 {
                return .freeDay(reason: nil)
            }
            return .unknown
        }

        for event in events {
            let lowercasedTitle = event.title.lowercased()
            for keyword in Self.noSchoolKeywords {
                if lowercasedTitle.contains(keyword) {
                    return .freeDay(reason: event.title)
                }
            }
        }

        return .schoolDay
    }

    /// Determines whether a routine with the given calendarMode should be shown
    /// in the given day context.
    ///
    /// Modes:
    /// - "always": show on all days
    /// - "schoolDayOnly": show on school days and unknown days (backward compatibility)
    /// - "freeDayOnly": show on free days and unknown days (backward compatibility)
    /// - default: show (treat unknown modes as "always")
    func shouldShow(calendarMode: String, in context: DayContext) -> Bool {
        switch calendarMode {
        case "always":
            return true
        case "schoolDayOnly":
            return context == .schoolDay || context == .unknown
        case "freeDayOnly":
            if case .freeDay = context { return true }
            return context == .unknown
        default:
            return true
        }
    }
}
