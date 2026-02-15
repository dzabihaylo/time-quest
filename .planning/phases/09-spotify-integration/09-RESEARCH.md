# Phase 9: Spotify Integration - Research

**Researched:** 2026-02-15
**Domain:** Spotify Web API / OAuth PKCE / Deep Links / SwiftData schema migration
**Confidence:** MEDIUM-HIGH

## Summary

Phase 9 adds Spotify awareness to TimeQuest so routines can be paired with playlists, providing an intuitive "song-based" time sense. The locked decision is **Web API + PKCE only** -- no Spotify iOS SDK for playback control, no audio session conflicts with SoundManager. This means: OAuth via Spotify's `ios-auth` library or hand-rolled ASWebAuthenticationSession, data fetching via REST (playlists, tracks, currently-playing), playback launch via deep links (`spotify:playlist:ID` URIs or `open.spotify.com` Universal Links), and a "Now Playing" indicator that polls the `/me/player/currently-playing` endpoint.

**Critical February 2026 development:** Spotify changed its Developer Mode API requirements. New apps (created after Feb 11, 2026) are limited to 5 authenticated users and require the app owner to have Premium. Existing apps are migrated to these restrictions by March 9, 2026. For production use, Extended Quota Mode requires 250K+ MAUs, a registered business entity, and a 6-week review process. **This means TimeQuest will operate under Development Mode constraints during initial development (5-user limit).** This is acceptable for building and testing but requires an Extended Quota application before any public release.

The architecture follows the established codebase pattern: a pure domain engine (`SpotifyPlaylistMatcher`) for duration-matching logic, a service layer (`SpotifyService`) for API calls and token management, and lightweight schema additions (SchemaV6) for storing playlist associations on Routines. The "completely optional" requirement (SPOT-06) means the entire Spotify feature is an additive overlay -- the app must work identically without it, matching the Phase 8 calendar intelligence pattern.

**Primary recommendation:** Build a `SpotifyService` (OAuth + API client) using either Spotify's `ios-auth` SPM package or hand-rolled ASWebAuthenticationSession + PKCE, a `SpotifyPlaylistMatcher` pure engine for duration matching, and wire playlist associations into SchemaV6 on Routine. Launch playback via `open.spotify.com` Universal Links (preferred over `spotify:` deep links to avoid iOS confirmation prompts). Poll `/me/player/currently-playing` at 5-10 second intervals for the "Now Playing" indicator.

## User Constraints (from phase description)

### Locked Decisions
- **Spotify via Web API + PKCE** (no iOS SDK playback control) to avoid audio session conflicts with SoundManager
- **SchemaV4 lightweight migration only** -- all new fields have defaults (now on V5, will create V6)
- **UI refresh last** (Phase 10) so all new views from Phases 7-9 get themed in one pass

### Key Constraint Implications
- No `SPTAppRemote` or `SPTSessionManager` from the Spotify iOS SDK
- No client secret stored on device (PKCE eliminates this)
- Playback control via deep links only -- cannot programmatically play/pause/skip
- "Now Playing" reads from Web API polling, not from iOS SDK callbacks

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Spotify Web API | v1 | Playlists, tracks, currently-playing, user profile | Only API for Spotify data; locked decision |
| AuthenticationServices | System (iOS 17+) | ASWebAuthenticationSession for OAuth PKCE flow | Apple's standard for in-app OAuth; no third-party needed |
| Security (Keychain) | System | Secure storage of OAuth tokens | Apple's standard for credential storage |
| SwiftData | System (iOS 17+) | SchemaV6 for Spotify fields on Routine | Existing migration pattern |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| spotify/ios-auth | 3.0.1 (SPM) | PKCE OAuth flow with Spotify app fallback | OPTIONAL: simplifies auth but adds SPM dependency; hand-rolled ASWebAuthenticationSession is viable alternative |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| spotify/ios-auth (SPM) | Hand-rolled ASWebAuthenticationSession + PKCE | ios-auth handles Spotify app detection/fallback automatically; hand-rolled gives full control, no binary xcframework, guaranteed Swift 6 compatibility |
| Keychain (raw Security framework) | KeychainAccess SPM package | Raw Keychain API is verbose but avoids another dependency; the token storage is simple enough for raw API |
| URLSession (direct) | Alamofire or similar | URLSession is sufficient for simple REST calls; no need for a networking library |

### Recommendation: Hand-Roll the OAuth + API Client

**Do NOT use spotify/ios-auth for this project.** Reasons:
1. It ships as a binary xcframework -- Swift 6 strict concurrency compatibility is unverified
2. Adding SPM to the generate-xcodeproj.js is a significant build system change (see Blockers section)
3. The PKCE flow is straightforward to implement with ASWebAuthenticationSession (~100 lines)
4. The app only needs a handful of API endpoints -- a thin SpotifyService is cleaner than a framework dependency

