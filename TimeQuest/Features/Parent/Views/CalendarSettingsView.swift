import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var hasAccess: Bool = false
    @State private var selectedCalendarIDs: [String] = []
    @State private var selectedCalendarNames: [String] = []
    @State private var showingCalendarChooser = false

    var body: some View {
        Form {
            accessSection
            if hasAccess {
                schoolCalendarsSection
            }
            howItWorksSection
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasAccess = dependencies.calendarService.hasAccess
            selectedCalendarIDs = dependencies.calendarService.selectedCalendarIDs() ?? []
            selectedCalendarNames = UserDefaults.standard.stringArray(
                forKey: CalendarService.selectedCalendarNamesKey
            ) ?? []
        }
        .sheet(isPresented: $showingCalendarChooser, onDismiss: saveCalendarSelection) {
            CalendarChooserView(
                selectedCalendarIDs: $selectedCalendarIDs,
                eventStore: dependencies.calendarService.getEventStore()
            )
        }
    }

    // MARK: - Sections

    private var accessSection: some View {
        Section {
            if hasAccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Calendar access granted")
                }
            } else {
                Button("Enable Calendar Access") {
                    Task {
                        let granted = await dependencies.calendarService.requestAccess()
                        hasAccess = granted
                    }
                }
            }
        } header: {
            Text("Calendar Access")
        } footer: {
            Text("TimeQuest reads your calendar to detect school days and holidays. Calendar data is never stored.")
        }
    }

    private var schoolCalendarsSection: some View {
        Section {
            if !selectedCalendarNames.isEmpty {
                ForEach(selectedCalendarNames, id: \.self) { name in
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(name)
                    }
                }
            }

            Button("Select Calendars") {
                showingCalendarChooser = true
            }
        } header: {
            Text("School Calendars")
        } footer: {
            Text("Select the calendars that contain your school schedule. If none selected, all calendars are scanned.")
        }
    }

    private var howItWorksSection: some View {
        Section {
            Text("TimeQuest looks for events like \"No School\", \"Holiday\", or \"Break\" in your calendar. On those days, school-only routines are hidden automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } header: {
            Text("How It Works")
        }
    }

    // MARK: - Actions

    private func saveCalendarSelection() {
        // Resolve names from the event store for display
        let store = dependencies.calendarService.getEventStore()
        let names = selectedCalendarIDs.compactMap { id in
            store.calendar(withIdentifier: id)?.title
        }
        selectedCalendarNames = names

        if selectedCalendarIDs.isEmpty {
            dependencies.calendarService.clearSelectedCalendars()
        } else {
            dependencies.calendarService.saveSelectedCalendars(ids: selectedCalendarIDs, names: names)
        }
    }
}
