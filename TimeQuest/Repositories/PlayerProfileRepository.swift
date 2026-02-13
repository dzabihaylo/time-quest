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
        var descriptor = FetchDescriptor<PlayerProfile>()
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let profile = PlayerProfile()
        modelContext.insert(profile)
        return profile
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