**Installation:** No packages needed. All implementation uses system frameworks (AuthenticationServices, Security, Foundation).

## Architecture Patterns

### Recommended Project Structure
```
TimeQuest/
├── Domain/
│   └── SpotifyPlaylistMatcher.swift    # Pure: matches playlist duration to routine
├── Services/
│   ├── SpotifyAuthManager.swift        # OAuth PKCE flow + token storage/refresh
│   └── SpotifyAPIClient.swift          # REST client for Web API endpoints
├── Features/
│   ├── Parent/
│   │   ├── Views/
│   │   │   ├── SpotifySettingsView.swift     # Connect/disconnect Spotify
│   │   │   └── PlaylistPickerView.swift      # Browse & select playlist for routine
│   │   └── ViewModels/
│   │       └── RoutineEditorViewModel.swift  # Extended: playlist association
│   └── Player/
│       ├── Views/
│       │   ├── NowPlayingIndicator.swift     # Minimal "Now Playing" overlay
│       │   └── SessionSummaryView.swift      # Extended: song count display
│       └── ViewModels/
│           └── GameSessionViewModel.swift    # Extended: Spotify playback launch + polling
├── Models/
│   ├── Schemas/
│   │   └── TimeQuestSchemaV6.swift           # Adds Spotify fields to Routine
│   ├── Migration/
│   │   └── TimeQuestMigrationPlan.swift      # V5 -> V6 lightweight
│   └── SpotifyModels.swift                   # Codable structs for API responses
└── App/
    └── AppDependencies.swift                 # Registers SpotifyAuthManager
```

### Pattern 1: SpotifyAuthManager (OAuth PKCE Service)
**What:** `@MainActor` service that manages the complete PKCE flow: authorization URL construction, ASWebAuthenticationSession presentation, token exchange, secure Keychain storage, and automatic token refresh.
**When to use:** Any time the app needs to authenticate with Spotify or make authenticated API calls.
**Why:** Isolates all OAuth complexity to one place. Matches the CalendarService and NotificationManager patterns.
**Example:**
```swift
// Services/SpotifyAuthManager.swift
import AuthenticationServices
import CryptoKit

@MainActor
@Observable
final class SpotifyAuthManager: NSObject {
    var isConnected: Bool = false
    var userDisplayName: String?

    private let clientID = "YOUR_CLIENT_ID"  // From Spotify Dashboard
    private let redirectURI = "https://your-domain.com/callback"  // HTTPS required
    private var codeVerifier: String?

    // MARK: - PKCE Flow

    func authorize() async throws {
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: requiredScopes),
        ]

        let authURL = components.url!
        let callbackURL = try await presentAuthSession(url: authURL)
        let code = extractCode(from: callbackURL)
        let tokens = try await exchangeCodeForTokens(code: code, verifier: verifier)
        try saveTokens(tokens)
        isConnected = true
    }

    private var requiredScopes: String {
        [
            "playlist-read-private",
            "playlist-read-collaborative",
            "user-read-currently-playing",
            "user-read-playback-state",
        ].joined(separator: " ")
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .prefix(128)
            .description
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

### Pattern 2: SpotifyAPIClient (REST Wrapper)
**What:** Thin wrapper around URLSession that handles authenticated Spotify Web API requests with automatic token refresh.
**When to use:** All Spotify data fetching (playlists, tracks, currently-playing).
**Example:**
```swift
// Services/SpotifyAPIClient.swift
@MainActor
final class SpotifyAPIClient {
    private let authManager: SpotifyAuthManager
    private let baseURL = "https://api.spotify.com/v1"

    init(authManager: SpotifyAuthManager) {
        self.authManager = authManager
    }

    func getCurrentlyPlaying() async throws -> NowPlayingInfo? {
        let data = try await authenticatedRequest(path: "/me/player/currently-playing")
        guard !data.isEmpty else { return nil }  // 204 = nothing playing
        return try JSONDecoder().decode(CurrentlyPlayingResponse.self, from: data).toNowPlayingInfo()
    }

    func getUserPlaylists(limit: Int = 50) async throws -> [SpotifyPlaylist] {
        let data = try await authenticatedRequest(
            path: "/me/playlists",
            queryItems: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
        return try JSONDecoder().decode(PagingObject<SpotifyPlaylist>.self, from: data).items
    }

    func getPlaylistTracks(playlistID: String) async throws -> [SpotifyTrack] {
        // Handle pagination for playlists > 100 tracks
        var allTracks: [SpotifyTrack] = []
        var offset = 0
        let limit = 100
        var hasMore = true

        while hasMore {
            let data = try await authenticatedRequest(
                path: "/playlists/\(playlistID)/tracks",
                queryItems: [
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)"),
                    URLQueryItem(name: "fields", value: "items(track(name,duration_ms,artists(name),album(images))),next"),
                ]
            )
            let page = try JSONDecoder().decode(PagingObject<PlaylistTrackItem>.self, from: data)
            allTracks.append(contentsOf: page.items.compactMap(\.track))
            hasMore = page.next != nil
            offset += limit
        }
        return allTracks
    }

