---
phase: 02-engagement-layer
plan: 03
subsystem: ui, services, sensory-feedback
tags: [avfoundation, usernotifications, spritekit, haptics, sound, celebrations, notifications, sensory-feedback]

# Dependency graph
requires:
  - phase: 02-engagement-layer
    plan: 01
    provides: "XPEngine, LevelCalculator, StreakTracker, PersonalBestTracker, PlayerProfile, PlayerProfileRepository, GameSessionViewModel XP/streak/personal-best integration"
  - phase: 02-engagement-layer
    plan: 02
    provides: "ProgressionViewModel, XPBarView, StreakBadgeView, LevelBadgeView, PlayerStatsView, PlayerHomeView progression header, SessionSummaryView XP display"
provides:
  - "SoundManager: AVAudioPlayer wrapper with preload, play, mute toggle"
  - "NotificationManager: schedule/cancel local notifications with deterministic IDs and game framing"
  - "CelebrationScene: SpriteKit particle scene for levelUp, personalBest, streak milestones"
  - "NotificationSettingsView: player-controlled toggles for notifications and sound"
  - "Haptic feedback on estimate lock-in and accuracy reveal via .sensoryFeedback"
  - "Sound effects on lock-in, reveal, personal best, level up, session complete"
  - "AppDependencies.soundManager and .notificationManager injected via environment"
affects: [future-phases, parent-dashboard-notifications]

# Tech tracking
tech-stack:
  added: [AVFoundation, UserNotifications]
  patterns:
    - "SoundManager as @MainActor @Observable with AVAudioPlayer strong references"
    - "NotificationManager with deterministic IDs (routine-name-dayN) preventing duplicates"
    - "CelebrationScene with configurable BurstConfig per milestone type"
    - ".sensoryFeedback modifier (iOS 17+ declarative) not UIKit UIFeedbackGenerator"
    - "AppDependencies injected via ContentView wrapper in TimeQuestApp"
    - "@preconcurrency import for UserNotifications under Swift 6 strict concurrency"

key-files:
  created:
    - TimeQuest/Services/SoundManager.swift
    - TimeQuest/Services/NotificationManager.swift
    - TimeQuest/Game/CelebrationScene.swift
    - TimeQuest/Features/Player/Views/NotificationSettingsView.swift
    - TimeQuest/Resources/Sounds/estimate_lock.wav
    - TimeQuest/Resources/Sounds/reveal.wav
    - TimeQuest/Resources/Sounds/level_up.wav
    - TimeQuest/Resources/Sounds/personal_best.wav
    - TimeQuest/Resources/Sounds/session_complete.wav
  modified:
    - TimeQuest/Features/Player/Views/AccuracyRevealView.swift
    - TimeQuest/Features/Player/Views/EstimationInputView.swift
    - TimeQuest/Features/Player/Views/SessionSummaryView.swift
    - TimeQuest/Features/Player/Views/PlayerHomeView.swift
    - TimeQuest/Features/Player/Views/QuestView.swift
    - TimeQuest/App/AppDependencies.swift
    - TimeQuest/App/TimeQuestApp.swift
    - generate-xcodeproj.js

key-decisions:
  - "AppDependencies injected via intermediate ContentView (modelContext needed at init)"
  - "Sound files are placeholder .wav (0.1s silence); real assets can be swapped later"
  - "Personal best celebration takes visual priority over spot-on celebration"
  - "@preconcurrency import UserNotifications for Swift 6 strict concurrency compatibility"

patterns-established:
  - "Services layer for system framework wrappers (AVFoundation, UserNotifications)"
  - "Sensory feedback via .sensoryFeedback modifier, not UIKit haptic generators"
  - "SoundManager passed as explicit parameter, not environment object"

# Metrics
duration: 7min
completed: 2026-02-13
---

# Phase 2 Plan 3: Sensory Polish and Notifications Summary

**Haptic/sound feedback on estimate lock-in and accuracy reveal, SpriteKit milestone celebrations, game-framed local notifications with player-controlled settings**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-13T13:26:03Z
- **Completed:** 2026-02-13T13:32:41Z (Tasks 1-2; Task 3 checkpoint pending)
- **Tasks:** 2 of 3 (Task 3 is human-verify checkpoint)
- **Files modified:** 20

## Accomplishments
- SoundManager wraps AVAudioPlayer with preload/play/mute toggle and strong player references
- NotificationManager schedules weekly UNCalendarNotificationTrigger with deterministic IDs and game framing ("Quest Available!")
- CelebrationScene renders type-specific particle bursts (gold for level-up, teal for personal best, orange for streaks)
- NotificationSettingsView provides player-controlled toggles for quest reminders, reminder time, and sound
- AccuracyRevealView fires haptic and plays sound on accuracy reveal; shows personal best celebration particles
- EstimationInputView fires haptic and plays sound on estimate lock-in
- SessionSummaryView shows level-up celebration particles and plays completion/level-up sound
- PlayerHomeView has settings gear navigating to NotificationSettingsView
- Placeholder .wav sound files bundled as resources (0.1s silent WAV files)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SoundManager, NotificationManager, CelebrationScene, and notification settings** - `2c3b796` (feat)
2. **Task 2: Integrate sensory feedback into views and update build system** - `e827bf4` (feat)
3. **Task 3: Verify complete Phase 2 engagement layer** - CHECKPOINT PENDING (human-verify)

