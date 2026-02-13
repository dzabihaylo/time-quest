---
phase: 03-data-foundation-cloudkit-backup
plan: 01
subsystem: database
tags: [swiftdata, versioned-schema, migration, cloudkit-prep, swift6-concurrency]

# Dependency graph
requires:
  - phase: 02-progression-engagement
    provides: "5 SwiftData @Model classes (Routine, RoutineTask, GameSession, TaskEstimation, PlayerProfile)"
provides:
  - "TimeQuestSchemaV1 -- retroactive V1 VersionedSchema capturing current on-disk layout"
  - "TimeQuestSchemaV2 -- V2 schema with cloudID and property-level defaults on all models"
  - "TimeQuestMigrationPlan -- lightweight V1->V2 migration stage"
  - "Typealias pattern: model files reference V2 schema types transparently"
affects: [03-02-cloudkit-backup, phase-04, phase-05, phase-06]

# Tech tracking
tech-stack:
  added: [VersionedSchema, SchemaMigrationPlan, MigrationStage.lightweight]
  patterns: [typealias-to-versioned-schema, nonisolated-unsafe-for-swift6, preconcurrency-import-swiftdata]

key-files:
  created:
    - TimeQuest/Models/Schemas/TimeQuestSchemaV1.swift
    - TimeQuest/Models/Schemas/TimeQuestSchemaV2.swift
    - TimeQuest/Models/Migration/TimeQuestMigrationPlan.swift
  modified:
    - TimeQuest/Models/Routine.swift
    - TimeQuest/Models/RoutineTask.swift
    - TimeQuest/Models/GameSession.swift
    - TimeQuest/Models/TaskEstimation.swift
    - TimeQuest/Models/PlayerProfile.swift
    - generate-xcodeproj.js

key-decisions:
  - "Used nonisolated(unsafe) for VersionedSchema.versionIdentifier to satisfy Swift 6 strict concurrency"
  - "Used @preconcurrency import SwiftData to suppress Sendable warnings on MigrationStage"
  - "Fully qualified relationship inverse keypaths in both V1 and V2 schemas to avoid typealias resolution conflicts"

patterns-established:
  - "Typealias model pattern: model files become typealiases to latest VersionedSchema types, computed properties live in extensions"
  - "Schema versioning: V(N) captures exact on-disk layout, V(N+1) adds new properties with defaults"
  - "Lightweight-only migration: no custom willMigrate/didMigrate (CloudKit constraint)"

# Metrics
duration: 4min
completed: 2026-02-13
---

# Phase 3 Plan 1: Schema Versioning Summary

**SwiftData VersionedSchema V1/V2 with lightweight migration, cloudID on all 5 models, and typealias-based model files for transparent upgrade**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-13T15:23:43Z
- **Completed:** 2026-02-13T15:28:15Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Created retroactive V1 VersionedSchema that exactly mirrors the current on-disk model definitions
- Created V2 VersionedSchema with cloudID: String on all 5 models and property-level defaults on every non-optional property
- Established lightweight-only migration plan (V1->V2) compatible with CloudKit constraints
- Converted all 5 model files to typealiases preserving computed properties (orderedTasks, orderedEstimations, rating)
- Updated build system with Schemas/ and Migration/ groups; project compiles with zero errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Create V1 and V2 VersionedSchemas + migration plan** - `3a2d8b0` (feat)
2. **Task 2: Convert model files to typealiases + update build system** - `c802918` (feat)

## Files Created/Modified
- `TimeQuest/Models/Schemas/TimeQuestSchemaV1.swift` - Retroactive V1 VersionedSchema with all 5 models matching current on-disk schema
- `TimeQuest/Models/Schemas/TimeQuestSchemaV2.swift` - V2 VersionedSchema with cloudID + defaults on all models
- `TimeQuest/Models/Migration/TimeQuestMigrationPlan.swift` - SchemaMigrationPlan with lightweight V1->V2 stage
- `TimeQuest/Models/Routine.swift` - Typealias to V2 + orderedTasks computed property
- `TimeQuest/Models/RoutineTask.swift` - Typealias to V2
- `TimeQuest/Models/GameSession.swift` - Typealias to V2 + orderedEstimations computed property
- `TimeQuest/Models/TaskEstimation.swift` - Typealias to V2 + rating computed property
- `TimeQuest/Models/PlayerProfile.swift` - Typealias to V2
- `generate-xcodeproj.js` - Added Schemas/ and Migration/ groups + 3 new source files

## Decisions Made
- Used `nonisolated(unsafe)` for `versionIdentifier` static var (Swift 6 strict concurrency requires this for VersionedSchema protocol conformance)
- Used `@preconcurrency import SwiftData` in all schema/migration files to suppress MigrationStage Sendable warnings
- Used fully qualified inverse keypaths (`\TimeQuestSchemaV1.RoutineTask.routine` not `\RoutineTask.routine`) to prevent typealias resolution from crossing schema boundaries

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Swift 6 strict concurrency errors on VersionedSchema**
- **Found during:** Task 2 (build verification)
- **Issue:** `static var versionIdentifier` triggers "not concurrency-safe because it is nonisolated global shared mutable state" error in Swift 6
- **Fix:** Added `nonisolated(unsafe)` modifier to versionIdentifier in both V1 and V2 schemas; added `@preconcurrency import SwiftData` to all 3 new files
- **Files modified:** TimeQuestSchemaV1.swift, TimeQuestSchemaV2.swift, TimeQuestMigrationPlan.swift
- **Verification:** Clean build succeeds with zero errors
- **Committed in:** c802918 (Task 2 commit)

**2. [Rule 1 - Bug] Fixed relationship inverse keypath resolution across schemas**
- **Found during:** Task 2 (build verification)
- **Issue:** Unqualified keypaths like `\RoutineTask.routine` in V1 schema resolved to V2 types via typealiases, causing linker symbol mismatches
- **Fix:** Changed all relationship inverse keypaths to fully qualified form (`\TimeQuestSchemaV1.RoutineTask.routine`, `\TimeQuestSchemaV2.RoutineTask.routine`)
- **Files modified:** TimeQuestSchemaV1.swift, TimeQuestSchemaV2.swift
- **Verification:** Clean build succeeds; linker resolves all symbols correctly
- **Committed in:** c802918 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs -- Swift 6 concurrency + keypath resolution)
**Impact on plan:** Both auto-fixes were necessary for compilation. No scope creep. The plan anticipated this possibility and noted the fix approach.

## Issues Encountered
- Stale build cache caused linker errors on incremental build after typealias conversion; resolved with clean build (`xcodebuild clean build`)

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Schema versioning foundation complete; ready for Plan 02 (CloudKit container enablement + backup)
- ModelContainer in TimeQuestApp.swift still uses `.modelContainer(for:)` shorthand -- Plan 02 should switch to migration-plan-aware initialization when enabling CloudKit
- All existing code (repositories, view models, views) works without modification via typealiases

## Self-Check: PASSED

All 9 files verified present. Both commit hashes (3a2d8b0, c802918) confirmed in git log.

---
*Phase: 03-data-foundation-cloudkit-backup*
*Completed: 2026-02-13*