    private func authenticatedRequest(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        let token = try await authManager.validAccessToken()
        var components = URLComponents(string: baseURL + path)!
        if !queryItems.isEmpty { components.queryItems = queryItems }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200: return data
        case 204: return Data()  // No content (nothing playing)
        case 401:
            // Token expired mid-request -- refresh and retry once
            try await authManager.refreshToken()
            return try await authenticatedRequest(path: path, queryItems: queryItems)
        case 429:
            // Rate limited -- respect Retry-After header
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Double.init) ?? 5.0
            try await Task.sleep(for: .seconds(retryAfter))
            return try await authenticatedRequest(path: path, queryItems: queryItems)
        default:
            throw SpotifyError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}
```

### Pattern 3: SpotifyPlaylistMatcher (Pure Domain Engine)
**What:** Pure struct that takes a routine's total estimated duration and a list of track durations, returns a subset of tracks that fills the time window. No Spotify API dependency.
**When to use:** When starting a routine that has a linked playlist.
**Why:** Testable without network. Can unit test with fabricated track data.
**Example:**
```swift
// Domain/SpotifyPlaylistMatcher.swift
struct PlaylistMatchResult: Sendable {
    let trackCount: Int
    let totalDurationSeconds: Double
    let songCountLabel: String  // "4.5 songs"
    let deepLinkURI: String     // For opening in Spotify
}

struct SpotifyPlaylistMatcher: Sendable {
    /// Given track durations and a target routine duration, calculate how many
    /// songs fit and produce a human-readable "song count" label.
    func matchDuration(
        trackDurationsMs: [Int],
        targetDurationSeconds: Double
    ) -> PlaylistMatchResult {
        let targetMs = targetDurationSeconds * 1000
        var accumulatedMs: Double = 0
        var trackCount = 0

        for durationMs in trackDurationsMs {
            accumulatedMs += Double(durationMs)
            trackCount += 1
            if accumulatedMs >= targetMs { break }
        }

        // Calculate fractional song count for the label
        let totalDurationMs = trackDurationsMs.prefix(trackCount).reduce(0, +)
        let avgTrackMs = totalDurationMs > 0
            ? Double(totalDurationMs) / Double(trackCount)
            : 0
        let fractionalCount = avgTrackMs > 0
            ? targetMs / avgTrackMs
            : 0

        let label = formatSongCount(fractionalCount)

        return PlaylistMatchResult(
            trackCount: trackCount,
            totalDurationSeconds: Double(totalDurationMs) / 1000.0,
            songCountLabel: label,
            deepLinkURI: ""  // Caller sets this from playlist URI
        )
    }

    /// Format "4.5 songs" or "1 song" with appropriate rounding
    func formatSongCount(_ count: Double) -> String {
        if count < 0.5 { return "less than 1 song" }
        let rounded = (count * 2).rounded() / 2  // Round to nearest 0.5
        if rounded == 1.0 { return "1 song" }
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) songs"
        }
        return String(format: "%.1f songs", rounded)
    }
}
```

### Pattern 4: Graceful Degradation (SPOT-06 / SPOT-07)
**What:** Spotify is purely additive. The app works identically without it.
**When to use:** Every touchpoint. No nagging, no forced login, no Premium-gating.
**Why:** SPOT-06 requires zero degradation without Spotify. SPOT-07 requires Free tier support.
**Example:**
```swift
// In QuestView -- only show Now Playing if Spotify is connected AND playing
if let nowPlaying = viewModel.nowPlayingInfo {
    NowPlayingIndicator(info: nowPlaying)
}
// No "else" branch -- no "Connect Spotify" nag, no empty state

