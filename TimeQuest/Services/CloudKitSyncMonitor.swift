import Foundation
import CloudKit
@preconcurrency import CoreData  // For NSPersistentCloudKitContainer.Event

@MainActor @Observable
final class CloudKitSyncMonitor {
    enum SyncStatus: Equatable {
        case notStarted
        case syncing
        case synced(Date)
        case error(String)
        case noAccount

        // Display text for settings UI
        var displayText: String {
            switch self {
            case .notStarted: return "Waiting..."
            case .syncing: return "Syncing..."
            case .synced(let date):
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Synced \(formatter.localizedString(for: date, relativeTo: Date.now))"
            case .error(let msg): return "Error: \(msg)"
            case .noAccount: return "iCloud not available"
            }
        }

        var systemImage: String {
            switch self {
            case .notStarted: return "icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            case .noAccount: return "icloud.slash"
            }
        }

        // Equatable conformance for cases with associated values
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted): return true
            case (.syncing, .syncing): return true
            case (.synced(let a), .synced(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            case (.noAccount, .noAccount): return true
            default: return false
            }
        }
    }

    var status: SyncStatus = .notStarted
    private nonisolated(unsafe) var observer: NSObjectProtocol?

    func startMonitoring() {
        // Listen for CloudKit sync events
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            // Extract event data on current (main) queue before crossing isolation boundary
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            let endDate = event.endDate
            let errorMessage = event.error?.localizedDescription

            Task { @MainActor in
                guard let self else { return }
                if endDate != nil {
                    if let errorMessage {
                        self.status = .error(errorMessage)
                    } else {
                        self.status = .synced(endDate ?? Date())
                    }
                } else {
                    self.status = .syncing
                }
            }
        }

        // Check iCloud account availability
        Task {
            do {
                let accountStatus = try await CKContainer.default().accountStatus()
                if accountStatus != .available {
                    self.status = .noAccount
                }
            } catch {
                self.status = .noAccount
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
