# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-14)

**Core value:** The player develops an accurate internal sense of time -- the ability to predict how long things take and act on those predictions without external prompting.
**Current focus:** v3.0 Adaptive & Connected -- Phase 9 (Spotify Integration)

## Current Position

Milestone: v3.0 Adaptive & Connected
Phase: 9 of 10 (Spotify Integration)
Plan: 2 of 4 in current phase
Status: Executing 09-02
Last activity: 2026-02-15 -- Completed 09-02 (Spotify OAuth & API Service Layer)

Progress: [##################░░░░░░░░░░░░] 58%

## Performance Metrics

**v1.0 MVP:**
- Phases: 2, Plans: 6, Tasks: 13
- Timeline: 2 days (2026-02-12 -> 2026-02-13)
- Codebase: 46 Swift files, 3,575 LOC

**v2.0 Advanced Training:**
- Phases: 4 (Phases 3-6), Plans: 8, Tasks: 19
- Timeline: 2 days (2026-02-13 -> 2026-02-14)
- Codebase: 66 Swift files, 6,211 LOC

**v3.0 Adaptive & Connected:**
- Phases: 4 (Phases 7-10), Plans: TBD
- Estimated: ~2,670 LOC added (~17 new files, ~28 modified files)

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v3.0 roadmap]: Spotify via Web API + PKCE (no iOS SDK playback control) to avoid audio session conflicts with SoundManager
- [v3.0 roadmap]: SchemaV4 lightweight migration only -- all new fields have defaults
- [v3.0 roadmap]: UI refresh last (Phase 10) so all new views from Phases 7-9 get themed in one pass
- [08-01]: calendarModeRaw defaults to "always" -- existing routines unaffected by V5 migration
- [08-01]: DayContext.Equatable ignores freeDay reason (informational only)
- [08-01]: shouldShow() returns true for .unknown context in all modes (backward compatibility)
- [08-02]: Calendar IDs in UserDefaults (device-local), not SwiftData/CloudKit (device-specific identifiers)
- [08-02]: Calendar names stored alongside IDs as display fallback for identifier instability
- [08-03]: nonisolated + MainActor.assumeIsolated pattern for UIKit delegates in Swift 6
- [08-03]: Context chip uses passive language only ("School day", "Free day") per CAL-05
- [08-03]: Calendar filtering skipped when hasAccess=false -- identical to v2.0 per CAL-03
- [09-01]: All Spotify fields use nil defaults for CloudKit-compatible lightweight migration
- [09-01]: SpotifyError enum with typed cases for each failure mode (not generic error)
- [09-01]: NowPlayingInfo is Sendable but NOT Codable -- derived from CurrentlyPlayingResponse at runtime
- [09-01]: formatSongCount rounds to nearest 0.5 for child-friendly readability
- [09-02]: Hand-rolled ASWebAuthenticationSession + PKCE over spotify/ios-auth SPM (no binary xcframework, Swift 6 safe)
- [09-02]: prefersEphemeralWebBrowserSession = false for reusing existing Safari Spotify login (family UX)
- [09-02]: Token refresh uses single in-flight Task to prevent race conditions on concurrent requests
- [09-02]: @preconcurrency ASWebAuthenticationPresentationContextProviding with nonisolated + MainActor.assumeIsolated

### Blockers/Concerns

- CloudKit + SwiftData integration needs real-device testing (MEDIUM, carried from v2.0)
- Test target not wired in generate-xcodeproj.js (tests written but not runnable via xcodebuild)
- Spotify Client ID placeholder ("YOUR_SPOTIFY_CLIENT_ID") must be replaced before OAuth flow works

## Session Continuity

Last session: 2026-02-15
Stopped at: Completed 09-02-PLAN.md (Spotify OAuth & API Service Layer)
Resume file: None