// In SessionSummaryView -- only show song count if available
if let songCount = viewModel.songCountLabel {
    HStack(spacing: 4) {
        Image(systemName: "music.note")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("You got through \(songCount)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
// Falls through silently if no Spotify data

// Free tier handling -- read-only endpoints work, playback control doesn't
// Our approach (deep links) works for BOTH tiers:
// - Free users: Spotify opens with ads, shuffle-only on mobile
// - Premium users: Spotify opens with full playback
// Both get the "Now Playing" indicator (read-only endpoint)
```

### Anti-Patterns to Avoid
- **Storing access/refresh tokens in UserDefaults:** Use Keychain. Tokens are credentials.
- **Embedding client_secret in the app:** PKCE eliminates this. Never ship a secret in a mobile app.
- **Polling currently-playing every second:** Wastes API quota. Poll every 5-10 seconds, and use `progress_ms` + `duration_ms` to predict track changes.
- **Showing Spotify UI to users who haven't connected:** Spotify is invisible until the parent opts in. No "Connect Spotify" prompts in the player flow.
- **Requiring Premium for any feature:** Deep links work for both tiers. Read-only API endpoints work for both tiers. Never gate functionality on Premium.
- **Using spotify: URI deep links instead of Universal Links:** `spotify:` URIs trigger an iOS confirmation dialog. `open.spotify.com` URLs use Universal Links (no dialog if Spotify is installed) and fall back to the browser if not installed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PKCE code verifier/challenge | Custom crypto | `CryptoKit.SHA256` + `SecRandomCopyBytes` | Crypto is easy to get wrong; CryptoKit is battle-tested |
| Token secure storage | File-based or UserDefaults storage | Keychain Services (Security framework) | Tokens are credentials; Keychain is encrypted and hardware-backed |
| JSON response parsing | Manual JSONSerialization | `Codable` structs with `JSONDecoder` | Type safety, less error-prone, Swift-native |
| HTTP retry/backoff | Manual timer logic | URLSession + Retry-After header parsing | Spotify returns Retry-After; respect it directly |
| Playlist duration math | Rough estimates | Sum of `duration_ms` from track list | Exact data is available; no reason to estimate |

**Key insight:** The Spotify Web API is well-documented REST. The complexity is NOT in the API calls (which are simple GET requests) but in: (1) the OAuth PKCE flow lifecycle (auth, refresh, revoke, re-auth), (2) graceful degradation across all UI touchpoints, and (3) rate limit management for the polling "Now Playing" indicator.

## Common Pitfalls

### Pitfall 1: Token Refresh Race Condition
**What goes wrong:** Multiple concurrent API calls all detect an expired token and simultaneously try to refresh, causing the first refresh to invalidate the second's refresh token.
**Why it happens:** Access tokens expire after 1 hour. Multiple views polling simultaneously can all hit 401 at the same time.
**How to avoid:** Use an async lock pattern -- a single `refreshTask` property. If a refresh is already in-flight, await the existing task instead of starting a new one.
**Warning signs:** Intermittent 401 errors even after token refresh; users randomly logged out.

### Pitfall 2: Redirect URI Mismatch
**What goes wrong:** OAuth fails with "INVALID_CLIENT: Invalid redirect URI" during authorization.
**Why it happens:** The redirect URI in the authorization request doesn't exactly match what's registered in the Spotify Developer Dashboard. Case, trailing slash, scheme -- all must match.
**How to avoid:** Define the redirect URI as a single constant. Copy-paste it to the Dashboard exactly. Test with a fresh install.
**Warning signs:** Auth flow opens browser but callback never fires.

### Pitfall 3: Polling Currently-Playing Burns API Quota
**What goes wrong:** Rate limit (429) errors during active quests because the app polls too aggressively.
**Why it happens:** Naive 1-second polling interval during a 15-minute routine = 900 calls. Spotify's rolling 30-second window rate limit kicks in.
**How to avoid:** Poll every 10 seconds. When a track is playing, use `progress_ms` and `duration_ms` to estimate when the current track will end, and only poll again near that time. Stop polling when `is_playing` is false.
**Warning signs:** 429 responses; "Now Playing" indicator stops updating.

### Pitfall 4: Free Tier Mobile Shuffle-Only
**What goes wrong:** Planning to deep-link to a specific track offset within a playlist. Free tier on mobile enforces shuffle mode -- you can't start at a specific track.
**Why it happens:** Spotify Free on mobile doesn't support on-demand playback of specific tracks within playlists.
**How to avoid:** Design the deep link to open the PLAYLIST, not a specific track. Accept that Free users will hear shuffled tracks. The "song count" feature still works because we poll currently-playing regardless of play order.
**Warning signs:** Test only with Premium accounts; discover on release that Free users get a different experience.

### Pitfall 5: Keychain Persists After App Uninstall
**What goes wrong:** User uninstalls and reinstalls the app. Spotify appears "connected" because old tokens are in Keychain, but they may be expired or revoked.
**Why it happens:** iOS Keychain items survive app deletion.
**How to avoid:** On first launch (track via UserDefaults flag), clear Spotify Keychain items. When loading tokens, always validate by calling a simple API endpoint before trusting stored tokens.
**Warning signs:** "Connected" state shown but all API calls fail with 401.

### Pitfall 6: LSApplicationQueriesSchemes Missing
**What goes wrong:** `UIApplication.shared.canOpenURL(URL(string: "spotify:")!)` always returns `false` even when Spotify is installed.
**Why it happens:** iOS requires declaring URL schemes you want to query in Info.plist under `LSApplicationQueriesSchemes`.
**How to avoid:** Add `spotify` to `LSApplicationQueriesSchemes` in `generate-xcodeproj.js`. But note: prefer Universal Links (`open.spotify.com`) which don't need this declaration.
**Warning signs:** Deep link detection always reports "Spotify not installed."

### Pitfall 7: ASWebAuthenticationSession Ephemeral Session
**What goes wrong:** User has to log in to Spotify every time they re-authorize because the session doesn't share cookies with Safari.
**Why it happens:** `ASWebAuthenticationSession` with `prefersEphemeralWebBrowserSession = true` doesn't use existing Safari cookies.
**How to avoid:** Set `prefersEphemeralWebBrowserSession = false` so the auth session can use existing Spotify login from Safari. This is the better UX for a family app -- the parent is likely already logged into Spotify in Safari.
**Warning signs:** User prompted to enter Spotify credentials every authorization attempt.

### Pitfall 8: February 2026 Dev Mode 5-User Limit
**What goes wrong:** More than 5 family members try to use Spotify features and get 403 errors.
**Why it happens:** New Development Mode apps (after Feb 11, 2026) are limited to 5 authenticated users. Users not on the allowlist get 403.
**How to avoid:** During development, add test users to the Spotify Dashboard allowlist. Before any public release, apply for Extended Quota Mode (requires 250K+ MAUs, registered business, 6-week review). For initial testing/beta, the 5-user limit is sufficient.
**Warning signs:** 403 errors for users who aren't on the Dashboard allowlist.

## Code Examples

Verified patterns from official sources:

### OAuth PKCE Token Exchange
```swift
// Source: https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow
func exchangeCodeForTokens(code: String, verifier: String) async throws -> SpotifyTokens {
    var components = URLComponents(string: "https://accounts.spotify.com/api/token")!

    let body = [
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirectURI,
        "client_id": clientID,
        "code_verifier": verifier,
    ]

    var request = URLRequest(url: components.url!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = body.map { "\($0.key)=\($0.value)" }
        .joined(separator: "&")
        .data(using: .utf8)

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(SpotifyTokens.self, from: data)
}

struct SpotifyTokens: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int          // 3600 (1 hour)
    let refreshToken: String?
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}
```

### Token Refresh (PKCE -- no client_secret needed)
```swift
// Source: https://developer.spotify.com/documentation/web-api/tutorials/refreshing-tokens
func refreshAccessToken(refreshToken: String) async throws -> SpotifyTokens {
    let body = [
        "grant_type": "refresh_token",
        "refresh_token": refreshToken,
        "client_id": clientID,
    ]

    var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = body.map { "\($0.key)=\($0.value)" }
        .joined(separator: "&")
        .data(using: .utf8)

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(SpotifyTokens.self, from: data)
}
```

### ASWebAuthenticationSession Presentation
```swift
// Source: Apple AuthenticationServices documentation
import AuthenticationServices

func presentAuthSession(url: URL) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "timequest"  // Custom scheme for callback
        ) { callbackURL, error in
            if let error {
                continuation.resume(throwing: error)
            } else if let callbackURL {
                continuation.resume(returning: callbackURL)
            } else {
                continuation.resume(throwing: SpotifyError.authCancelled)
            }
        }
        session.presentationContextProvider = self  // self conforms to ASWebPresentationContextProviding
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
}

// ASWebPresentationContextProviding conformance
extension SpotifyAuthManager: ASWebPresentationContextProviding {
    nonisolated func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        // MainActor-safe way to get the key window
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
```

### Opening Spotify via Universal Link (Preferred)
```swift
// Source: https://developer.spotify.com/documentation/ios/tutorials/content-linking
func openPlaylistInSpotify(playlistID: String) {
    // Prefer Universal Links (no confirmation dialog, graceful browser fallback)
    let universalURL = URL(string: "https://open.spotify.com/playlist/\(playlistID)")!

    // UIApplication.open handles Universal Links -> Spotify app if installed,
    // or Safari if not
    UIApplication.shared.open(universalURL)
}

// Alternative: spotify: URI (triggers iOS confirmation dialog)
func openPlaylistViaDeepLink(playlistURI: String) {
    // URI format: spotify:playlist:37i9dQZF1DXcBWIGoYBM5M
    if let url = URL(string: playlistURI),
       UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
    }
}
```

### Keychain Token Storage
```swift
// Source: Apple Security framework documentation
struct KeychainHelper {
    private static let service = "com.timequest.spotify"

    static func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SpotifyError.keychainError(status)
        }
    }

    static func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### Codable Models for Spotify API Responses
