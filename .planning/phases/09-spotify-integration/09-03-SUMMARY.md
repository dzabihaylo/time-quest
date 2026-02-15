---
phase: 09-spotify-integration
plan: 03
subsystem: ui, parent
tags: [swiftui, spotify-oauth, playlist-picker, routine-editor, parent-dashboard, async-image]

# Dependency graph
requires:
  - phase: 09-spotify-integration
    plan: 01
    provides: "SchemaV6 with spotifyPlaylistID/Name on Routine, SpotifyPlaylist Codable type"
  - phase: 09-spotify-integration
    plan: 02
    provides: "SpotifyAuthManager (authorize/disconnect/isConnected), SpotifyAPIClient (getUserPlaylists), AppDependencies registration"
provides:
  - "SpotifySettingsView for parent connect/disconnect Spotify OAuth"
  - "PlaylistPickerView for browsing and selecting Spotify playlists"
  - "Playlist fields in RoutineEditState with save/load persistence"
  - "Spotify section in RoutineEditorView (hidden when not connected per SPOT-06)"
  - "Spotify toolbar button in ParentDashboardView"
affects: [09-04 (playback launch needs playlist ID from routine)]

# Tech tracking
tech-stack:
  added: []
  patterns: [conditional-section-visibility, lazy-display-name-restore, async-playlist-loading]

key-files:
  created:
    - TimeQuest/Features/Parent/Views/SpotifySettingsView.swift
    - TimeQuest/Features/Parent/Views/PlaylistPickerView.swift
  modified:
    - TimeQuest/Features/Parent/ViewModels/RoutineEditorViewModel.swift
    - TimeQuest/Features/Parent/Views/RoutineEditorView.swift
    - TimeQuest/Features/Parent/Views/ParentDashboardView.swift
    - generate-xcodeproj.js

key-decisions:
  - "Display name restored lazily via .task on SpotifySettingsView (not on SpotifyAuthManager init)"
  - "Spotify playlist section completely hidden when not connected (SPOT-06 invisible until opt-in)"
  - "PlaylistPickerView uses ForEach inside List (not List(data:) initializer) to avoid Swift binding inference issues"

patterns-established:
  - "Conditional Form sections: guard on dependencies.spotifyAuthManager.isConnected to hide entire feature section"
  - "Lazy profile restore: .task modifier fetches user profile on first view appearance when connected but display name is nil"

# Metrics
duration: 4min
completed: 2026-02-15
---

# Phase 9 Plan 3: Spotify Parent UI Summary

**SpotifySettingsView for connect/disconnect, PlaylistPickerView for browsing playlists with thumbnails, and RoutineEditorView integration for linking playlists to routines**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-15T22:32:45Z
- **Completed:** 2026-02-15T22:36:49Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- SpotifySettingsView provides connect/disconnect UI with display name, loading state, and error handling -- follows CalendarSettingsView pattern
- PlaylistPickerView fetches playlists from Spotify Web API with async image thumbnails, track counts, selection checkmarks, and error/empty/loading states
- RoutineEditorView gains a Spotify Playlist section that is entirely invisible when Spotify is not connected (SPOT-06 compliance), with link/change/remove playlist actions
- RoutineEditorViewModel persists spotifyPlaylistID and spotifyPlaylistName through createNew() and updateExisting() save paths
- ParentDashboardView bottom toolbar now has both Calendar and Spotify navigation buttons

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SpotifySettingsView and PlaylistPickerView** - `09b99ad` (feat)
2. **Task 2: Integrate playlist selection into RoutineEditor and wire ParentDashboard navigation** - `2ec925f` (feat)

