@preconcurrency import EventKit

@MainActor
final class CalendarService {

    private let eventStore = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var hasAccess: Bool {
        authorizationStatus == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func fetchTodayEvents(from calendarIdentifiers: [String]? = nil) -> [CalendarEvent] {
        guard hasAccess else { return [] }

        let now = Date.now
        let startOfDay = Calendar.current.startOfDay(for: now)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        var calendars: [EKCalendar]?
        if let identifiers = calendarIdentifiers {
            calendars = identifiers.compactMap { eventStore.calendar(withIdentifier: $0) }
            if calendars?.isEmpty == true {
                calendars = nil
            }
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)

        return ekEvents.map { event in
            CalendarEvent(
                title: event.title ?? "",
                isAllDay: event.isAllDay,
                startDate: event.startDate,
                endDate: event.endDate,
                calendarTitle: event.calendar?.title ?? ""
            )
        }
    }

    func getEventStore() -> EKEventStore {
        eventStore
    }

    // MARK: - Calendar Selection Persistence (UserDefaults, device-local)

    static let selectedCalendarIDsKey = "selectedCalendarIDs"
    static let selectedCalendarNamesKey = "selectedCalendarNames"

    func selectedCalendarIDs() -> [String]? {
        UserDefaults.standard.stringArray(forKey: Self.selectedCalendarIDsKey)
    }

    func saveSelectedCalendars(ids: [String], names: [String]) {
        UserDefaults.standard.set(ids, forKey: Self.selectedCalendarIDsKey)
        UserDefaults.standard.set(names, forKey: Self.selectedCalendarNamesKey)
    }

    func clearSelectedCalendars() {
        UserDefaults.standard.removeObject(forKey: Self.selectedCalendarIDsKey)
        UserDefaults.standard.removeObject(forKey: Self.selectedCalendarNamesKey)
    }
}
