# Phase 3: Data Foundation + CloudKit Backup - Research

**Researched:** 2026-02-13
**Domain:** SwiftData schema versioning, CloudKit integration, data migration
**Confidence:** HIGH (core patterns well-documented, codebase fully analyzed)

## Summary

Phase 3 upgrades the TimeQuest app from a local-only SwiftData store to a CloudKit-backed backup system. This involves three tightly coupled workstreams: (1) retroactively versioning the existing schema as V1, (2) creating a V2 schema that adds CloudKit-compatible defaults and `cloudID` properties to all five models, and (3) enabling CloudKit sync with entitlements, ModelConfiguration, and a backup status indicator.

The codebase analysis reveals several models with non-optional properties lacking defaults (`Routine.name`, `Routine.displayName`, `RoutineTask.name`, `RoutineTask.displayName`, `TaskEstimation.taskDisplayName`, `TaskEstimation.estimatedSeconds`, `TaskEstimation.actualSeconds`, `TaskEstimation.differenceSeconds`, `TaskEstimation.accuracyPercent`, `TaskEstimation.ratingRawValue`, `GameSession.startedAt`, `GameSession.isCalibration`, `RoutineTask.orderIndex`, `TaskEstimation.orderIndex`). These all need defaults for CloudKit compatibility. The `SessionRepository` uses `persistentModelID` in predicates, which must migrate to a stable `cloudID` property. The build system (`generate-xcodeproj.js`) must be updated to register new files and add entitlements.

A critical constraint discovered during research: **custom migrations crash when CloudKit is enabled** (known Apple issue). Since this app targets iOS 17.0+, all migrations MUST use lightweight stages only. This is achievable because the V1-to-V2 changes (adding optional/defaulted properties) are inherently lightweight.

**Primary recommendation:** Use a two-step versioning approach -- retroactive V1 capturing current schema exactly, lightweight migration to V2 that adds `cloudID: String` (defaulting to `UUID().uuidString`) and ensures all properties have defaults. Enable CloudKit via `ModelConfiguration(cloudKitDatabase: .automatic)`. Build a hand-rolled sync monitor using `NSPersistentCloudKitContainer.eventChangedNotification` (no third-party dependencies needed).

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftData | iOS 17.0+ | ORM/persistence layer | Already in use; native Apple framework |
| CloudKit | iOS 17.0+ | iCloud backup/sync | Only Apple-supported cloud sync for SwiftData |
| VersionedSchema | iOS 17.0+ | Schema version tracking | Required protocol for SwiftData migrations |
| SchemaMigrationPlan | iOS 17.0+ | Migration orchestration | Required protocol for defining migration stages |
| ModelConfiguration | iOS 17.0+ | Container configuration | Provides `.cloudKitDatabase` parameter for CloudKit |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| CKContainer | iOS 17.0+ | iCloud account status check | Checking if iCloud is available before showing status |
| NSPersistentCloudKitContainer.Event | iOS 14.0+ | Sync event monitoring | Tracking import/export/setup completion for status UI |
| NotificationCenter | Foundation | Event subscription | Listening to CloudKit sync events and account changes |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled sync monitor | CloudKitSyncMonitor SPM package | Project uses Node-based build system (generate-xcodeproj.js), not SPM. Adding SPM dependency adds complexity. The needed functionality is ~100 lines of code. Hand-roll is simpler. |
| `cloudKitDatabase: .automatic` | CKSyncEngine | CKSyncEngine is for apps needing fine-grained control. Automatic is correct for simple backup use case. |
| Lightweight migration only | Custom migration stages | Custom migrations crash with CloudKit on iOS 17.x (FB13694972). Lightweight only is the safe path. |

**Installation:** No new dependencies needed. All components are Apple frameworks already available.

## Architecture Patterns