## Files Created/Modified
- `TimeQuest/Features/Parent/Views/SpotifySettingsView.swift` - Connect/disconnect Spotify UI with OAuth flow, display name, loading/error states
- `TimeQuest/Features/Parent/Views/PlaylistPickerView.swift` - Playlist browsing with async image thumbnails, track counts, selection, error/empty/loading states
- `TimeQuest/Features/Parent/ViewModels/RoutineEditorViewModel.swift` - Added spotifyPlaylistID/Name to RoutineEditState, init from routine, createNew(), updateExisting()
- `TimeQuest/Features/Parent/Views/RoutineEditorView.swift` - Added conditional Spotify playlist section with link/change/remove, sheet for PlaylistPickerView
- `TimeQuest/Features/Parent/Views/ParentDashboardView.swift` - Added Spotify toolbar button in bottomBar navigating to SpotifySettingsView
- `generate-xcodeproj.js` - Registered SpotifySettingsView.swift and PlaylistPickerView.swift in sourceFiles and ParentViews group

## Decisions Made
- Display name is restored lazily via `.task` on SpotifySettingsView rather than eagerly on SpotifyAuthManager init -- avoids unnecessary network request when user never opens Spotify settings
- Spotify playlist section in RoutineEditorView is completely hidden (not just disabled) when Spotify is not connected, per SPOT-06 invisible-until-opt-in requirement
- PlaylistPickerView uses explicit `ForEach` inside `List {}` rather than `List(data:)` initializer to avoid Swift compiler binding inference issues with Identifiable structs

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered new view files in generate-xcodeproj.js during Task 1**
- **Found during:** Task 1
- **Issue:** Build verification requires files registered in generate-xcodeproj.js, but plan defers registration to Task 2
- **Fix:** Added SpotifySettingsView.swift and PlaylistPickerView.swift to sourceFiles and ParentViews group in Task 1
- **Files modified:** generate-xcodeproj.js
- **Verification:** Clean build succeeds after Task 1
- **Committed in:** 09b99ad (Task 1 commit)

**2. [Rule 1 - Bug] Fixed List initializer binding inference error in PlaylistPickerView**
- **Found during:** Task 1 (build verification)
- **Issue:** `List(playlists) { playlist in ... }` caused Swift compiler to infer binding form, producing type errors on playlist property access
- **Fix:** Switched to `List { ForEach(playlists) { ... } }` pattern and extracted row into separate function
- **Files modified:** TimeQuest/Features/Parent/Views/PlaylistPickerView.swift
- **Verification:** Build succeeds
- **Committed in:** 09b99ad (Task 1 commit)

**3. [Rule 1 - Bug] Fixed invalid ShapeStyle member `.accent` in PlaylistPickerView**
- **Found during:** Task 1 (build verification)
- **Issue:** `.foregroundStyle(.accent)` is invalid -- `ShapeStyle` has no `.accent` member
- **Fix:** Changed to `.foregroundStyle(.tint)` which resolves to the accent color
- **Files modified:** TimeQuest/Features/Parent/Views/PlaylistPickerView.swift
- **Verification:** Build succeeds
- **Committed in:** 09b99ad (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 blocking)
**Impact on plan:** All auto-fixes necessary for build correctness. No scope creep.

## Issues Encountered
None beyond the auto-fixed build errors documented above.

## User Setup Required
None - relies on Spotify Client ID already configured in SpotifyAuthManager (see 09-02-SUMMARY.md User Setup Required section).

## Next Phase Readiness
- Parent-facing Spotify UI complete: connect, disconnect, browse playlists, link to routines
- spotifyPlaylistID persisted on Routine model, ready for 09-04 playback launch to read and open Spotify
- All views registered in build system and building cleanly

---
*Phase: 09-spotify-integration*
*Plan: 03*
*Completed: 2026-02-15*

## Self-Check: PASSED

All 2 created files exist. Both commit hashes verified (09b99ad, 2ec925f). Key content confirmed: spotifyAuthManager in SpotifySettingsView, getUserPlaylists in PlaylistPickerView, spotifyPlaylistID in RoutineEditorViewModel, spotifyPlaylistName in RoutineEditorView, SpotifySettingsView in ParentDashboardView.
