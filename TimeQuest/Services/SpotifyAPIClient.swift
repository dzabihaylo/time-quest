import Foundation

// Placeholder -- implemented in Task 2
@MainActor
final class SpotifyAPIClient {
    private let authManager: SpotifyAuthManager

    init(authManager: SpotifyAuthManager) {
        self.authManager = authManager
    }
}
