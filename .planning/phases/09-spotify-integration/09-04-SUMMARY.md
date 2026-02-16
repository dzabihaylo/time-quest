---
phase: 09-spotify-integration
plan: 04
subsystem: player-ui, playback
tags: [spotify, universal-links, now-playing, polling, song-count, swiftui]

# Dependency graph
requires:
  - phase: 09-spotify-integration
    plan: 01
    provides: "SchemaV6 with spotifySongCount on GameSession, SpotifyPlaylistMatcher, NowPlayingInfo"
  - phase: 09-spotify-integration
    plan: 02
    provides: "SpotifyAuthManager, SpotifyAPIClient for getCurrentlyPlaying()"
  - phase: 09-spotify-integration
    plan: 03
    provides: "Parent UI for connecting Spotify and linking playlists to routines"
provides:
  - "Spotify playback launch via Universal Link when quest starts with linked playlist"
  - "Now Playing indicator polling every 10s during active quests"
  - "Song count persisted on GameSession and displayed in session summary"
  - "NowPlayingIndicator shared component"
affects: [10 (UI refresh -- NowPlayingIndicator will be themed)]

# Tech tracking
tech-stack:
  added: []
  patterns: [universal-link-playback, polling-with-task-cancellation, conditional-ui-rendering]

key-files:
  created:
    - TimeQuest/Features/Shared/Components/NowPlayingIndicator.swift
    - TimeQuest/Info.plist
  modified:
    - TimeQuest/Features/Player/ViewModels/GameSessionViewModel.swift
    - TimeQuest/Features/Player/Views/QuestView.swift
    - TimeQuest/Features/Player/Views/SessionSummaryView.swift
    - TimeQuest/Services/SpotifyAuthManager.swift
    - generate-xcodeproj.js

key-decisions:
  - "Universal Links (open.spotify.com) over spotify: URI scheme to avoid iOS confirmation dialog"
  - "10-second polling interval to stay well under Spotify rate limits"
  - "Song tracking via unique track name set (not Spotify track ID) for simplicity"
  - "All Spotify code paths guarded by isConnected + spotifyPlaylistID (SPOT-06)"
  - "Info.plist created for timequest:// URL scheme registration (OAuth callback)"
  - "Spotify Client ID wired from developer dashboard (was placeholder)"

patterns-established:
  - "Conditional UI: if let binding pattern for optional Spotify data (no else branch)"
  - "Task-based polling: cancellable async loop with Task.sleep and isCancelled checks"

# Metrics
duration: 6min
completed: 2026-02-16
---

# Phase 9 Plan 4: Player UI — Playback, NowPlaying, Song Count

**Spotify playback launch via Universal Link, real-time Now Playing indicator with 10s polling, and song count as time unit in session summary**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-15
- **Completed:** 2026-02-16
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 7

## Accomplishments
- GameSessionViewModel launches Spotify via Universal Link at quest start when routine has a linked playlist
- NowPlayingIndicator component shows current track name and artist during active quests
- Polling every 10s via cancellable Task loop, stops on quest end or app background
- Song count tracked via unique track names, formatted via SpotifyPlaylistMatcher, persisted to GameSession.spotifySongCount
- SessionSummaryView shows "You got through X songs" when Spotify data available
- All Spotify paths are complete no-ops when not connected or no playlist linked (SPOT-06)
- Info.plist created with timequest:// URL scheme for OAuth callback
- Spotify Client ID configured from developer dashboard

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend GameSessionViewModel with Spotify playback launch, Now Playing polling, and song count tracking** - `ad2c869` (feat)
2. **Task 2: Wire NowPlayingIndicator into QuestView and song count into SessionSummaryView** - `1603aed` (feat)
3. **Task 3: Verify Spotify integration end-to-end** - Human checkpoint (approved: deferred to device testing)

## Files Created/Modified
- `TimeQuest/Features/Shared/Components/NowPlayingIndicator.swift` - Compact HStack with music note, track name, artist name, ultraThinMaterial background
- `TimeQuest/Features/Player/ViewModels/GameSessionViewModel.swift` - configureSpotify(), startNowPlayingPolling(), stopNowPlayingPolling(), persistSongCount(), Universal Link launch
- `TimeQuest/Features/Player/Views/QuestView.swift` - NowPlayingIndicator overlay during active task with move+opacity transition
- `TimeQuest/Features/Player/Views/SessionSummaryView.swift` - "You got through X songs" label below stats
- `TimeQuest/Services/SpotifyAuthManager.swift` - Client ID replaced with actual developer credentials
- `TimeQuest/Info.plist` - CFBundleURLTypes with timequest:// scheme for OAuth callback
- `generate-xcodeproj.js` - INFOPLIST_FILE build setting added, NowPlayingIndicator registered

## Decisions Made
- Universal Links (https://open.spotify.com/playlist/...) used over spotify: URI to avoid iOS confirmation dialog
- 10-second polling interval keeps well under Spotify Web API rate limits
- Song tracking uses unique track names (not IDs) for simplicity -- tracks heard during quest
- All Spotify code paths guarded by both isConnected AND spotifyPlaylistID != nil (SPOT-06 compliance)
- Created Info.plist for URL scheme since GENERATE_INFOPLIST_FILE doesn't support CFBundleURLTypes via build settings

## Deviations from Plan

### Orchestrator-applied changes (post-checkpoint)
- **Spotify Client ID**: Replaced placeholder with actual developer credentials (b3ac760a...)
- **Info.plist**: Created for timequest:// URL scheme registration (not in original plan -- discovered as OAuth requirement)
- **generate-xcodeproj.js**: Added INFOPLIST_FILE build setting for both Debug and Release configs

## Issues Encountered
- Spotify can't run on iOS Simulator -- full E2E testing deferred to physical device
- Info.plist path resolution: Initially used "TimeQuest/Info.plist" but xcodeproj resolves relative to its own location, fixed to "Info.plist"

## User Setup Required
- Spotify Developer app created at developer.spotify.com/dashboard
- Client ID configured in SpotifyAuthManager.swift
- Redirect URI (timequest://spotify-callback) must be registered in Spotify Dashboard
- Test user emails added to Spotify app allowlist (Dev Mode: max 5 users)

## Next Phase Readiness
- Full Spotify integration code-complete across all 4 plans
- Ready for Phase 10 UI refresh -- NowPlayingIndicator, SpotifySettingsView, PlaylistPickerView all need theming

---
*Phase: 09-spotify-integration*
*Plan: 04*
*Completed: 2026-02-16*

## Self-Check: PASSED

Both created files exist on disk. Both commit hashes (ad2c869, 1603aed) verified. Key content (NowPlayingIndicator, openPlaylistInSpotify, spotifySongCount) confirmed present in target files. Build succeeds.