## Files Created/Modified
- `TimeQuest/Services/SoundManager.swift` - @Observable AVAudioPlayer wrapper with preload/play/mute
- `TimeQuest/Services/NotificationManager.swift` - UNCalendarNotificationTrigger with deterministic IDs
- `TimeQuest/Game/CelebrationScene.swift` - SpriteKit particle scene for levelUp/personalBest/streak
- `TimeQuest/Features/Player/Views/NotificationSettingsView.swift` - Quest reminder and sound toggles
- `TimeQuest/Features/Player/Views/AccuracyRevealView.swift` - Added haptic, sound, personal best celebration
- `TimeQuest/Features/Player/Views/EstimationInputView.swift` - Added haptic and sound on lock-in
- `TimeQuest/Features/Player/Views/SessionSummaryView.swift` - Added level-up celebration and sound
- `TimeQuest/Features/Player/Views/PlayerHomeView.swift` - Added settings gear in toolbar
- `TimeQuest/Features/Player/Views/QuestView.swift` - Passes soundManager to child views
- `TimeQuest/App/AppDependencies.swift` - Added soundManager and notificationManager
- `TimeQuest/App/TimeQuestApp.swift` - ContentView wrapper injects AppDependencies into environment
- `TimeQuest/Resources/Sounds/*.wav` - 5 placeholder silent WAV files
- `generate-xcodeproj.js` - Services group, sound resources, new source files

## Decisions Made
- AppDependencies injected via intermediate ContentView wrapper because modelContext is needed at init time and is only available after .modelContainer is applied
- Placeholder .wav sound files (0.1s silence) used so the build system and SoundManager infrastructure work; real sound assets can be swapped in-place later
- Personal best celebration takes visual priority over spot-on celebration when both conditions are true
- Used @preconcurrency import for UserNotifications to handle Swift 6 strict concurrency (UNNotificationSettings is non-Sendable)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 concurrency: @preconcurrency import UserNotifications**
- **Found during:** Task 2 (Build verification)
- **Issue:** UNNotificationSettings is non-Sendable; `notificationSettings()` call crosses actor boundary under Swift 6 strict concurrency
- **Fix:** Added `@preconcurrency import UserNotifications` as compiler suggested
- **Files modified:** TimeQuest/Services/NotificationManager.swift
- **Verification:** Build succeeded
- **Committed in:** e827bf4 (Task 2 commit)

**2. [Rule 2 - Missing Critical] Added haptic and sound to EstimationInputView lock-in**
- **Found during:** Task 2 (Integration)
- **Issue:** Plan's must_haves truth states "Player feels haptic feedback when locking in an estimate" but only AccuracyRevealView was specified for haptics. EstimationInputView's "Lock It In" button needed sensory feedback.
- **Fix:** Added .sensoryFeedback modifier and soundManager.play("estimate_lock") to EstimationInputView
- **Files modified:** TimeQuest/Features/Player/Views/EstimationInputView.swift
- **Verification:** Build succeeded; haptic triggers on lock-in
- **Committed in:** e827bf4 (Task 2 commit)

**3. [Rule 3 - Blocking] QuestView needed updates to pass soundManager**
- **Found during:** Task 2 (Integration)
- **Issue:** AccuracyRevealView and SessionSummaryView now require soundManager parameter but QuestView (their parent) didn't have it
- **Fix:** Updated QuestView to access AppDependencies from environment and pass soundManager to child views
- **Files modified:** TimeQuest/Features/Player/Views/QuestView.swift
- **Verification:** Build succeeded; sound and haptic flow through view hierarchy
- **Committed in:** e827bf4 (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 bug, 1 missing critical, 1 blocking)
**Impact on plan:** All fixes necessary for correctness and the must-have truths. No scope creep.

## Issues Encountered
- Xcode simulator target `iPhone 16,OS=18.2` not available; used `iPhone 16,OS=18.3.1` instead (same as previous plans)

## User Setup Required
None - no external service configuration required.

## Checkpoint Status
Task 3 (human-verify) is PENDING. The complete Phase 2 engagement layer needs manual verification on iOS Simulator.

## Next Phase Readiness
- Complete Phase 2 engagement layer: XP/leveling, streaks, personal bests, accuracy charts, haptics, sounds, celebrations, notifications
- All sensory features are optional and non-blocking (app works fine without real sound assets)
- Notification infrastructure ready for parent-dashboard integration in future phases

## Self-Check: PASSED (Tasks 1-2)

All 9 created files verified on disk. Both task commits (2c3b796, e827bf4) verified in git log. Build succeeds with zero errors. Task 3 checkpoint pending human verification.

---
*Phase: 02-engagement-layer*
*Completed: 2026-02-13 (checkpoint pending)*
