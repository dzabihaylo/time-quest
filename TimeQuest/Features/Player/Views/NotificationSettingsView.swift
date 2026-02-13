import SwiftUI

struct NotificationSettingsView: View {
    let playerProfileRepository: PlayerProfileRepositoryProtocol
    let notificationManager: NotificationManager
    let routines: [Routine]

    @State private var notificationsEnabled = true
    @State private var soundEnabled = true
    @State private var reminderTime = Date()
    @State private var authorizationDenied = false
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Quest Reminders", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        handleNotificationToggle(newValue)
                    }

                if authorizationDenied {
                    HStack {
                        Text("Notifications are disabled in Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                    }
                }

                if notificationsEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderTime) { _, _ in
                        saveReminderTime()
                    }
                }
            }

            Section("Sound") {
                Toggle("Sound Effects", isOn: $soundEnabled)
                    .onChange(of: soundEnabled) { _, newValue in
                        handleSoundToggle(newValue)
                    }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loadProfile()
            loaded = true
        }
    }

    private func loadProfile() {
        let profile = playerProfileRepository.fetchOrCreate()
        notificationsEnabled = profile.notificationsEnabled
        soundEnabled = profile.soundEnabled

        // Build reminder time from profile's hour/minute
        var components = DateComponents()
        components.hour = profile.notificationHour
        components.minute = profile.notificationMinute
        if let date = Calendar.current.date(from: components) {
            reminderTime = date
        }

        // Check current authorization
        Task {
            let status = await notificationManager.checkAuthorizationStatus()
            authorizationDenied = (status == .denied)
        }
    }

    private func handleNotificationToggle(_ enabled: Bool) {
        let profile = playerProfileRepository.fetchOrCreate()
        profile.notificationsEnabled = enabled
        try? playerProfileRepository.save()

        if enabled {
            Task {
                let granted = await notificationManager.requestAuthorization()
                if granted {
                    authorizationDenied = false
                    let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                    notificationManager.rescheduleAll(
                        routines: routines,
                        hour: components.hour ?? 7,
                        minute: components.minute ?? 30
                    )
                } else {
                    authorizationDenied = true
                    notificationsEnabled = false
                    profile.notificationsEnabled = false
                    try? playerProfileRepository.save()
                }
            }
        } else {
            notificationManager.cancelAllReminders()
        }
    }

    private func handleSoundToggle(_ enabled: Bool) {
        let profile = playerProfileRepository.fetchOrCreate()
        profile.soundEnabled = enabled
        try? playerProfileRepository.save()
    }

    private func saveReminderTime() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = components.hour ?? 7
        let minute = components.minute ?? 30

        let profile = playerProfileRepository.fetchOrCreate()
        profile.notificationHour = hour
        profile.notificationMinute = minute
        try? playerProfileRepository.save()

        if notificationsEnabled {
            notificationManager.rescheduleAll(
                routines: routines,
                hour: hour,
                minute: minute
            )
        }
    }
}
