---
phase: 04-contextual-learning-insights
plan: 02
subsystem: ui
tags: [swiftui, insight-cards, contextual-hints, my-patterns, navigation, curiosity-framing]

# Dependency graph
requires:
  - phase: 04-contextual-learning-insights
    plan: 01
    provides: "InsightEngine with detectBias, detectTrend, computeConsistency, contextualHint, generateInsights + EstimationSnapshot bridge"
provides:
  - "InsightCardView shared component for displaying per-task insights"
  - "MyPatternsView screen with insights grouped by routine"
  - "MyPatternsViewModel orchestrating InsightEngine from SwiftData queries"
  - "Contextual hint preloading in GameSessionViewModel.startQuest()"
  - "Hint capsule display in EstimationInputView for eligible tasks"
  - "Navigation from PlayerHomeView to My Patterns"
affects: [phase-06-weekly-reflection]

# Tech tracking
tech-stack:
  added: []
  patterns: [shared-insight-card-component, contextual-hint-preloading, curiosity-framed-ui-language]

key-files:
  created:
    - TimeQuest/Features/Shared/Components/InsightCardView.swift
    - TimeQuest/Features/Player/Views/MyPatternsView.swift
    - TimeQuest/Features/Player/ViewModels/MyPatternsViewModel.swift
  modified:
    - TimeQuest/Features/Player/Views/PlayerHomeView.swift
    - TimeQuest/Features/Player/Views/EstimationInputView.swift
    - TimeQuest/Features/Player/ViewModels/GameSessionViewModel.swift
    - generate-xcodeproj.js

key-decisions:
  - "Used InsightEngine.generateInsights() then grouped by routineName -- simpler than manual per-task analysis"
  - "MyPatternsViewModel takes only modelContext (not SessionRepository) matching ProgressionViewModel fetch pattern"
  - "Contextual hints preloaded synchronously in startQuest() for zero-latency display"
  - "Hint capsule styled identically to calibration banner (same padding, background, clipShape) for visual consistency"

patterns-established:
  - "InsightCardView as shared component: takes TaskInsight, renders bias/trend/consistency with curiosity framing"
  - "Contextual hint preloading: fetch all estimations once at quest start, generate hints for all tasks upfront"
  - "My Patterns navigation: placed above View Your Stats in PlayerHomeView for feature discoverability"

# Metrics
duration: 12min
completed: 2026-02-13
---

# Phase 4 Plan 2: Insight UI -- My Patterns + Contextual Hints Summary

**My Patterns screen with InsightCardView shared component showing per-task bias/trend/consistency insights, plus contextual reference hints in EstimationInputView preloaded at quest start**

## Performance

- **Duration:** 12 min
- **Started:** 2026-02-13T17:10:19Z
- **Completed:** 2026-02-13T17:23:09Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments
- InsightCardView shared component renders bias, trend, and consistency with curiosity-framed language
- MyPatternsView displays per-task insights grouped by routine with friendly empty state for new players
- Contextual reference hints ("Last 5 times: ~Xm Ys") appear during estimation for tasks with 5+ non-calibration sessions
- Hints preloaded at quest start for zero-latency display, skipped entirely during calibration
- Full project builds cleanly with all new files registered in Xcode project

## Task Commits

Each task was committed atomically:

1. **Task 1: Create InsightCardView shared component and MyPatternsViewModel** - `2242f31` (feat)
2. **Task 2: Create MyPatternsView and add navigation from PlayerHomeView** - `2fc4f32` (feat)
3. **Task 3: Add contextual hints to estimation flow and update build system** - `b738352` (feat)

**Plan metadata:** (pending)

## Files Created/Modified
- `TimeQuest/Features/Shared/Components/InsightCardView.swift` - Shared component displaying TaskInsight with bias/trend/consistency rows using curiosity framing
- `TimeQuest/Features/Player/ViewModels/MyPatternsViewModel.swift` - @MainActor @Observable ViewModel fetching estimations and generating insights grouped by routine
- `TimeQuest/Features/Player/Views/MyPatternsView.swift` - Patterns screen with ScrollView/LazyVStack grouped by routine, empty state for new players
- `TimeQuest/Features/Player/Views/PlayerHomeView.swift` - Added "My Patterns" NavigationLink above "View Your Stats"
- `TimeQuest/Features/Player/ViewModels/GameSessionViewModel.swift` - Added contextualHints dictionary, currentTaskHint computed property, preloading in startQuest()
- `TimeQuest/Features/Player/Views/EstimationInputView.swift` - Added lightbulb hint capsule between calibration banner and task name
- `generate-xcodeproj.js` - Registered InsightCardView, MyPatternsView, MyPatternsViewModel in source files and groups
- `TimeQuest/TimeQuest.xcodeproj/project.pbxproj` - Regenerated with new file references

## Decisions Made
- Used `InsightEngine.generateInsights()` composite function then grouped by `routineName` -- avoids duplicating per-task filtering logic that's already in the engine
- MyPatternsViewModel takes only `modelContext` (not `SessionRepository`) -- matches how `ProgressionViewModel.loadPersonalBests()` fetches `TaskEstimation` directly via `FetchDescriptor`
- Preloaded all hints synchronously in `startQuest()` rather than lazily per task -- the computation is trivially fast (filter + mean of 5-50 numbers) and guarantees hints are available before first estimation screen
- Hint capsule uses identical styling to calibration banner (`.padding(.horizontal, 12)`, `.padding(.vertical, 6)`, `.background(Color(.systemGray6))`, `.clipShape(Capsule())`) for visual consistency

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 4 is fully complete -- InsightEngine domain core (Plan 01) and Insight UI (Plan 02) both shipped
- All insight types available for Phase 6 WeeklyReflectionEngine to consume
- EstimationSnapshot bridge and InsightEngine are reusable without modification
- My Patterns screen provides the navigation foundation if future phases add deeper per-task drill-down views

## Self-Check: PASSED

All files exist, all commits verified:
- FOUND: TimeQuest/Features/Shared/Components/InsightCardView.swift
- FOUND: TimeQuest/Features/Player/ViewModels/MyPatternsViewModel.swift
- FOUND: TimeQuest/Features/Player/Views/MyPatternsView.swift
- FOUND: TimeQuest/Features/Player/Views/PlayerHomeView.swift
- FOUND: TimeQuest/Features/Player/ViewModels/GameSessionViewModel.swift
- FOUND: TimeQuest/Features/Player/Views/EstimationInputView.swift
- FOUND: generate-xcodeproj.js
- FOUND: 2242f31 (Task 1)
- FOUND: 2fc4f32 (Task 2)
- FOUND: b738352 (Task 3)

---
*Phase: 04-contextual-learning-insights*
*Completed: 2026-02-13*