### Recommended File Structure
```
TimeQuest/
├── Models/
│   ├── Schemas/
│   │   ├── TimeQuestSchemaV1.swift    # Retroactive V1 (exact current models)
│   │   └── TimeQuestSchemaV2.swift    # V2 with defaults + cloudID
│   ├── Migration/
│   │   └── TimeQuestMigrationPlan.swift  # Lightweight V1->V2
│   ├── Routine.swift          # Typealias to V2 (updated)
│   ├── RoutineTask.swift      # Typealias to V2 (updated)
│   ├── GameSession.swift      # Typealias to V2 (updated)
│   ├── TaskEstimation.swift   # Typealias to V2 (updated)
│   └── PlayerProfile.swift    # Typealias to V2 (updated)
├── Services/
│   └── CloudKitSyncMonitor.swift  # Sync status tracking
└── App/
    └── TimeQuestApp.swift     # Updated ModelContainer init
```

### Pattern 1: Retroactive VersionedSchema (V1)
**What:** Wrap existing model definitions exactly as-is inside a VersionedSchema enum, establishing the baseline.
**When to use:** When a shipped app has never used VersionedSchema and needs to introduce versioning.
**Confidence:** HIGH (verified pattern from Donny Wals, Hacking with Swift, Atomic Robot)
```swift
// Source: https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/
enum TimeQuestSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Routine.self, RoutineTask.self, GameSession.self,
         TaskEstimation.self, PlayerProfile.self]
    }

    @Model final class Routine {
        var name: String
        var displayName: String
        var activeDays: [Int]
        var isActive: Bool
        var createdAt: Date
        var updatedAt: Date
        @Relationship(deleteRule: .cascade, inverse: \RoutineTask.routine)
        var tasks: [RoutineTask] = []
        @Relationship(deleteRule: .cascade, inverse: \GameSession.routine)
        var sessions: [GameSession] = []
        // ... init matches current exactly
    }
    // ... all 5 models, identical to current code
}
```

### Pattern 2: V2 Schema with CloudKit Defaults + cloudID
**What:** Add `cloudID: String = UUID().uuidString` to all models, add property-level defaults to all non-optional properties.
**When to use:** V2 schema definition for CloudKit compatibility.
**Confidence:** HIGH (CloudKit default requirement verified across multiple sources)
```swift
enum TimeQuestSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Routine.self, RoutineTask.self, GameSession.self,
         TaskEstimation.self, PlayerProfile.self]
    }

    @Model final class Routine {
        var cloudID: String = UUID().uuidString  // NEW: stable ID
        var name: String = ""                     // NEW: default added
        var displayName: String = ""              // NEW: default added
        var activeDays: [Int] = []
        var isActive: Bool = true
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        @Relationship(deleteRule: .cascade, inverse: \RoutineTask.routine)
        var tasks: [RoutineTask] = []
        @Relationship(deleteRule: .cascade, inverse: \GameSession.routine)
        var sessions: [GameSession] = []
        // init still takes parameters for creation
    }
    // ... all 5 models with defaults on every property
}

// Typealiases so rest of app uses current version
typealias Routine = TimeQuestSchemaV2.Routine
```

### Pattern 3: Lightweight-Only Migration Plan
**What:** SchemaMigrationPlan with only lightweight stages (no custom willMigrate/didMigrate).
**When to use:** ALWAYS when CloudKit is enabled. Custom migrations crash with CloudKit on iOS 17.x.
**Confidence:** HIGH (crash confirmed by Apple forum reports, FB13694972)
```swift
// Source: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema
enum TimeQuestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TimeQuestSchemaV1.self, TimeQuestSchemaV2.self]
    }
    static var stages: [MigrationStage] {
        [v1ToV2]
    }
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV1.self,
        toVersion: TimeQuestSchemaV2.self
    )
}
```

