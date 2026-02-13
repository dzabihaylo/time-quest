---
phase: 02-engagement-layer
plan: 01
subsystem: domain, database
tags: [swiftdata, xp, leveling, streaks, personal-bests, progression]

# Dependency graph
requires:
  - phase: 01-playable-foundation
    provides: "GameSession, TaskEstimation, AccuracyRating, TimeEstimationScorer, SessionRepository, GameSessionViewModel"
provides:
  - "XPEngine: accuracy-based XP calculation"
  - "LevelCalculator: concave level curve from total XP"
  - "StreakTracker: graceful pause streak semantics"
  - "PersonalBestTracker: per-task closest estimation detection"
  - "PlayerProfile: SwiftData singleton for progression state"
  - "PlayerProfileRepository: fetch-or-create singleton with XP/streak mutation"
  - "GameSessionViewModel integration: XP award, level-up, streak, personal best on session completion"
affects: [02-02-PLAN, 02-03-PLAN, celebration-ui, progress-display, stats-dashboard]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure domain engine structs (XPEngine, LevelCalculator, StreakTracker, PersonalBestTracker)"
    - "Concave XP curve: baseXP * pow(level, 1.5)"
    - "Graceful streak pause (never reset on gaps)"
    - "Fetch-or-create singleton pattern for PlayerProfile"
    - "Migration-safe SwiftData: all new properties have defaults"

key-files:
  created:
    - TimeQuest/Models/PlayerProfile.swift
    - TimeQuest/Domain/XPEngine.swift
    - TimeQuest/Domain/LevelCalculator.swift
    - TimeQuest/Domain/StreakTracker.swift
    - TimeQuest/Domain/PersonalBestTracker.swift
    - TimeQuest/Repositories/PlayerProfileRepository.swift
  modified:
    - TimeQuest/Models/GameSession.swift
    - TimeQuest/App/AppDependencies.swift
    - TimeQuest/App/TimeQuestApp.swift
    - TimeQuest/Features/Player/ViewModels/GameSessionViewModel.swift
    - TimeQuest/Features/Player/Views/QuestView.swift
    - generate-xcodeproj.js

key-decisions:
  - "XP values: spot_on=100, close=60, off=25, way_off=10 plus 20 completion bonus per session"
  - "Level curve: baseXP=100, exponent=1.5 (concave -- fast early levels, slower later)"
  - "Streak semantics: pause on 2+ day gap (never reset, never punish)"
  - "Personal best comparison uses abs(differenceSeconds) across all historical estimations"

patterns-established:
  - "Domain engines as pure static structs with no mutable state"
  - "PlayerProfile singleton via fetch-or-create on @MainActor"
  - "Session-level XP tracking via xpEarned property on GameSession"

# Metrics
duration: 5min
completed: 2026-02-13
---

# Phase 2 Plan 1: Progression Data Layer Summary

**Accuracy-based XP engine with concave level curve, graceful streak pausing, and personal best detection wired into GameSessionViewModel**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-13T13:12:52Z
- **Completed:** 2026-02-13T13:17:47Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Five pure domain engines (XPEngine, LevelCalculator, StreakTracker, PersonalBestTracker) with zero framework dependencies
- PlayerProfile SwiftData model as progression singleton with migration-safe defaults
- PlayerProfileRepository with fetch-or-create pattern preventing duplicate profiles
- GameSessionViewModel awards XP, detects level-ups, updates streaks, and identifies personal bests on quest completion

## Task Commits

Each task was committed atomically:

1. **Task 1: Create domain engines and PlayerProfile model** - `a477c23` (feat)
2. **Task 2: Wire progression into GameSessionViewModel and update build system** - `f8cb780` (feat)

## Files Created/Modified
- `TimeQuest/Models/PlayerProfile.swift` - SwiftData @Model singleton for XP, level, streak, preferences
- `TimeQuest/Domain/XPEngine.swift` - Pure XP calculation from AccuracyRating (accuracy-based, never speed)
- `TimeQuest/Domain/LevelCalculator.swift` - Concave level curve: baseXP=100, exponent=1.5
- `TimeQuest/Domain/StreakTracker.swift` - Streak pause semantics (never resets on gaps)
- `TimeQuest/Domain/PersonalBestTracker.swift` - Per-task closest estimation detection
- `TimeQuest/Repositories/PlayerProfileRepository.swift` - Fetch-or-create singleton, XP/streak mutation
- `TimeQuest/Models/GameSession.swift` - Added xpEarned property with default
- `TimeQuest/App/AppDependencies.swift` - Added playerProfileRepository
- `TimeQuest/App/TimeQuestApp.swift` - Registered PlayerProfile.self in modelContainer
- `TimeQuest/Features/Player/ViewModels/GameSessionViewModel.swift` - XP award, level-up, streak, personal best integration
- `TimeQuest/Features/Player/Views/QuestView.swift` - Passes playerProfileRepository to ViewModel
- `generate-xcodeproj.js` - Added all 6 new files to build system

## Decisions Made
- XP values tuned for kids: spot_on=100, close=60, off=25, way_off=10 plus 20 completion bonus
- Level curve uses baseXP=100 with exponent=1.5 (fast early levels for motivation)
- Streaks pause on 2+ day gaps rather than resetting (no punishment for missed days)
- Personal best comparison uses absolute difference in seconds across all historical sessions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created PlayerProfileRepository early for build verification**
- **Found during:** Task 1 (Build verification)
- **Issue:** Task 1 verification required a successful build, but the new files referenced types (PlayerProfileRepository) that needed to exist in the build system
- **Fix:** Created the full PlayerProfileRepository.swift and added all files to generate-xcodeproj.js during Task 1 instead of Task 2
- **Files modified:** TimeQuest/Repositories/PlayerProfileRepository.swift, generate-xcodeproj.js
- **Verification:** Build succeeded after addition
- **Committed in:** a477c23 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed FetchDescriptor(fetchLimit:) API**
- **Found during:** Task 1 (Build verification)
- **Issue:** SwiftData's FetchDescriptor does not accept fetchLimit as an init parameter; it must be set as a property
- **Fix:** Changed `FetchDescriptor<PlayerProfile>(fetchLimit: 1)` to `var descriptor = FetchDescriptor<PlayerProfile>(); descriptor.fetchLimit = 1`
- **Files modified:** TimeQuest/Repositories/PlayerProfileRepository.swift
- **Verification:** Build succeeded
- **Committed in:** a477c23 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both auto-fixes necessary for correctness. Repository moved from Task 2 to Task 1 for buildability. No scope creep.

## Issues Encountered
- Xcode simulator target `iPhone 16,OS=18.2` not available; used `iPhone 16,OS=18.3.1` instead

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Progression data layer complete; all domain engines are pure and testable
- UI components (XP bar, level badge, streak display) can now bind to GameSessionViewModel properties
- Celebration/sensory triggers can check didLevelUp and isNewPersonalBest flags
- SessionSummaryView ready for XP display enhancement

## Self-Check: PASSED

All 6 created files verified on disk. Both task commits (a477c23, f8cb780) verified in git log. Build succeeds with zero errors.

---
*Phase: 02-engagement-layer*
*Completed: 2026-02-13*
