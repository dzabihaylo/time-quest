import Foundation
import SwiftData

@MainActor
@Observable
final class AppDependencies {
    let routineRepository: RoutineRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    let playerProfileRepository: PlayerProfileRepositoryProtocol
    let soundManager: SoundManager
    let notificationManager: NotificationManager
    let syncMonitor: CloudKitSyncMonitor

    init(modelContext: ModelContext) {
        self.routineRepository = SwiftDataRoutineRepository(modelContext: modelContext)
        self.sessionRepository = SwiftDataSessionRepository(modelContext: modelContext)
        self.playerProfileRepository = SwiftDataPlayerProfileRepository(modelContext: modelContext)
        self.soundManager = SoundManager()
        self.notificationManager = NotificationManager()
        self.syncMonitor = CloudKitSyncMonitor()
        syncMonitor.startMonitoring()
    }
}
