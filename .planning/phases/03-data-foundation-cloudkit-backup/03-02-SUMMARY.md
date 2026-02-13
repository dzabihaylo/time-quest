---
phase: 03-data-foundation-cloudkit-backup
plan: 02
subsystem: database
tags: [cloudkit, swiftdata, icloud-backup, sync-monitor, entitlements, migration, swift6-concurrency]

# Dependency graph
requires:
  - phase: 03-data-foundation-cloudkit-backup
    plan: 01
    provides: "TimeQuestSchemaV2 with cloudID on all models, TimeQuestMigrationPlan, typealias pattern"
provides:
  - "CloudKitSyncMonitor -- observable sync status via NSPersistentCloudKitContainer events"
  - "ModelContainer init with migration plan + cloudKitDatabase: .automatic"
  - "cloudID-based repository queries (SessionRepository)"
  - "PlayerProfile singleton deduplication with sentinel cloudID pattern"
  - "iCloud Backup status section in settings UI"
  - "Entitlements file with iCloud + CloudKit + APS keys"
  - "CODE_SIGN_ENTITLEMENTS + UIBackgroundModes in build settings"
affects: [phase-04, phase-05, phase-06]

# Tech tracking
tech-stack:
  added: [CloudKit, NSPersistentCloudKitContainer, CKContainer, ModelConfiguration.cloudKitDatabase]
  patterns: [cloudkit-sync-monitor, sentinel-cloudid-deduplication, nonisolated-unsafe-for-observer, preconcurrency-import-coredata]

key-files:
  created:
    - TimeQuest/Services/CloudKitSyncMonitor.swift
    - TimeQuest/TimeQuest.entitlements
  modified:
    - TimeQuest/App/TimeQuestApp.swift
    - TimeQuest/App/AppDependencies.swift
    - TimeQuest/Repositories/SessionRepository.swift
    - TimeQuest/Repositories/PlayerProfileRepository.swift
    - TimeQuest/Features/Player/Views/NotificationSettingsView.swift
    - TimeQuest/Features/Player/Views/PlayerHomeView.swift
    - generate-xcodeproj.js

key-decisions:
  - "Used nonisolated(unsafe) for CloudKitSyncMonitor.observer to allow deinit access in Swift 6"
  - "Used @preconcurrency import CoreData to suppress NSPersistentCloudKitContainer.Event Sendable warnings"
  - "Extract event data before Task boundary to avoid sending non-Sendable Notification across isolation"
  - "CODE_SIGN_ENTITLEMENTS path relative to project dir (TimeQuest.entitlements not TimeQuest/TimeQuest.entitlements)"

patterns-established:
  - "CloudKit sync monitoring: @Observable class wrapping NSPersistentCloudKitContainer.eventChangedNotification"
  - "Singleton deduplication: sentinel cloudID with merge-on-fetch for CloudKit multi-device conflicts"
  - "cloudID-based predicates: all cross-model queries use cloudID instead of persistentModelID"

# Metrics
duration: 5min
completed: 2026-02-13
---

# Phase 3 Plan 2: CloudKit Backup Summary

**CloudKit-enabled ModelContainer with sync monitor, cloudID-based queries, PlayerProfile deduplication, and iCloud backup status in settings UI**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-13T15:31:07Z
- **Completed:** 2026-02-13T15:35:46Z
- **Tasks:** 2 of 2 auto tasks (checkpoint pending)
- **Files modified:** 10

## Accomplishments
- ModelContainer initializes with TimeQuestMigrationPlan and cloudKitDatabase: .automatic for automatic iCloud sync
- CloudKitSyncMonitor tracks sync events via NSPersistentCloudKitContainer.eventChangedNotification with CKContainer account status checking
- SessionRepository uses cloudID-based predicates instead of persistentModelID for CloudKit-safe queries
- PlayerProfileRepository uses sentinel cloudID "singleton-player-profile" with full deduplication merge logic
- Settings UI shows "iCloud Backup" section with dynamic status icon and text (synced/syncing/error/no account)
- Entitlements file configured with iCloud + CloudKit services + APS environment
- Build system updated with CODE_SIGN_ENTITLEMENTS and UIBackgroundModes for remote notifications

## Task Commits

Each task was committed atomically:

1. **Task 1: Create entitlements, sync monitor, update app init + repositories** - `81a0b09` (feat)
2. **Task 2: Add backup status to settings UI + update build system** - `9df4707` (feat)