### Pattern 4: ModelContainer with Migration + CloudKit
**What:** Initialize ModelContainer with both a migration plan and CloudKit configuration.
**When to use:** App entry point, replacing the current `.modelContainer(for:)` modifier.
**Confidence:** HIGH
```swift
// Source: https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-8s4ts
@main
struct TimeQuestApp: App {
    let container: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(
                cloudKitDatabase: .automatic
            )
            container = try ModelContainer(
                for: TimeQuestSchemaV2.Routine.self,
                     TimeQuestSchemaV2.RoutineTask.self,
                     TimeQuestSchemaV2.GameSession.self,
                     TimeQuestSchemaV2.TaskEstimation.self,
                     TimeQuestSchemaV2.PlayerProfile.self,
                migrationPlan: TimeQuestMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
```

### Pattern 5: Lightweight Sync Monitor (No Third-Party)
**What:** Use NSPersistentCloudKitContainer.eventChangedNotification + CKAccountStatus to track sync state.
**When to use:** Backup status indicator in settings screen.
**Confidence:** HIGH (API verified via Apple docs and CloudKitSyncMonitor reference implementation)
```swift
// Source: https://github.com/ggruen/CloudKitSyncMonitor (pattern reference)
@MainActor @Observable
final class CloudKitSyncMonitor {
    enum SyncStatus {
        case notStarted, syncing, synced(Date), error(String), noAccount
    }

    var status: SyncStatus = .notStarted

    func startMonitoring() {
        // Listen for sync events
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            if event.endDate != nil {
                if event.error != nil {
                    self?.status = .error("Sync failed")
                } else {
                    self?.status = .synced(event.endDate ?? Date())
                }
            } else {
                self?.status = .syncing
            }
        }

        // Check iCloud account status
        Task {
            let accountStatus = try? await CKContainer.default().accountStatus()
            if accountStatus != .available {
                self.status = .noAccount
            }
        }
    }
}
```

### Pattern 6: cloudID-Based Repository Queries
**What:** Replace `persistentModelID` predicates with `cloudID` String predicates.
**When to use:** Any repository method that queries by model identity (currently `SessionRepository.fetchSessions(for:)`).
**Confidence:** HIGH (persistentModelID instability with CloudKit is well-documented)
```swift
// BEFORE (current code - breaks with CloudKit):
func fetchSessions(for routine: Routine) -> [GameSession] {
    let routineID = routine.persistentModelID
    let descriptor = FetchDescriptor<GameSession>(
        predicate: #Predicate { $0.routine?.persistentModelID == routineID }
    )
    return (try? modelContext.fetch(descriptor)) ?? []
}

// AFTER (cloudID-based):
func fetchSessions(for routine: Routine) -> [GameSession] {
    let routineCloudID = routine.cloudID
    let descriptor = FetchDescriptor<GameSession>(
        predicate: #Predicate { $0.routine?.cloudID == routineCloudID }
    )
    return (try? modelContext.fetch(descriptor)) ?? []
}
```

### Anti-Patterns to Avoid
- **Custom migration stages with CloudKit:** Crashes on iOS 17.x. Use lightweight only.
- **`@Attribute(.unique)` with CloudKit:** CloudKit does not support unique constraints. Will silently fail to sync.
- **Non-optional relationships:** All relationships MUST be optional for CloudKit. This is already correct in the current codebase (all relationships use `?`).
- **Ordered relationships:** CloudKit does not support ordered relationships. The current codebase correctly uses `orderIndex` properties instead.
- **Relying on `persistentModelID` for identity:** Changes during object lifecycle and is not stable across CloudKit sync. Use a custom `cloudID` property.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Schema migration | Custom SQLite manipulation | SwiftData VersionedSchema + SchemaMigrationPlan | Framework handles migration path detection, rollback, data integrity |
| CloudKit sync engine | Custom CKRecord management | ModelConfiguration(cloudKitDatabase: .automatic) | Apple handles conflict resolution, delta sync, retry logic |
| Sync monitoring (complex) | Full-featured sync dashboard | Simple ~100 LOC monitor on eventChangedNotification | This is a backup app, not a collaboration tool. Simple "synced/syncing/error" is sufficient |
| UUID generation for cloudID | Sequential ID scheme | `UUID().uuidString` as default value | UUIDs are globally unique, no coordination needed |