```swift
// Models/SpotifyModels.swift

struct PagingObject<T: Codable>: Codable {
    let items: [T]
    let next: String?
    let total: Int
}

struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let tracks: PlaylistTracksRef

    struct PlaylistTracksRef: Codable {
        let total: Int
    }
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

struct PlaylistTrackItem: Codable {
    let track: SpotifyTrack?
}

struct SpotifyTrack: Codable {
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

struct SpotifyArtist: Codable {
    let name: String
}

struct SpotifyAlbum: Codable {
    let images: [SpotifyImage]
}

struct CurrentlyPlayingResponse: Codable {
    let isPlaying: Bool
    let item: SpotifyTrack?
    let progressMs: Int?

    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
        case progressMs = "progress_ms"
    }

    func toNowPlayingInfo() -> NowPlayingInfo? {
        guard let item, isPlaying else { return nil }
        return NowPlayingInfo(
            trackName: item.name,
            artistName: item.artists.first?.name ?? "",
            albumArtURL: item.album?.images.first?.url,
            durationMs: item.durationMs,
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
```

### SchemaV6 Migration
```swift
// Models/Schemas/TimeQuestSchemaV6.swift
// Add to Routine model:
var spotifyPlaylistID: String?       // nil = no playlist linked
var spotifyPlaylistName: String?     // Cached for display without API call
var spotifyPlaylistImageURL: String? // Cached album art URL

// All fields are optional with nil defaults -> lightweight migration

// Models/Migration/TimeQuestMigrationPlan.swift
// Add V5 -> V6 stage:
static let v5ToV6 = MigrationStage.lightweight(
    fromVersion: TimeQuestSchemaV5.self,
    toVersion: TimeQuestSchemaV6.self
)
```