## Files Created/Modified
- `TimeQuest/TimeQuest.entitlements` - iCloud + CloudKit + APS entitlements plist
- `TimeQuest/Services/CloudKitSyncMonitor.swift` - Observable sync status monitor using NSPersistentCloudKitContainer events
- `TimeQuest/App/TimeQuestApp.swift` - Explicit ModelContainer init with migration plan + CloudKit config
- `TimeQuest/App/AppDependencies.swift` - Added CloudKitSyncMonitor dependency with startMonitoring()
- `TimeQuest/Repositories/SessionRepository.swift` - cloudID-based predicate for routine sessions query
- `TimeQuest/Repositories/PlayerProfileRepository.swift` - Sentinel cloudID deduplication with merge logic
- `TimeQuest/Features/Player/Views/NotificationSettingsView.swift` - iCloud Backup section with sync status display
- `TimeQuest/Features/Player/Views/PlayerHomeView.swift` - Updated call site to pass syncMonitor
- `generate-xcodeproj.js` - Entitlements file ref, CloudKitSyncMonitor source, CODE_SIGN_ENTITLEMENTS, UIBackgroundModes

## Decisions Made
- Used `nonisolated(unsafe)` for observer property (Swift 6 requires this for deinit access to @MainActor properties)
- Used `@preconcurrency import CoreData` to suppress NSPersistentCloudKitContainer.Event Sendable warnings
- Extracted event data (endDate, errorMessage) before Task boundary to avoid sending non-Sendable Notification across isolation
- CODE_SIGN_ENTITLEMENTS path is relative to project directory, not repo root

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added CloudKitSyncMonitor to build system in Task 1**
- **Found during:** Task 1 (build verification)
- **Issue:** CloudKitSyncMonitor.swift was created but not registered in generate-xcodeproj.js, so AppDependencies.swift could not find the type
- **Fix:** Added CloudKitSyncMonitor.swift to sourceFiles array and Services group in generate-xcodeproj.js during Task 1 (plan had this in Task 2)
- **Files modified:** generate-xcodeproj.js
- **Verification:** Clean build succeeds
- **Committed in:** 81a0b09 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed Swift 6 strict concurrency error in CloudKitSyncMonitor deinit**
- **Found during:** Task 1 (build verification)
- **Issue:** `observer` property on @MainActor class cannot be accessed from nonisolated `deinit`
- **Fix:** Added `nonisolated(unsafe)` modifier to observer property
- **Files modified:** CloudKitSyncMonitor.swift
- **Verification:** Clean build succeeds
- **Committed in:** 81a0b09 (Task 1 commit)

**3. [Rule 1 - Bug] Fixed Sendable violation in CloudKitSyncMonitor notification handler**
- **Found during:** Task 1 (build verification)
- **Issue:** Notification (non-Sendable) was being captured and sent into @MainActor Task, violating Swift 6 strict concurrency
- **Fix:** Extracted event.endDate and event.error?.localizedDescription as Sendable values before the Task boundary
- **Files modified:** CloudKitSyncMonitor.swift
- **Verification:** Clean build succeeds
- **Committed in:** 81a0b09 (Task 1 commit)

**4. [Rule 1 - Bug] Fixed CODE_SIGN_ENTITLEMENTS path**
- **Found during:** Task 2 (build verification)
- **Issue:** Path `TimeQuest/TimeQuest.entitlements` resolved to double-nested path since project is already inside TimeQuest/
- **Fix:** Changed to `TimeQuest.entitlements` (relative to project directory)
- **Files modified:** generate-xcodeproj.js
- **Verification:** Build succeeds, entitlements processed correctly
- **Committed in:** 9df4707 (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (3 bugs -- Swift 6 concurrency + path resolution, 1 blocking -- build system ordering)
**Impact on plan:** All auto-fixes necessary for compilation. No scope creep. The Swift 6 concurrency issues were anticipated by the plan notes.

## Issues Encountered
- Swift 6 strict concurrency continues to require careful handling of @MainActor classes, particularly around deinit and closure capture across isolation boundaries
- CODE_SIGN_ENTITLEMENTS path must be relative to the Xcode project directory, not the repository root

## User Setup Required
CloudKit container must be registered with Apple Developer account:
1. Open project in Xcode
2. Go to Target -> Signing & Capabilities -> + Capability -> iCloud
3. Check CloudKit checkbox
4. Create or select container "iCloud.com.timequest.app"

## Next Phase Readiness
- Complete CloudKit backup infrastructure in place
- All v1.0 features continue working via typealias pattern
- Pending human verification: settings UI visual check + CloudKit container setup in Xcode
- After verification: ready for Phase 4 (Insight Engine)

## Self-Check: PASSED

All files verified present. Both commit hashes (81a0b09, 9df4707) confirmed in git log.

---
*Phase: 03-data-foundation-cloudkit-backup*
*Completed: 2026-02-13*