**Key insight:** SwiftData + CloudKit is designed to be declarative -- you describe the schema and the framework handles sync. The less custom sync code, the fewer bugs. The only hand-rolled piece should be the thin sync status monitor.

## Common Pitfalls

### Pitfall 1: Custom Migrations Crash with CloudKit
**What goes wrong:** `ModelContainer` init crashes (not catchable) when using `MigrationStage.custom()` with CloudKit enabled on iOS 17.x.
**Why it happens:** Apple acknowledged as intended behavior -- CloudKit requires lightweight migration (same as Core Data). Tracked as FB13694972.
**How to avoid:** Use ONLY `MigrationStage.lightweight()` stages. Design V2 schema so all changes are lightweight-compatible (add properties with defaults, no renames without `@Attribute(originalName:)`, no type changes).
**Warning signs:** App crash on launch after schema update, with no catchable error.

### Pitfall 2: Missing Defaults Cause Silent Sync Failure
**What goes wrong:** CloudKit sync silently fails. No error in UI, but data never reaches iCloud. Xcode console shows warnings.
**Why it happens:** CloudKit requires all properties to be optional or have defaults. Non-optional properties without defaults block sync.
**How to avoid:** Audit EVERY property on ALL models. Add explicit default values. The current codebase has 14+ properties needing defaults (see property audit below).
**Warning signs:** Look for CloudKit warnings in Xcode console at very top of log output.

### Pitfall 3: Retroactive V1 Schema Mismatch
**What goes wrong:** Migration fails or crashes because V1 VersionedSchema definition doesn't exactly match the actual on-disk schema.
**Why it happens:** The V1 enum must mirror the current models byte-for-byte (same property names, types, relationships, defaults). Any mismatch and SwiftData can't identify the on-disk schema.
**How to avoid:** Copy current model code directly into V1 enum. Don't "clean up" or change anything. Verify the V1 definitions match the current models exactly.
**Warning signs:** Crash on first launch after update.

### Pitfall 4: PlayerProfile Singleton Duplication
**What goes wrong:** After CloudKit sync, multiple PlayerProfile instances exist (one from each device/reinstall), breaking the `fetchOrCreate()` singleton pattern.
**Why it happens:** CloudKit creates new records on sync, and without `@Attribute(.unique)` (which CloudKit forbids), there's no deduplication.
**How to avoid:** Use a sentinel `cloudID` pattern -- PlayerProfile gets a well-known fixed `cloudID` (e.g., `"singleton-player-profile"`). On fetch, if multiple exist, keep the one with the sentinel ID and merge/delete duplicates. Alternatively, since this is single-device backup (not multi-device sync), duplicates are unlikely but should be handled defensively.
**Warning signs:** Stats showing double XP, incorrect streak counts after restore.

### Pitfall 5: Entitlements Not Configured in Build System
**What goes wrong:** CloudKit sync doesn't start. No errors in code, but CKAccountStatus may show issues.
**Why it happens:** The `generate-xcodeproj.js` build system doesn't currently generate an entitlements file or set `CODE_SIGN_ENTITLEMENTS` build setting.
**How to avoid:** Create `TimeQuest.entitlements` file with iCloud + CloudKit keys. Update `generate-xcodeproj.js` to reference the entitlements file in build settings. Add the entitlements file to the PBXFileReference section.
**Warning signs:** Build succeeds but CloudKit console shows no activity.

### Pitfall 6: Default Values in Init vs Property-Level Defaults
**What goes wrong:** Lightweight migration adds new properties but existing rows get nil/zero instead of the expected default.
**Why it happens:** Default values in Swift `init` parameters are not the same as SwiftData property-level defaults. For migration and CloudKit, the property declaration itself must have the default (e.g., `var name: String = ""`).
**How to avoid:** Always use property-level defaults (`var x: Type = default`), not just init parameter defaults.
**Warning signs:** Existing data shows empty strings or zeros after migration for properties that "should" have values.

