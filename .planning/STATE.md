# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-13)

**Core value:** The player develops an accurate internal sense of time -- the ability to predict how long things take and act on those predictions without external prompting.
**Current focus:** v2.0 Advanced Training -- Phase 6 in progress (Plan 1 of 2 complete)

## Current Position

Milestone: v2.0 Advanced Training
Phase: 6 of 6 in progress (Weekly Reflection Summaries)
Plan: 1 of 2 complete in Phase 6
Status: Phase 6 Plan 1 complete -- executing Plan 2 next
Last activity: 2026-02-14 -- Completed 06-01 (WeeklyReflection data layer)

Progress: [###########################...] 93% (13/14 plans -- v1.0: 6/6, v2.0: 7/8)

## Performance Metrics

**v1.0 MVP:**
- Phases: 2, Plans: 6, Tasks: 13
- Timeline: 2 days (2026-02-12 -> 2026-02-13)
- Codebase: 46 Swift files, 3,575 LOC

**v2.0 Advanced Training:**
- Phases: 4 (Phases 3-6), Plans: 8
- Status: Phase 6 Plan 1 complete
- Codebase: 65 Swift files, ~5,870 LOC

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 03-01 | Schema Versioning | 4min | 2 | 11 |
| 03-02 | CloudKit Backup | 10min | 3 | 10 |
| 04-01 | InsightEngine Domain Core | 6min | 2 | 5 |
| 04-02 | Insight UI: My Patterns + Hints | 12min | 3 | 8 |
| 05-01 | Self-Set Routines | ~15min | 3 | 10 |
| 05-02 | Production Audio + XP Tunables | ~10min | 2 | 9 |
| 06-01 | Weekly Reflection Data Layer | 3min | 2 | 4 |

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
- Graceful CloudKit fallback: try? .automatic first, fall back to .none

**Phase 4 decisions:**
- Absolute 15s bias threshold, 0.5 slope threshold, 0.3/0.6 CV breakpoints
- EstimationSnapshot bridge pattern: pure struct + SwiftData extension
- Contextual hints preloaded synchronously in startQuest()

**Phase 5 decisions:**
- SchemaV3 with createdBy: String = "parent" on Routine (lightweight migration V2->V3)
- Player creation flow as separate view (not sharing parent RoutineEditorView)
- RoutineTemplateProvider with 3 templates (Homework, Friend's House, Activity Prep)
- Orange star badge for player-created quests (no labeling of parent routines)
- Parent dashboard @Query filtered to createdBy == "parent"
- AVAudioSession .ambient category in SoundManager init
- XPConfiguration struct extracting 7 tunable constants from XPEngine + LevelCalculator
- Sound effects generated via Python synthesis (real audio, not silent placeholders)

**Phase 6 decisions:**
- ReflectionDefaults uses ISO 8601 week identifiers (YYYY-WNN) for UserDefaults storage
- Quest count uses GameSession query, not snapshot counting
- Most improved task requires 2+ estimations per week per task in both weeks
- Pattern highlight priority: improving trend > notable bias > very consistent
- completedAt Date? filter done in-memory (SwiftData #Predicate limitation with optional Dates)

### Pending Todos

- Execute Phase 6 Plan 2 (Reflection Card UI + PlayerHome integration) -- NEXT
- Complete v2.0 milestone

### Blockers/Concerns

- CloudKit + SwiftData integration needs real-device testing (MEDIUM)
- Test target not wired in generate-xcodeproj.js (tests written but not runnable via xcodebuild)
- Sound effects are synthesized tones; may want to replace with professionally designed sounds later

## Session Continuity

Last session: 2026-02-14
Stopped at: Completed 06-01-PLAN.md (Weekly Reflection Data Layer)
Resume file: None
