---
phase: 07-schema-evolution-adaptive-difficulty
plan: 01
subsystem: database
tags: [swiftdata, schema-migration, versioned-schema, ema, difficulty-levels]

# Dependency graph
requires:
  - phase: 06-self-set-routines-production-audio
    provides: SchemaV3 with all existing models (Routine, RoutineTask, GameSession, TaskEstimation, PlayerProfile)
provides:
  - SchemaV4 with TaskDifficultyState model and GameSession difficulty fields
  - V3-to-V4 lightweight migration stage in migration chain
  - DifficultyConfiguration with 5-level EMA thresholds, accuracy bands, and XP multipliers
  - DifficultySnapshot value-type bridge from TaskDifficultyState to domain layer
  - All typealiases updated to V4
  - TimeQuestApp ModelContainer referencing V4 with TaskDifficultyState
affects: [07-02-adaptive-difficulty-engine, 08-session-history, 10-ui-refresh]

# Tech tracking
tech-stack:
  added: []
  patterns: [5-level-difficulty-configuration, ema-smoothing, difficulty-snapshot-bridge]

key-files:
  created:
    - TimeQuest/Models/Schemas/TimeQuestSchemaV4.swift
    - TimeQuest/Models/TaskDifficultyState.swift
    - TimeQuest/Models/DifficultySnapshot.swift
    - TimeQuest/Domain/DifficultyConfiguration.swift
  modified:
    - TimeQuest/Models/Migration/TimeQuestMigrationPlan.swift
    - TimeQuest/Models/Routine.swift
    - TimeQuest/Models/RoutineTask.swift
    - TimeQuest/Models/GameSession.swift
    - TimeQuest/Models/TaskEstimation.swift
    - TimeQuest/Models/PlayerProfile.swift
    - TimeQuest/App/TimeQuestApp.swift
    - generate-xcodeproj.js

key-decisions:
  - "No @Attribute(.unique) on TaskDifficultyState.taskDisplayName -- CloudKit forbids unique constraints"
  - "GameSession stores difficultyLevel and xpMultiplier as snapshots for fair historical comparisons"
  - "DifficultyConfiguration is Foundation-only (no SwiftData) following XPConfiguration pattern"

patterns-established:
  - "TaskDifficultyState keyed by taskDisplayName (string match, not relationship) for cross-routine difficulty tracking"
  - "DifficultySnapshot bridges SwiftData model to domain layer following EstimationSnapshot dual-import pattern"
  - "5-level difficulty system with EMA-based advancement thresholds and tightening accuracy bands"

# Metrics
duration: 8min
completed: 2026-02-14
---

# Phase 7 Plan 01: Schema Evolution (V3 to V4) + Foundation Types Summary

**SchemaV4 with TaskDifficultyState model, 5-level DifficultyConfiguration with EMA thresholds and tightening accuracy bands, and DifficultySnapshot bridge type**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-14T17:06:55Z
- **Completed:** 2026-02-14T17:15:00Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- SchemaV4 adds TaskDifficultyState model (per-task difficulty tracking with EMA) and two new GameSession fields (difficultyLevel, xpMultiplier) for fair historical snapshots
- DifficultyConfiguration centralizes all 5-level tunable constants: EMA alpha (0.3), level thresholds (0/65/75/83/90%), tightening accuracy bands, and XP multipliers (1.0x to 2.0x)
- Complete V1->V2->V3->V4 lightweight migration chain with CloudKit-compatible defaults on all new fields
- DifficultySnapshot provides a clean value-type bridge from SwiftData to the domain layer, following the established EstimationSnapshot pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SchemaV4 with TaskDifficultyState model, update migration chain and typealiases** - `c8a20f0` (feat)
2. **Task 2: Create DifficultyConfiguration and DifficultySnapshot, update TimeQuestApp and build system** - `09436fd` (feat)

## Files Created/Modified
- `TimeQuest/Models/Schemas/TimeQuestSchemaV4.swift` - V4 schema with all V3 models plus TaskDifficultyState and GameSession.difficultyLevel/xpMultiplier
- `TimeQuest/Models/TaskDifficultyState.swift` - Typealias for TimeQuestSchemaV4.TaskDifficultyState
- `TimeQuest/Models/DifficultySnapshot.swift` - Value-type bridge from TaskDifficultyState to domain layer
- `TimeQuest/Domain/DifficultyConfiguration.swift` - Centralized 5-level difficulty constants (EMA, thresholds, XP multipliers)
- `TimeQuest/Models/Migration/TimeQuestMigrationPlan.swift` - Added V3-to-V4 lightweight migration stage
- `TimeQuest/Models/Routine.swift` - Typealias updated to V4
- `TimeQuest/Models/RoutineTask.swift` - Typealias updated to V4
- `TimeQuest/Models/GameSession.swift` - Typealias updated to V4
- `TimeQuest/Models/TaskEstimation.swift` - Typealias updated to V4
- `TimeQuest/Models/PlayerProfile.swift` - Typealias updated to V4
- `TimeQuest/App/TimeQuestApp.swift` - ModelContainer references V4, includes TaskDifficultyState in both container paths
- `generate-xcodeproj.js` - All 4 new files registered in sourceFiles and group arrays

## Decisions Made
- No `@Attribute(.unique)` on TaskDifficultyState.taskDisplayName because CloudKit forbids unique constraints
- GameSession stores difficultyLevel and xpMultiplier as snapshots so historical sessions preserve the difficulty context they were played under
- DifficultyConfiguration follows the XPConfiguration pattern: Foundation-only, Sendable, static default

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- V4 schema compiled and building successfully -- ready for AdaptiveDifficultyEngine implementation in Plan 07-02
- All foundation types (TaskDifficultyState, DifficultyConfiguration, DifficultySnapshot) in place for engine to consume
- No blockers for Plan 07-02

---
*Phase: 07-schema-evolution-adaptive-difficulty*
*Completed: 2026-02-14*
