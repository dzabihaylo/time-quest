---
phase: 09-spotify-integration
plan: 02
subsystem: auth, services
tags: [spotify-web-api, oauth-pkce, keychain, aswebauthenticationsession, token-refresh, http-client]

# Dependency graph
requires:
  - phase: 09-spotify-integration
    plan: 01
    provides: "Codable types for Spotify Web API responses, SpotifyError enum"
provides:
  - "SpotifyAuthManager with full PKCE OAuth lifecycle (authorize, exchange, refresh, disconnect)"
  - "KeychainHelper for secure token storage (never UserDefaults)"
  - "SpotifyAPIClient with authenticated requests, 401 refresh retry, 429 rate limiting"
  - "AppDependencies.spotifyAuthManager and .spotifyAPIClient registered"
affects: [09-03 (Spotify UI settings/playlist picker), 09-04 (playback launch + now playing)]

# Tech tracking
tech-stack:
  added: [AuthenticationServices, CryptoKit, Security]
  patterns: [pkce-oauth-flow, keychain-token-storage, race-safe-token-refresh, authenticated-http-client]

key-files:
  created:
    - TimeQuest/Services/SpotifyAuthManager.swift
    - TimeQuest/Services/KeychainHelper.swift
    - TimeQuest/Services/SpotifyAPIClient.swift
  modified:
    - TimeQuest/App/AppDependencies.swift
    - generate-xcodeproj.js

key-decisions:
  - "Hand-rolled ASWebAuthenticationSession + PKCE over spotify/ios-auth SPM package (no binary xcframework, guaranteed Swift 6 compatibility)"
  - "prefersEphemeralWebBrowserSession = false for reusing existing Safari Spotify login (better UX for family app)"
  - "Token refresh uses single in-flight Task to prevent race conditions on concurrent requests"
  - "@preconcurrency ASWebAuthenticationPresentationContextProviding with nonisolated + MainActor.assumeIsolated pattern"

patterns-established:
  - "PKCE OAuth flow: generateCodeVerifier (64 random bytes, base64url) + generateCodeChallenge (SHA256, base64url)"
  - "Keychain CRUD: delete-before-add pattern with separate entries for access_token, refresh_token, token_expiry"
  - "Authenticated HTTP client: validAccessToken() -> Bearer header, auto-retry on 401 and 429"

# Metrics
duration: 2min
completed: 2026-02-15
---

# Phase 9 Plan 2: Spotify OAuth & API Service Layer Summary

**PKCE OAuth flow via ASWebAuthenticationSession with Keychain token storage, race-safe refresh, and authenticated HTTP client for Spotify Web API playlists/tracks/currently-playing endpoints**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-15T22:26:46Z
- **Completed:** 2026-02-15T22:29:26Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- SpotifyAuthManager handles complete PKCE OAuth lifecycle: authorization URL construction, ASWebAuthenticationSession presentation, token exchange, Keychain storage, automatic refresh with race condition protection, and disconnect cleanup
- KeychainHelper provides simple save/load/delete for Keychain entries using Security framework (SecItemAdd, SecItemCopyMatching, SecItemDelete)
- SpotifyAPIClient provides typed methods for all 4 Spotify endpoints (getUserProfile, getUserPlaylists, getPlaylistTracks, getCurrentlyPlaying) with automatic 401 retry and 429 rate limiting
- AppDependencies registers spotifyAuthManager and spotifyAPIClient for app-wide dependency injection

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SpotifyAuthManager with PKCE OAuth flow and KeychainHelper for token storage** - `b232822` (feat)
2. **Task 2: Create SpotifyAPIClient, wire into AppDependencies, register files in build system** - `241d716` (feat)

## Files Created/Modified
- `TimeQuest/Services/KeychainHelper.swift` - Keychain CRUD with save/load/delete for secure token persistence
- `TimeQuest/Services/SpotifyAuthManager.swift` - @MainActor @Observable OAuth PKCE manager with ASWebAuthenticationSession, token lifecycle, and race-safe refresh
- `TimeQuest/Services/SpotifyAPIClient.swift` - Authenticated HTTP client for Spotify Web API with retry logic (401/429)
- `TimeQuest/App/AppDependencies.swift` - Added spotifyAuthManager and spotifyAPIClient properties
- `generate-xcodeproj.js` - Registered all 3 service files in sourceFiles array and Services group

## Decisions Made
- Hand-rolled ASWebAuthenticationSession + PKCE over spotify/ios-auth SPM package -- avoids binary xcframework, guarantees Swift 6 compatibility, and keeps generate-xcodeproj.js simple (no SPM support needed)
- prefersEphemeralWebBrowserSession = false so existing Safari Spotify login is reused (better UX for family app -- research pitfall #7)
- Token refresh uses single in-flight Task (refreshTask property) to prevent race conditions when multiple concurrent requests detect an expired token
- @preconcurrency ASWebAuthenticationPresentationContextProviding conformance with nonisolated + MainActor.assumeIsolated pattern (same approach as CalendarChooserView Coordinator from Phase 8)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered all 3 service files in generate-xcodeproj.js during Task 1**
- **Found during:** Task 1
- **Issue:** Build verification requires files in generate-xcodeproj.js, but plan splits registration to Task 2. Registering early requires SpotifyAPIClient.swift to exist.
- **Fix:** Registered all 3 files in Task 1 and created a minimal placeholder SpotifyAPIClient.swift (replaced with full implementation in Task 2)
- **Files modified:** generate-xcodeproj.js, TimeQuest/Services/SpotifyAPIClient.swift (placeholder)
- **Verification:** Clean build succeeds after Task 1
- **Committed in:** b232822 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Registration moved earlier to satisfy build verification. No scope creep -- Task 2 replaced the placeholder with full implementation.

## Issues Encountered
None.

## User Setup Required
Spotify Developer account setup is required before OAuth flow can function:
- Create Spotify Developer app at https://developer.spotify.com/dashboard
- Replace "YOUR_SPOTIFY_CLIENT_ID" in SpotifyAuthManager.swift with actual Client ID
- Add redirect URI "timequest://spotify-callback" in Spotify Dashboard app settings
- Add test user emails to app allowlist (Dev Mode: max 5 users)

## Next Phase Readiness
- SpotifyAuthManager ready for SpotifySettingsView (09-03) to connect/disconnect accounts
- SpotifyAPIClient ready for PlaylistPickerView (09-03) to browse and select playlists
- SpotifyAPIClient.getCurrentlyPlaying() ready for NowPlayingIndicator (09-04) polling
- All services registered in AppDependencies for @Environment injection

---
*Phase: 09-spotify-integration*
*Plan: 02*
*Completed: 2026-02-15*

## Self-Check: PASSED

All 3 created files exist. Both commit hashes verified (b232822, 241d716). Key content confirmed: ASWebAuthenticationSession in SpotifyAuthManager (3 occurrences), SecItemAdd in KeychainHelper (1), authenticatedRequest in SpotifyAPIClient (5), spotifyAuthManager in AppDependencies (3), spotifyAPIClient in AppDependencies (2).