## Spotify API Scopes Reference

| Scope | Purpose | Premium Required |
|-------|---------|-----------------|
| `playlist-read-private` | Read user's private playlists | No |
| `playlist-read-collaborative` | Read collaborative playlists | No |
| `user-read-currently-playing` | Read currently playing track | No (read-only) |
| `user-read-playback-state` | Read playback state (device, shuffle, etc.) | No (read-only) |
| `user-modify-playback-state` | Control playback (play, pause, skip) | **Yes -- DO NOT USE** |
| `streaming` | Stream audio via Web Playback SDK | **Yes -- DO NOT USE** |

**We only need the first four scopes.** No Premium-requiring scopes are needed because we use deep links for playback control.

## Spotify API Endpoints Used

| Endpoint | Method | Purpose | Free Tier | Rate Limit |
|----------|--------|---------|-----------|------------|
| `/me/playlists` | GET | List user's playlists | Works | Standard |
| `/playlists/{id}/tracks` | GET | Get track list with durations | Works | Standard |
| `/me/player/currently-playing` | GET | Poll current track info | Works (read-only) | Standard |
| `/me` | GET | Verify connection / get display name | Works | Standard |

**Endpoints we DO NOT use:**
- `PUT /me/player/play` -- requires Premium
- `PUT /me/player/pause` -- requires Premium
- Any write/control endpoint

## Redirect URI Strategy

### CRITICAL: HTTPS Required for New Apps

As of April 9, 2025, new Spotify apps must use HTTPS redirect URIs (custom schemes are still supported but have reported issues with newly created apps). Two viable approaches:

**Option A: Custom URL Scheme with ASWebAuthenticationSession**
- Register `timequest://spotify-callback` in Dashboard
- Use `ASWebAuthenticationSession(callbackURLScheme: "timequest")`
- Simpler to implement, no server needed
- Custom schemes officially still supported, but some developers report INVALID_CLIENT errors for new apps

**Option B: HTTPS Universal Link (Recommended)**
- Register `https://your-domain.com/spotify-callback` in Dashboard
- Requires hosting a static `.well-known/apple-app-site-association` file
- More reliable with Spotify's new security requirements
- Better UX (no iOS confirmation dialog)

**Recommendation:** Start with Option A (custom scheme). It's simpler and officially supported. If INVALID_CLIENT errors occur, fall back to Option B. The `ASWebAuthenticationSession` callback URL scheme approach is secure because the OS guarantees only your app receives the callback.

## Build System Changes Required

### generate-xcodeproj.js Updates Needed

1. **Info.plist keys** (add to both Debug and Release build settings):
```javascript
// LSApplicationQueriesSchemes for detecting Spotify app
// Note: This may need to be an Info.plist file entry rather than a build setting
// because it's an array value. Verify during implementation.
```

2. **No SPM changes needed** (since we hand-roll OAuth + API client):
The recommendation to avoid spotify/ios-auth means NO Swift Package Manager integration is needed. All code uses system frameworks (AuthenticationServices, Security, CryptoKit, Foundation).

