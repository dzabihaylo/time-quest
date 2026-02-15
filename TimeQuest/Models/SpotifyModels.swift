import Foundation

// MARK: - Spotify Web API Response Types

struct PagingObject<T: Codable & Sendable>: Codable, Sendable {
    let items: [T]
    let next: String?
    let total: Int
}

struct SpotifyPlaylist: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let tracks: PlaylistTracksRef

    struct PlaylistTracksRef: Codable, Sendable {
        let total: Int
    }
}

struct SpotifyImage: Codable, Sendable {
    let url: String
    let height: Int?
    let width: Int?
}

struct PlaylistTrackItem: Codable, Sendable {
    let track: SpotifyTrack?
}

struct SpotifyTrack: Codable, Sendable {
    let name: String
    let durationMs: Int
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum?

    enum CodingKeys: String, CodingKey {
        case name
        case durationMs = "duration_ms"
        case artists
        case album
    }
}

struct SpotifyArtist: Codable, Sendable {
    let name: String
}

struct SpotifyAlbum: Codable, Sendable {
    let images: [SpotifyImage]
}

struct CurrentlyPlayingResponse: Codable, Sendable {
    let isPlaying: Bool
    let item: SpotifyTrack?
    let progressMs: Int?

    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
        case progressMs = "progress_ms"
    }

    func toNowPlayingInfo() -> NowPlayingInfo? {
        guard isPlaying, let track = item else { return nil }
        let artistName = track.artists.first?.name ?? "Unknown Artist"
        let albumArtURL = track.album?.images.first?.url
        return NowPlayingInfo(
            trackName: track.name,
            artistName: artistName,
            albumArtURL: albumArtURL,
            durationMs: track.durationMs,
            progressMs: progressMs ?? 0
        )
    }
}

struct NowPlayingInfo: Sendable {
    let trackName: String
    let artistName: String
    let albumArtURL: String?
    let durationMs: Int
    let progressMs: Int
}

struct SpotifyUserProfile: Codable, Sendable {
    let id: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

// MARK: - Spotify Errors

enum SpotifyError: Error, Sendable {
    case notConnected
    case authCancelled
    case tokenExpired
    case httpError(statusCode: Int)
    case invalidResponse
    case keychainError(OSStatus)
    case rateLimited
}