## Code Examples

### Current Model Property Audit (Properties Needing Defaults)

**Routine:**
| Property | Current | Needs | Action |
|----------|---------|-------|--------|
| `name: String` | No default | `= ""` | Add default |
| `displayName: String` | No default | `= ""` | Add default |
| `activeDays: [Int]` | Has default `= []` | OK | None |
| `isActive: Bool` | Has default (init only) | `= true` | Add property-level default |
| `createdAt: Date` | Has default (init only) | `= Date.now` | Add property-level default |
| `updatedAt: Date` | Has default (init only) | `= Date.now` | Add property-level default |
| NEW `cloudID: String` | N/A | `= UUID().uuidString` | Add property |

**RoutineTask:**
| Property | Current | Needs | Action |
|----------|---------|-------|--------|
| `name: String` | No default | `= ""` | Add default |
| `displayName: String` | No default | `= ""` | Add default |
| `referenceDurationSeconds: Int?` | Optional | OK | None |
| `orderIndex: Int` | No default | `= 0` | Add default |
| `routine: Routine?` | Optional | OK | None |
| NEW `cloudID: String` | N/A | `= UUID().uuidString` | Add property |

**GameSession:**
| Property | Current | Needs | Action |
|----------|---------|-------|--------|
| `routine: Routine?` | Optional | OK | None |
| `startedAt: Date` | No default | `= Date.now` | Add default |
| `completedAt: Date?` | Optional | OK | None |
| `isCalibration: Bool` | No default | `= false` | Add default |
| `xpEarned: Int` | Has default `= 0` | OK | None |
| NEW `cloudID: String` | N/A | `= UUID().uuidString` | Add property |

**TaskEstimation:**
| Property | Current | Needs | Action |
|----------|---------|-------|--------|
| `taskDisplayName: String` | No default | `= ""` | Add default |
| `estimatedSeconds: Double` | No default | `= 0` | Add default |
| `actualSeconds: Double` | No default | `= 0` | Add default |
| `differenceSeconds: Double` | No default | `= 0` | Add default |
| `accuracyPercent: Double` | No default | `= 0` | Add default |
| `ratingRawValue: String` | No default | `= "way_off"` | Add default |
| `orderIndex: Int` | No default | `= 0` | Add default |
| `recordedAt: Date` | Has default (init only) | `= Date.now` | Add property-level default |
| `session: GameSession?` | Optional | OK | None |
| NEW `cloudID: String` | N/A | `= UUID().uuidString` | Add property |

**PlayerProfile:**
| Property | Current | Needs | Action |
|----------|---------|-------|--------|
| `totalXP: Int` | Has default `= 0` | OK | None |
| `currentStreak: Int` | Has default `= 0` | OK | None |
| `lastPlayedDate: Date?` | Optional | OK | None |
| `notificationsEnabled: Bool` | Has default `= true` | OK | None |
| `notificationHour: Int` | Has default `= 7` | OK | None |
| `notificationMinute: Int` | Has default `= 30` | OK | None |
| `soundEnabled: Bool` | Has default `= true` | OK | None |
| `createdAt: Date` | Has default `= Date.now` | OK | None |
| NEW `cloudID: String` | N/A | `= UUID().uuidString` | Add property |

**Summary:** PlayerProfile is already CloudKit-ready (all defaults present). The other 4 models need property-level defaults added plus the new `cloudID` property.

