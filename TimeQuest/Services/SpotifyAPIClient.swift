import Foundation

@MainActor
final class SpotifyAPIClient {

    private let authManager: SpotifyAuthManager
    private let baseURL = "https://api.spotify.com/v1"

    init(authManager: SpotifyAuthManager) {
        self.authManager = authManager
    }

    // MARK: - Core Authenticated Request

    private func authenticatedRequest(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        var token = try await authManager.validAccessToken()
        var hasRetried401 = false
        var hasRetried429 = false

        while true {
            var components = URLComponents(string: baseURL + path)!
            if !queryItems.isEmpty {
                components.queryItems = queryItems
            }

            guard let url = components.url else {
                throw SpotifyError.invalidResponse
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SpotifyError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                return data
            case 204:
                return Data()
            case 401:
                guard !hasRetried401 else {
                    throw SpotifyError.tokenExpired
                }
                hasRetried401 = true
                token = try await authManager.validAccessToken()
                continue
            case 429:
                guard !hasRetried429 else {
                    throw SpotifyError.rateLimited
                }
                hasRetried429 = true
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) } ?? 5.0
                try await Task.sleep(for: .seconds(retryAfter))
                continue
            default:
                throw SpotifyError.httpError(statusCode: httpResponse.statusCode)
            }
        }
    }

    // MARK: - Public API Methods

    func getUserProfile() async throws -> SpotifyUserProfile {
        let data = try await authenticatedRequest(path: "/me")
        return try JSONDecoder().decode(SpotifyUserProfile.self, from: data)
    }

    func getUserPlaylists(limit: Int = 50, offset: Int = 0) async throws -> PagingObject<SpotifyPlaylist> {
        let data = try await authenticatedRequest(
            path: "/me/playlists",
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )
        return try JSONDecoder().decode(PagingObject<SpotifyPlaylist>.self, from: data)
    }

    func getPlaylistTracks(playlistID: String) async throws -> [SpotifyTrack] {
        var allTracks: [SpotifyTrack] = []
        var offset = 0
        let limit = 100
        let fields = "items(track(name,duration_ms,artists(name),album(images))),next,total"

        while true {
            let data = try await authenticatedRequest(
                path: "/playlists/\(playlistID)/tracks",
                queryItems: [
                    URLQueryItem(name: "limit", value: String(limit)),
                    URLQueryItem(name: "offset", value: String(offset)),
                    URLQueryItem(name: "fields", value: fields)
                ]
            )

            let page = try JSONDecoder().decode(PagingObject<PlaylistTrackItem>.self, from: data)
            let tracks = page.items.compactMap(\.track)
            allTracks.append(contentsOf: tracks)

            if page.next == nil {
                break
            }
            offset += limit
        }

        return allTracks
    }

    func getCurrentlyPlaying() async throws -> NowPlayingInfo? {
        let data = try await authenticatedRequest(path: "/me/player/currently-playing")

        // 204 returns empty data -- nothing playing
        guard !data.isEmpty else { return nil }

        let response = try JSONDecoder().decode(CurrentlyPlayingResponse.self, from: data)
        return response.toNowPlayingInfo()
    }
}
