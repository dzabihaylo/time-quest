import SwiftUI
@preconcurrency import EventKitUI

/// UIViewControllerRepresentable wrapping EKCalendarChooser for selecting
/// which calendars to scan for school/holiday events.
struct CalendarChooserView: UIViewControllerRepresentable {
    @Binding var selectedCalendarIDs: [String]
    let eventStore: EKEventStore
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let chooser = EKCalendarChooser(
            selectionStyle: .multiple,
            displayStyle: .allCalendars,
            entityType: .event,
            eventStore: eventStore
        )
        chooser.showsDoneButton = true
        chooser.showsCancelButton = true
        chooser.delegate = context.coordinator

        // Pre-select calendars from existing selection
        var preselected = Set<EKCalendar>()
        for calendarID in selectedCalendarIDs {
            if let calendar = eventStore.calendar(withIdentifier: calendarID) {
                preselected.insert(calendar)
            }
        }
        chooser.selectedCalendars = preselected

        let nav = UINavigationController(rootViewController: chooser)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    final class Coordinator: NSObject, EKCalendarChooserDelegate {
        let parent: CalendarChooserView

        init(_ parent: CalendarChooserView) {
            self.parent = parent
        }

        nonisolated func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
            MainActor.assumeIsolated {
                parent.selectedCalendarIDs = calendarChooser.selectedCalendars.map { $0.calendarIdentifier }
                parent.dismiss()
            }
        }

        nonisolated func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser) {
            MainActor.assumeIsolated {
                parent.dismiss()
            }
        }
    }
}
