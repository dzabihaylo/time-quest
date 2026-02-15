---
phase: 09-spotify-integration
plan: 01
subsystem: database, domain
tags: [swiftdata, spotify-web-api, codable, sendable, schema-migration, foundation]

# Dependency graph
requires:
  - phase: 08-calendar-intelligence
    provides: "SchemaV5 with calendarModeRaw field, migration chain V1-V5"
provides:
  - "SchemaV6 with spotifyPlaylistID, spotifyPlaylistName on Routine and spotifySongCount on GameSession"
  - "Codable types for all Spotify Web API response shapes (playlists, tracks, currently-playing, user profile)"
  - "SpotifyPlaylistMatcher pure domain engine for duration-based song count formatting"
  - "V5-to-V6 lightweight migration stage"
affects: [09-02 (auth service), 09-03 (UI), 09-04 (playback)]

# Tech tracking
tech-stack:
  added: []
  patterns: [spotify-codable-types, playlist-duration-matching]

key-files:
  created:
    - TimeQuest/Models/Schemas/TimeQuestSchemaV6.swift
    - TimeQuest/Models/SpotifyModels.swift
    - TimeQuest/Domain/SpotifyPlaylistMatcher.swift
  modified:
    - TimeQuest/Models/Migration/TimeQuestMigrationPlan.swift
    - TimeQuest/Models/Routine.swift
    - TimeQuest/Models/RoutineTask.swift
    - TimeQuest/Models/GameSession.swift
    - TimeQuest/Models/TaskEstimation.swift
    - TimeQuest/Models/PlayerProfile.swift
    - TimeQuest/Models/TaskDifficultyState.swift
    - TimeQuest/App/TimeQuestApp.swift
    - generate-xcodeproj.js

key-decisions:
  - "All new Spotify fields use nil defaults for CloudKit-compatible lightweight migration"
  - "SpotifyError is an enum (not struct) with typed cases for each failure mode"
  - "NowPlayingInfo is Sendable but NOT Codable -- derived from CurrentlyPlayingResponse at runtime"
  - "formatSongCount rounds to nearest 0.5 for child-friendly readability"

patterns-established:
  - "Spotify Codable types: CodingKeys for snake_case API fields, all types Sendable"
  - "PlaylistMatchResult: immutable value type with preformatted display label"

# Metrics
duration: 4min
completed: 2026-02-15
---

# Phase 9 Plan 1: Spotify Data Foundation Summary

**SchemaV6 with Spotify playlist fields, Codable types for all Spotify Web API responses, and SpotifyPlaylistMatcher domain engine for duration-based song counting**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-15T22:19:48Z
- **Completed:** 2026-02-15T22:24:12Z
- **Tasks:** 3
- **Files modified:** 14

## Accomplishments
- SchemaV6 adds spotifyPlaylistID and spotifyPlaylistName to Routine, spotifySongCount to GameSession -- all with nil defaults for lightweight migration
- Complete Codable type coverage for Spotify Web API: playlists, tracks, albums, artists, currently-playing, user profile, errors
- SpotifyPlaylistMatcher computes fractional song counts from track durations with human-readable labels ("4.5 songs", "less than 1 song")
- Migration chain extended V1->V2->V3->V4->V5->V6, all lightweight

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SchemaV6 with Spotify fields, update migration chain and typealiases** - `55a4a68` (feat)
2. **Task 2: Create SpotifyModels Codable types and SpotifyPlaylistMatcher domain engine** - `41cac10` (feat)
3. **Task 3: Register new files in generate-xcodeproj.js** - `9139984` (chore)

## Files Created/Modified
- `TimeQuest/Models/Schemas/TimeQuestSchemaV6.swift` - V6 schema with Spotify optional fields on Routine and GameSession
- `TimeQuest/Models/SpotifyModels.swift` - All Codable structs for Spotify Web API responses (PagingObject, SpotifyPlaylist, SpotifyTrack, CurrentlyPlayingResponse, NowPlayingInfo, SpotifyUserProfile, SpotifyError)
- `TimeQuest/Domain/SpotifyPlaylistMatcher.swift` - Pure Foundation engine for duration-based song counting and label formatting
- `TimeQuest/Models/Migration/TimeQuestMigrationPlan.swift` - Added V5-to-V6 lightweight migration stage
- `TimeQuest/Models/Routine.swift` - Typealias updated to V6
- `TimeQuest/Models/RoutineTask.swift` - Typealias updated to V6
- `TimeQuest/Models/GameSession.swift` - Typealias updated to V6
- `TimeQuest/Models/TaskEstimation.swift` - Typealias updated to V6
- `TimeQuest/Models/PlayerProfile.swift` - Typealias updated to V6
- `TimeQuest/Models/TaskDifficultyState.swift` - Typealias updated to V6
- `TimeQuest/App/TimeQuestApp.swift` - ModelContainer references updated to V6
- `generate-xcodeproj.js` - Registered all 3 new source files in sourceFiles array and groups

## Decisions Made
- All new Spotify fields use nil defaults for CloudKit-compatible lightweight migration (no custom migration blocks)
- SpotifyError is an enum with typed cases (notConnected, authCancelled, tokenExpired, httpError, invalidResponse, keychainError, rateLimited) rather than a single generic error
- NowPlayingInfo is Sendable but NOT Codable -- it's a derived value type created from CurrentlyPlayingResponse at runtime
- formatSongCount rounds to nearest 0.5 for child-friendly readability ("4.5 songs" not "4.37 songs")

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered files in generate-xcodeproj.js early for build verification**
- **Found during:** Task 1 and Task 2
- **Issue:** Build verification requires files to be registered in generate-xcodeproj.js, but plan defers registration to Task 3
- **Fix:** Registered SchemaV6 during Task 1 commit and SpotifyModels + SpotifyPlaylistMatcher during Task 2 commit
- **Files modified:** generate-xcodeproj.js
- **Verification:** Clean build succeeds after each task
- **Committed in:** 55a4a68 (Task 1), 41cac10 (Task 2)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Registration work moved earlier to satisfy build verification. No scope creep -- Task 3 still committed the final regenerated project file.

## Issues Encountered
- Stale V5 build artifacts caused linker error on incremental build ("Undefined symbols for architecture arm64" referencing V5 RoutineTask). Resolved with clean build. Not a code issue -- cached object files from prior V5 build.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SchemaV6 active with all Spotify fields ready for binding
- Codable types ready for Spotify auth service (09-02) to decode API responses
- SpotifyPlaylistMatcher ready for UI integration (09-03) to display song count labels
- All types are Sendable-conformant for Swift 6 concurrency

---
*Phase: 09-spotify-integration*
*Plan: 01*
*Completed: 2026-02-15*

## Self-Check: PASSED

All 3 created files exist. All 3 commit hashes verified. Key content (spotifyPlaylistID, PagingObject, matchDuration, v5ToV6) confirmed present in target files.
