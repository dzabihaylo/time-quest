# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-13)

**Core value:** The player develops an accurate internal sense of time -- the ability to predict how long things take and act on those predictions without external prompting.
**Current focus:** v2.0 Advanced Training -- Phase 3 complete (pending verification)

## Current Position

Milestone: v2.0 Advanced Training
Phase: 3 of 6 (Data Foundation + CloudKit Backup)
Plan: 2 of 2 complete (checkpoint pending)
Status: Checkpoint -- awaiting human verification
Last activity: 2026-02-13 -- CloudKit backup integration + sync monitor + iCloud status UI

Progress: [###############...............] 62% (8/13 plans -- v1.0: 6/6, v2.0: 2/7)

## Performance Metrics

**v1.0 MVP:**
- Phases: 2, Plans: 6, Tasks: 13
- Timeline: 2 days (2026-02-12 -> 2026-02-13)
- Codebase: 46 Swift files, 3,575 LOC

**v2.0 Advanced Training:**
- Phases: 4 (Phases 3-6), Plans: 7 (estimated)
- Status: In progress

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 03-01 | Schema Versioning | 4min | 2 | 11 |
| 03-02 | CloudKit Backup | 5min | 2 | 10 |

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

### Pending Todos

- Create v2.0 roadmap -- DONE
- Plan Phase 3 (Data Foundation + CloudKit Backup) -- DONE
- Execute Phase 3 Plan 1 (Schema Versioning) -- DONE
- Execute Phase 3 Plan 2 (CloudKit Backup) -- DONE (checkpoint pending)

### Blockers/Concerns

- CloudKit + SwiftData integration needs real-device testing (MEDIUM research flag)
- Sound effects still placeholder .wav files (Phase 5 will fix)
- XP curve constants need playtesting data (Phase 5 exposes tunables)

## Session Continuity

Last session: 2026-02-13
Stopped at: 03-02-PLAN.md Task 3 checkpoint (human-verify) -- awaiting CloudKit container setup + UI verification
Resume file: None
