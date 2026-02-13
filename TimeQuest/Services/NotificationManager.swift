import UserNotifications

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

    func scheduleRoutineReminder(routine: Routine, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Quest Available!"
        content.body = "Your \(routine.displayName) quest is ready to play"
        content.sound = .default

        for weekday in routine.activeDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            // Deterministic ID prevents duplicates (research pitfall 6)
            let identifier = "routine-\(routine.name)-day\(weekday)"

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelRoutineReminders(routineName: String, activeDays: [Int]) {
        let identifiers = activeDays.map { "routine-\(routineName)-day\($0)" }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func rescheduleAll(routines: [Routine], hour: Int, minute: Int) {
        cancelAllReminders()
        for routine in routines where routine.isActive {
            scheduleRoutineReminder(routine: routine, hour: hour, minute: minute)
        }
    }
}