3. **New source files to register:**
```javascript
// Add to sourceFiles array:
{ name: 'SpotifyAuthManager.swift', path: 'Services/SpotifyAuthManager.swift' },
{ name: 'SpotifyAPIClient.swift', path: 'Services/SpotifyAPIClient.swift' },
{ name: 'SpotifyPlaylistMatcher.swift', path: 'Domain/SpotifyPlaylistMatcher.swift' },
{ name: 'SpotifyModels.swift', path: 'Models/SpotifyModels.swift' },
{ name: 'SpotifySettingsView.swift', path: 'Features/Parent/Views/SpotifySettingsView.swift' },
{ name: 'PlaylistPickerView.swift', path: 'Features/Parent/Views/PlaylistPickerView.swift' },
{ name: 'NowPlayingIndicator.swift', path: 'Features/Shared/Components/NowPlayingIndicator.swift' },
{ name: 'TimeQuestSchemaV6.swift', path: 'Models/Schemas/TimeQuestSchemaV6.swift' },
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Implicit Grant flow | Authorization Code + PKCE | Nov 2025 (enforced) | Implicit grant completely removed |
| HTTP redirect URIs | HTTPS or custom scheme redirect URIs | Nov 2025 (enforced) | HTTP no longer accepted (except loopback) |
| localhost redirect | Loopback IP (127.0.0.1) | Nov 2025 (enforced) | "localhost" alias removed |
| Unlimited dev users | 5-user Development Mode limit | Feb 2026 | New apps limited; existing apps migrated by Mar 2026 |
| No Premium req for dev | App owner needs Premium | Feb 2026 | Development Mode requires owner Premium account |
| Open API access | Extended Quota Mode gated | Feb 2026 | Production apps need 250K MAUs + business entity |
| `audio-features` endpoint | Removed for Dev Mode | Feb 2026 | Cannot get tempo/energy data in Dev Mode |

**Deprecated/outdated:**
- Implicit Grant flow: completely removed Nov 2025
- HTTP redirect URIs: removed Nov 2025 (except loopback)
- `GET /browse/new-releases`, `GET /browse/categories`: removed for Dev Mode apps Feb 2026
- `popularity`, `available_markets`, `followers` fields: no longer returned in Dev Mode

## Open Questions

1. **Redirect URI: Custom scheme vs HTTPS?**
   - What we know: Custom schemes are officially supported but developers report issues with newly created apps. HTTPS requires hosting a domain.
   - What's unclear: Whether a newly registered app with custom scheme will work reliably.
   - Recommendation: Try custom scheme first (`timequest://spotify-callback`). If Spotify rejects it, switch to HTTPS. ASWebAuthenticationSession works with both.

2. **Free tier currently-playing behavior**
   - What we know: READ endpoints (no Premium scope) should work for Free users. WRITE/CONTROL endpoints definitely require Premium.
   - What's unclear: No definitive documentation confirms `/me/player/currently-playing` returns data for Free mobile users (Free mobile has limited playback control).
   - Recommendation: Test with a Free account during development. If the endpoint returns empty/204 for Free users, the NowPlaying indicator simply won't show -- acceptable graceful degradation per SPOT-06.

3. **How should Spotify connection surface in the parent dashboard?**
   - What we know: ParentDashboardView has a toolbar with a Calendar button. Spotify settings need a home.
   - What's unclear: Separate settings screen vs integrated into existing settings.
   - Recommendation: Add a "Spotify" button next to the Calendar button in the ParentDashboardView bottom toolbar. Opens SpotifySettingsView (connect/disconnect).

4. **Playlist picker UX: how does the parent browse and select?**
   - What we know: `GET /me/playlists` returns paginated playlist list with names and images.
   - What's unclear: Should it show all playlists at once, or search, or both?
   - Recommendation: Simple list with playlist name, image thumbnail, and track count. No search for V1. Pagination handles large libraries. Parent taps to select.

5. **When does the app open Spotify -- at routine start or per-task?**
   - What we know: Success criterion says "when player starts a routine." Tasks are sequential.
   - What's unclear: Whether to open Spotify once at routine start or at each task transition.
   - Recommendation: Open Spotify ONCE at routine start (when first task estimation begins). Don't switch back to Spotify between tasks -- it would disrupt the quest flow.

6. **Token expiration during a quest**
   - What we know: Access tokens expire after 1 hour. A routine could theoretically last longer.
   - What's unclear: Nothing -- just need to handle it.
   - Recommendation: The SpotifyAPIClient already handles 401 -> refresh -> retry. The NowPlaying polling will automatically recover when the token is refreshed.

