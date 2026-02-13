# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-13)

**Core value:** The player develops an accurate internal sense of time -- the ability to predict how long things take and act on those predictions without external prompting.
**Current focus:** v2.0 Advanced Training -- Phase 4 in progress

## Current Position

Milestone: v2.0 Advanced Training
Phase: 4 of 6 (Contextual Learning Insights)
Plan: 1 of 2 complete
Status: Phase 4 Plan 1 complete -- InsightEngine domain core built
Last activity: 2026-02-13 -- Executed 04-01 (InsightEngine domain core)

Progress: [################..............] 65% (9/14 plans -- v1.0: 6/6, v2.0: 3/8)

## Performance Metrics

**v1.0 MVP:**
- Phases: 2, Plans: 6, Tasks: 13
- Timeline: 2 days (2026-02-12 -> 2026-02-13)
- Codebase: 46 Swift files, 3,575 LOC

**v2.0 Advanced Training:**
- Phases: 4 (Phases 3-6), Plans: 7 (estimated)
- Status: In progress -- Phase 4 Plan 1 complete
- Codebase: 53 Swift files, ~4,200 LOC

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 03-01 | Schema Versioning | 4min | 2 | 11 |
| 03-02 | CloudKit Backup | 10min | 3 | 10 |
| 04-01 | InsightEngine Domain Core | 6min | 2 | 5 |

## Accumulated Context

### Decisions

See .planning/PROJECT.md Key Decisions table for full list with outcomes.

**v2.0 scope decisions:**
- CloudKit-first migration: schema + defaults must complete before any feature work
- InsightEngine is dependency root: insights before reflections (Phase 4 before Phase 6)
- Self-set routines + sound assets bundled: independent features, similar risk level
- All new model properties require defaults (CloudKit + lightweight migration constraint)

**Phase 3 decisions:**
- Used nonisolated(unsafe) for VersionedSchema.versionIdentifier (Swift 6 strict concurrency)
- Used @preconcurrency import SwiftData in schema/migration files
- Fully qualified relationship inverse keypaths to prevent typealias cross-schema resolution
- Used nonisolated(unsafe) for CloudKitSyncMonitor.observer (deinit access in Swift 6)
- Used @preconcurrency import CoreData for NSPersistentCloudKitContainer.Event Sendable
- Extract event data before Task boundary to avoid Sendable violation
- CODE_SIGN_ENTITLEMENTS path relative to project dir, not repo root
- Graceful CloudKit fallback: try? .automatic first, fall back to .none (prevents crash on simulator)
- Container ID: iCloud.com.timequest.app (not iCloud.icloud.com.timequest.app)

**Phase 4 decisions:**
- Absolute 15s bias threshold matching TimeEstimationScorer spot_on threshold
- Linear regression slope 0.5 accuracy-points-per-session threshold for trend detection
- CV breakpoints 0.3/0.6 for consistency classification (standard statistical breakpoints)
- Added Sendable conformance to all insight types for Swift 6 strict concurrency
- EstimationSnapshot bridge pattern: pure struct + SwiftData extension in same file

### Pending Todos

- Create v2.0 roadmap -- DONE
- Plan Phase 3 (Data Foundation + CloudKit Backup) -- DONE
- Execute Phase 3 Plan 1 (Schema Versioning) -- DONE
- Execute Phase 3 Plan 2 (CloudKit Backup) -- DONE (verified)
- Plan Phase 4 (Contextual Learning Insights) -- DONE
- Execute Phase 4 Plan 1 (InsightEngine Domain Core) -- DONE
- Execute Phase 4 Plan 2 (Insight UI: My Patterns + Contextual Hints) -- NEXT

### Blockers/Concerns

- CloudKit + SwiftData integration needs real-device testing (MEDIUM research flag)
- Sound effects still placeholder .wav files (Phase 5 will fix)
- XP curve constants need playtesting data (Phase 5 exposes tunables)
- Test target not wired in generate-xcodeproj.js (tests written but not runnable via xcodebuild)

## Session Continuity

Last session: 2026-02-13
Stopped at: Completed 04-01-PLAN.md -- ready for 04-02 execution
Resume file: None
