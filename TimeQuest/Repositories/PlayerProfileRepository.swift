import Foundation
import SwiftData

@MainActor
protocol PlayerProfileRepositoryProtocol {
    func fetchOrCreate() -> PlayerProfile
    func addXP(_ amount: Int, to profile: PlayerProfile)
    func updateStreak(for profile: PlayerProfile, on date: Date)
    func save() throws
}

@MainActor
final class SwiftDataPlayerProfileRepository: PlayerProfileRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchOrCreate() -> PlayerProfile {
        let descriptor = FetchDescriptor<PlayerProfile>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let allProfiles = (try? modelContext.fetch(descriptor)) ?? []

        if allProfiles.isEmpty {
            let profile = PlayerProfile()
            profile.cloudID = "singleton-player-profile"
            modelContext.insert(profile)
            return profile
        }

        // Deduplication: keep first, merge extras (handles CloudKit sync creating duplicates)
        let keeper = allProfiles[0]
        if keeper.cloudID != "singleton-player-profile" {
            keeper.cloudID = "singleton-player-profile"
        }
        for extra in allProfiles.dropFirst() {
            keeper.totalXP = max(keeper.totalXP, extra.totalXP)
            keeper.currentStreak = max(keeper.currentStreak, extra.currentStreak)
            if let extraDate = extra.lastPlayedDate,
               let keeperDate = keeper.lastPlayedDate,
               extraDate > keeperDate {
                keeper.lastPlayedDate = extraDate
            } else if extra.lastPlayedDate != nil && keeper.lastPlayedDate == nil {
                keeper.lastPlayedDate = extra.lastPlayedDate
            }
            modelContext.delete(extra)
        }
        try? modelContext.save()
        return keeper
    }

    func addXP(_ amount: Int, to profile: PlayerProfile) {
        profile.totalXP += amount
        try? modelContext.save()
    }

    func updateStreak(for profile: PlayerProfile, on date: Date) {
        let state = StreakTracker.updatedStreak(
            currentStreak: profile.currentStreak,
            lastPlayedDate: profile.lastPlayedDate,
            today: date
        )
        profile.currentStreak = state.currentStreak
        profile.lastPlayedDate = state.lastPlayedDate
        try? modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }
}
