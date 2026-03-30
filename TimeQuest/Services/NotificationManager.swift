@preconcurrency import UserNotifications
import Foundation

@MainActor
final class NotificationManager {

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Schedule a reminder for a specific routine on a specific date.
    /// Uses a non-repeating trigger so we can re-evaluate calendar context daily.
    func scheduleRoutineReminder(routine: Routine, on date: Date, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Quest Available!"
        content.body = "Your \(routine.displayName) quest is ready to play"
        content.sound = .default

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false  // Non-repeating — re-evaluated daily with calendar context
        )

        let dateString = Self.dateString(date)
        let identifier = "routine-\(routine.name)-\(dateString)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelRoutineReminders(routineName: String, activeDays: [Int]) {
        // Cancel both legacy weekly and new daily-format identifiers
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let toRemove = requests
                .filter { $0.identifier.hasPrefix("routine-\(routineName)-") }
                .map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Reschedule notifications for the next 7 days, respecting calendar context.
    /// Call this on app launch, after completing a quest, and when notification settings change.
    func rescheduleAll(
        routines: [Routine],
        hour: Int,
        minute: Int,
        calendarService: CalendarService? = nil,
        calendarEngine: CalendarContextEngine = CalendarContextEngine()
    ) {
        cancelAllReminders()

        let calendar = Calendar.current
        let today = Date.now

        // Schedule for the next 7 days
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: date)

            // Determine calendar context for this day
            let dayContext: DayContext
            if let calendarService, calendarService.hasAccess {
                // For today, use real events. For future days, use weekday heuristic.
                if dayOffset == 0 {
                    let calendarIDs = calendarService.selectedCalendarIDs()
                    let events = calendarService.fetchTodayEvents(from: calendarIDs)
                    dayContext = calendarEngine.determineContext(events: events, date: date)
                } else {
                    // Future days: weekends are free, weekdays are school (best guess)
                    // Real calendar events for future days would require a fetchEvents(for: date)
                    // which CalendarService doesn't expose yet — weekday heuristic is the safe default
                    if weekday == 1 || weekday == 7 {
                        dayContext = .freeDay(reason: nil)
                    } else {
                        dayContext = .schoolDay
                    }
                }
            } else {
                dayContext = .unknown  // No calendar access — show everything
            }

            for routine in routines where routine.isActive {
                // Check if this routine is scheduled for this weekday
                guard routine.activeDays.contains(weekday) else { continue }

                // Check if calendar context allows this routine
                guard calendarEngine.shouldShow(calendarMode: routine.calendarModeRaw, in: dayContext) else { continue }

                scheduleRoutineReminder(routine: routine, on: date, hour: hour, minute: minute)
            }
        }
    }

    // MARK: - Helpers

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