### Entitlements File Content
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.timequest.app</string>
    </array>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```

### Build System Updates Required (generate-xcodeproj.js)

The following must be added to `generate-xcodeproj.js`:

1. **New source files** to the `sourceFiles` array:
   - `TimeQuestSchemaV1.swift` (path: `Models/Schemas/TimeQuestSchemaV1.swift`)
   - `TimeQuestSchemaV2.swift` (path: `Models/Schemas/TimeQuestSchemaV2.swift`)
   - `TimeQuestMigrationPlan.swift` (path: `Models/Migration/TimeQuestMigrationPlan.swift`)
   - `CloudKitSyncMonitor.swift` (path: `Services/CloudKitSyncMonitor.swift`)

2. **New group entries** for `Schemas` and `Migration` sub-groups under `Models`.

3. **Entitlements file reference** added to PBXFileReference section.

4. **`CODE_SIGN_ENTITLEMENTS`** build setting added to both Debug and Release target configurations, pointing to `TimeQuest.entitlements`.

5. **Background Modes** added via `UIBackgroundModes` with `remote-notification` in Info.plist keys.

### PlayerProfile Singleton Deduplication Pattern
```swift
// Source: pattern derived from Apple Developer Forums thread/745329
func fetchOrCreate() -> PlayerProfile {
    let descriptor = FetchDescriptor<PlayerProfile>(
        sortBy: [SortDescriptor(\.createdAt)]
    )
    let allProfiles = (try? modelContext.fetch(descriptor)) ?? []

    if allProfiles.isEmpty {
        let profile = PlayerProfile()
        profile.cloudID = "singleton-player-profile"
        modelContext.insert(profile)
        return profile
    }

    // Deduplication: keep the first, delete extras
    let keeper = allProfiles[0]
    if keeper.cloudID != "singleton-player-profile" {
        keeper.cloudID = "singleton-player-profile"
    }
    for extra in allProfiles.dropFirst() {
        // Merge XP, keep higher streak, etc.
        keeper.totalXP = max(keeper.totalXP, extra.totalXP)
        keeper.currentStreak = max(keeper.currentStreak, extra.currentStreak)
        if let extraDate = extra.lastPlayedDate,
           let keeperDate = keeper.lastPlayedDate,
           extraDate > keeperDate {
            keeper.lastPlayedDate = extraDate
        }
        modelContext.delete(extra)
    }
    try? modelContext.save()
    return keeper
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSPersistentCloudKitContainer (Core Data) | SwiftData ModelConfiguration(cloudKitDatabase:) | iOS 17 / WWDC 2023 | Declarative CloudKit setup, no manual CKRecord management |
| Unversioned models | VersionedSchema + SchemaMigrationPlan | iOS 17 / WWDC 2023 | Required for non-trivial schema changes |
| Custom migration with CloudKit | Lightweight-only migration | iOS 17.4 crash confirmed | Custom stages crash with CloudKit. Apple says "intended" |
| Model inheritance workarounds | @Model class inheritance | iOS 26 / WWDC 2025 | Not relevant for iOS 17 target, but future consideration |

**Deprecated/outdated:**
- Core Data `NSManagedObject` + `NSPersistentCloudKitContainer` directly: Still works but SwiftData wraps it. Use SwiftData APIs.
- `@Attribute(.unique)`: Cannot be used with CloudKit. Must remove any unique constraints.

## Open Questions

1. **Lightweight migration + cloudID population for existing rows**
   - What we know: Adding `var cloudID: String = UUID().uuidString` as a lightweight migration should auto-populate existing rows with unique UUIDs via the default value expression.
   - What's unclear: Whether SwiftData evaluates `UUID().uuidString` once (same UUID for all existing rows) or per-row during lightweight migration. With Core Data, default values from the model are used per-row, but SwiftData behavior may differ.
   - Recommendation: Test this during implementation. If all rows get the same UUID, add a post-migration fixup in the app's first launch that re-generates unique cloudIDs for any duplicates. This can be done in app code (not migration stage) to avoid the custom migration crash.
   - Confidence: MEDIUM

2. **generate-xcodeproj.js entitlements integration**
   - What we know: The build script needs `CODE_SIGN_ENTITLEMENTS` and the entitlements file reference. The current script generates build settings in the target configuration sections.
   - What's unclear: Whether simply adding the build setting is sufficient or if the entitlements file also needs an Xcode-managed capability registration (which would require Xcode UI interaction).
   - Recommendation: Add `CODE_SIGN_ENTITLEMENTS = TimeQuest/TimeQuest.entitlements` to the target build settings. The developer will need to configure their Apple Developer account's CloudKit container via the CloudKit Dashboard or Xcode Signing & Capabilities (one-time manual step).
   - Confidence: MEDIUM

3. **NSPersistentCloudKitContainer.Event availability with SwiftData**
   - What we know: SwiftData uses NSPersistentCloudKitContainer under the hood when CloudKit is enabled. The eventChangedNotification is documented for NSPersistentCloudKitContainer.
   - What's unclear: Whether SwiftData's automatic container management triggers these notifications identically to when using NSPersistentCloudKitContainer directly.
   - Recommendation: Implement the monitor and test. If notifications don't fire, fall back to CKContainer.accountStatus() + simple "iCloud enabled" indicator without real-time sync status.
   - Confidence: MEDIUM

## Sources

### Primary (HIGH confidence)
- Donny Wals - "A Deep Dive into SwiftData Migrations" (https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/) - VersionedSchema patterns, migration plan structure, retroactive V1
- Hacking with Swift - "How to sync SwiftData with iCloud" (https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud) - CloudKit requirements (defaults, optionals, no unique)
- Hacking with Swift - "How to create a complex migration using VersionedSchema" (https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) - Migration code patterns
- Fat Bob Man - "Rules for Adapting Data Models to CloudKit" (https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/) - Complete CloudKit model constraint list
- Apple - ModelConfiguration.CloudKitDatabase documentation (https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct) - Official API
- Apple - SchemaMigrationPlan documentation (https://developer.apple.com/documentation/swiftdata/schemamigrationplan) - Official API
- CloudKitSyncMonitor source code (https://github.com/ggruen/CloudKitSyncMonitor) - Reference implementation for sync monitoring patterns

### Secondary (MEDIUM confidence)
- Apple Developer Forums - SwiftData+CloudKit Migration Failure (https://developer.apple.com/forums/thread/742899) - Custom migration crash with CloudKit, FB13694972
- Apple Developer Forums - CloudKit Deduplication (https://developer.apple.com/forums/thread/745329) - UUID-based deduplication patterns
- Atomic Robot - "An Unauthorized Guide to SwiftData Migrations" (https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/) - Always use VersionedSchema from the start
- FireWhale - "Some Quirks of SwiftData with CloudKit" (https://firewhale.io/posts/swift-data-quirks/) - CloudKit model constraints confirmation

### Tertiary (LOW confidence)
- WWDC 2025 Session 291 - "SwiftData: Dive into inheritance and schema migration" (https://developer.apple.com/videos/play/wwdc2025/291/) - iOS 26 model inheritance (not directly applicable to iOS 17 target but confirms migration patterns)
- Apple Developer Forums - Local SwiftData to CloudKit migration (https://developer.apple.com/forums/thread/756538) - Community workarounds (could not verify specific claims)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - SwiftData + CloudKit is the only option for this use case. Well-documented by Apple and community.
- Architecture (schema versioning): HIGH - VersionedSchema + SchemaMigrationPlan patterns are well-established with multiple authoritative sources confirming the approach.
- Architecture (CloudKit model requirements): HIGH - Multiple independent sources confirm the defaults/optionals/no-unique constraints.
- Pitfalls (custom migration crash): HIGH - Confirmed by Apple Developer Forums with feedback number FB13694972. Multiple reporters.
- Pitfalls (sync monitoring): MEDIUM - eventChangedNotification is documented for NSPersistentCloudKitContainer but SwiftData's integration is less documented.
- Open questions (cloudID population): MEDIUM - Theoretical concern about per-row vs single evaluation of UUID default during migration.

**Research date:** 2026-02-13
**Valid until:** 2026-03-15 (stable domain, iOS 17 APIs frozen)
