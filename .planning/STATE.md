# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-14)

**Core value:** The player develops an accurate internal sense of time -- the ability to predict how long things take and act on those predictions without external prompting.
**Current focus:** v3.0 Adaptive & Connected -- Phase 10 (UI/Brand Refresh)

## Current Position

Milestone: v3.0 Adaptive & Connected
Phase: 10 of 10 (UI/Brand Refresh)
Plan: 3 of 4 in current phase (complete)
Status: Executing Phase 10
Last activity: 2026-02-16 -- Plan 03 complete (Remaining View Migration)

Progress: [##########################░░░░] 85%

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
- [09-03]: Display name restored lazily via .task on SpotifySettingsView (not on SpotifyAuthManager init)
- [09-03]: Spotify playlist section completely hidden when not connected (SPOT-06 invisible until opt-in)
- [09-03]: PlaylistPickerView uses ForEach inside List (not List(data:) initializer) to avoid Swift binding inference
- [10-01]: @Observable class (not struct) for DesignTokens to avoid unnecessary SwiftUI redraws
- [10-01]: @unchecked Sendable on DesignTokens since all properties are immutable let constants
- [10-01]: UIColor.system* wrapped in Color() for surfaces (auto dark/light adaptation, no asset catalog needed)
- [10-01]: SpriteKit color helpers as computed vars on DesignTokens (co-located with token definitions)
- [10-03]: DesignTokens() instance (not @Environment) for SpriteKit scenes since SKScene cannot access SwiftUI environment
- [10-03]: WeeklyReflectionCardView converted to .tqCard() modifier (standard card pattern)
- [10-03]: NotificationSettingsView statusColor uses semantic tokens (positive/school/negative/caution)
- [Phase 10-02]: InsightCardView uses .tqCard(elevation: .nested) since it appears inside other containers
- [Phase 10-02]: statCard/taskResultRow use surfaceTertiary+cornerRadiusMD directly (not .tqCard) to preserve compact padding
- [Phase 10-02]: Rating color mapping: spot_on->accentSecondary, close->accent, off->textTertiary, way_off->discovery

### Blockers/Concerns

- CloudKit + SwiftData integration needs real-device testing (MEDIUM, carried from v2.0)
- Test target not wired in generate-xcodeproj.js (tests written but not runnable via xcodebuild)
- Spotify Client ID configured -- full E2E test requires physical device (Spotify not available on Simulator)

## Session Continuity

Last session: 2026-02-16
Stopped at: Completed 10-02-PLAN.md (Player Views & Shared Components Migration)
Resume file: .planning/phases/10-ui-brand-refresh/10-02-SUMMARY.md