7. **Extended Quota Mode timeline for production**
   - What we know: Requires 250K+ MAUs, registered business, 6-week review.
   - What's unclear: Whether the app can launch on the App Store under Development Mode (5-user limit).
   - Recommendation: This is a business concern, not a technical one. Build the feature under Dev Mode. Apply for Extended Quota before any public release. The 5-user limit doesn't affect code architecture.

## Sources

### Primary (HIGH confidence)
- [Spotify Authorization Code with PKCE Flow](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow) - PKCE implementation details
- [Spotify Web API Scopes](https://developer.spotify.com/documentation/web-api/concepts/scopes) - Scope requirements and Premium restrictions
- [Spotify Refreshing Tokens](https://developer.spotify.com/documentation/web-api/tutorials/refreshing-tokens) - Token refresh for PKCE
- [Spotify iOS Content Linking](https://developer.spotify.com/documentation/ios/tutorials/content-linking) - Deep link formats, Universal Links
- [Spotify Rate Limits](https://developer.spotify.com/documentation/web-api/concepts/rate-limits) - Rolling 30s window, Retry-After header
- [Spotify Redirect URIs](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri) - HTTPS requirements, custom scheme support
- [Spotify Quota Modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes) - Dev Mode 5-user limit, Extended Quota

### Secondary (MEDIUM confidence)
- [Spotify Security Requirements Blog Post (Feb 2025)](https://developer.spotify.com/blog/2025-02-12-increasing-the-security-requirements-for-integrating-with-spotify) - Custom schemes still supported, HTTPS recommended
- [Spotify OAuth Migration Reminder (Nov 2025)](https://developer.spotify.com/blog/2025-10-14-reminder-oauth-migration-27-nov-2025) - Implicit grant removal timeline
- [Spotify February 2026 Migration Guide](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide) - Dev Mode changes, field removals
- [TechCrunch: Spotify Developer Mode Changes](https://techcrunch.com/2026/02/06/spotify-changes-developer-mode-api-to-require-premium-accounts-limits-test-users/) - 5-user limit, Premium requirement for owner
- [GitHub spotify/ios-auth](https://github.com/spotify/ios-auth) - iOS auth library SPM support (v3.0.1, swift-tools-version 5.9)
- [Spotify Community: Best practice for monitoring playback](https://community.spotify.com/t5/Spotify-for-Developers/Best-practice-to-monitor-current-playback/td-p/6105046) - Polling strategies
- [Android Redirect URI blog post](https://commonsware.com/blog/2025/04/12/spotify-android-sdk-redirect-uri-schemes.html) - Custom scheme issues with new apps

### Tertiary (LOW confidence)
- Free tier currently-playing endpoint behavior: Multiple community sources suggest read-only endpoints work without Premium, but no definitive official documentation confirms this for mobile Free accounts specifically. Needs validation during development.
- `LSApplicationQueriesSchemes` for `spotify`: Required for `canOpenURL` detection, but Universal Links (`open.spotify.com`) may not need it. Needs testing.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Web API + PKCE is the locked decision; Spotify docs are comprehensive
- Architecture: HIGH - Follows established codebase patterns (pure engines, @MainActor services, value-type editing)
- OAuth flow: HIGH - PKCE is well-documented, ASWebAuthenticationSession is Apple's standard
- Pitfalls: MEDIUM-HIGH - Common OAuth pitfalls are well-known; Spotify-specific rate limiting needs testing
- Free tier behavior: MEDIUM - Read-only endpoints likely work but no definitive docs; needs validation
- Feb 2026 Dev Mode changes: HIGH - Directly from Spotify official docs and TechCrunch reporting
- Build system impact: HIGH - No SPM needed (hand-roll approach), only generate-xcodeproj.js source file additions

**Codebase-specific findings:**
- `AppDependencies` is the service registry -- `SpotifyAuthManager` slots in alongside `CalendarService`, `SoundManager`
- `SoundManager` uses `.ambient` audio session category -- deep links to Spotify will NOT conflict (Spotify manages its own audio session)
- `RoutineEditorViewModel` uses value-type `RoutineEditState` -- add `spotifyPlaylistID/Name` fields to this struct
- `GameSessionViewModel` manages the quest flow -- extend with Spotify deep link launch at `startQuest()` and NowPlaying polling during `.active` phase
- `SessionSummaryView` has the summary stats section -- add song count below existing stats
- `generate-xcodeproj.js` has no SPM support and adding it would be complex (PBXProject, XCRemoteSwiftPackageReference, XCSwiftPackageProductDependency sections). The hand-roll approach avoids this entirely.
- SchemaV5 -> V6 follows the established lightweight migration pattern (optional fields with nil defaults)

**Research date:** 2026-02-15
**Valid until:** 2026-03-01 (Spotify API is actively changing -- Feb 2026 Dev Mode migration deadline is Mar 9, 2026)
