# Technology Stack: v2.0 Additions

**Project:** TimeQuest v2.0 -- Advanced Training Features
**Researched:** 2026-02-13
**Overall Confidence:** MEDIUM (WebSearch/WebFetch unavailable; recommendations based on training data through mid-2025 plus codebase analysis; flag CloudKit specifics for validation)

**Scope:** This document covers ONLY additions and changes needed for v2.0. The existing v1.0 stack (SwiftUI, SwiftData, SpriteKit, Swift Charts, AVFoundation, UserNotifications, iOS 17.0+, Swift 6.0) is validated and unchanged.

---

## Executive Assessment

v2.0 requires **zero new third-party dependencies**. Every new capability maps to an Apple first-party framework that already ships with the iOS 17 SDK. The only additions are:

1. **CloudKit framework** -- iCloud backup/sync (new framework addition)
2. **New SwiftData model types** -- pattern analysis, reflection, self-set routines (schema evolution)
3. **New pure domain engines** -- pattern analyzer, reflection generator (new code, no new dependencies)
4. **Real audio assets** -- replacing placeholder .wav files (asset swap, no code change)

This is architecturally ideal. The v1.0 stack was designed to accommodate exactly these additions.

---

## New Framework Additions

### 1. CloudKit (via SwiftData ModelConfiguration)

| Property | Value |
|----------|-------|
| **Framework** | CloudKit.framework (ships with iOS SDK) |
| **Purpose** | iCloud backup and sync of all player data across devices |
| **Integration point** | `ModelConfiguration(cloudKitDatabase: .automatic)` in `TimeQuestApp.swift` |
| **Why** | SwiftData has built-in CloudKit sync. Enabling it is a configuration change, not an architecture change. This was explicitly anticipated in v1.0 research. |

**What changes in existing code:**

```swift
// BEFORE (v1.0 -- TimeQuestApp.swift)
.modelContainer(for: [
    Routine.self,
    RoutineTask.self,
    GameSession.self,
    TaskEstimation.self,
    PlayerProfile.self
])

// AFTER (v2.0)
.modelContainer(for: [
    Routine.self,
    RoutineTask.self,
    GameSession.self,
    TaskEstimation.self,
    PlayerProfile.self,
    WeeklyReflection.self,  // new model
    // other new models...
], configurations: ModelConfiguration(
    cloudKitDatabase: .automatic
))
```

**Required project configuration:**
1. Add CloudKit capability in Xcode Signing & Capabilities
2. Add iCloud capability with CloudKit checkbox
3. Add a CloudKit container identifier (e.g., `iCloud.com.timequest.app`)
4. Enable Background Modes > Remote notifications (for CloudKit change notifications)
5. Update `project.yml` to include `CloudKit.framework` SDK dependency

**Confidence:** MEDIUM -- SwiftData + CloudKit integration was demonstrated at WWDC 2023 and improved at WWDC 2024. The `ModelConfiguration(cloudKitDatabase:)` API exists. However, exact behavior with relationships (especially cascade deletes) and optional properties needs validation. SwiftData CloudKit sync has had bugs in early iOS 17 releases; iOS 17.4+ is reportedly more stable.

**Critical constraints for CloudKit-compatible SwiftData models:**
- All properties must have default values (CloudKit records can arrive with missing fields during sync)
- No unique constraints (CloudKit does not support them)
- Relationships must be optional on at least one side
- No custom `#Index` macros (CloudKit ignores them, but they do not break sync)
- Existing models (Routine, RoutineTask, GameSession, TaskEstimation, PlayerProfile) already satisfy most of these -- they use optional relationships and have defaults. **Verify:** `Routine.activeDays: [Int]` may need a default value explicitly set for CloudKit compatibility.

---

### 2. No Other New Frameworks Required

| Proposed Feature | Framework Needed | Already Available? |
|------------------|-----------------|-------------------|
| Contextual learning insights | SwiftData (queries) + pure Swift (analysis) | YES -- SwiftData already in project |
| Pattern analysis engine | Pure Swift structs | YES -- follows existing `TimeEstimationScorer` pattern |
| Self-set routines | SwiftUI (forms) + SwiftData (persistence) | YES -- existing `RoutineEditorViewModel` pattern |
| Routine templates | Pure Swift structs (static data) | YES -- no framework needed |
| Real sound assets | AVFoundation (`AVAudioPlayer`) | YES -- `SoundManager` already handles this |
| Weekly reflections | SwiftData (model) + SwiftUI (views) + Swift Charts | YES -- all in project |
| iCloud backup | CloudKit via SwiftData | Partially -- need to add CloudKit framework |

---

## New Domain Engines (Pure Swift, No Dependencies)

These follow the established v1.0 pattern: pure structs with static methods, zero framework dependencies, fully testable.

### PatternAnalyzer

**Purpose:** Analyze per-task estimation history to surface contextual insights.
**Follows pattern of:** `TimeEstimationScorer`, `PersonalBestTracker`

```swift
// Domain/PatternAnalyzer.swift -- new file
struct PatternAnalyzer {
    struct TaskPattern {
        let taskDisplayName: String
        let averageDifference: Double       // signed: positive = tends to overestimate
        let consistencyScore: Double         // 0-100: how consistent estimates are
        let recentTrend: Trend               // improving, declining, stable
        let sampleCount: Int
    }

    enum Trend: String {
        case improving, declining, stable
    }

    /// Pure function: analyze estimations for a single task
    static func analyze(taskName: String, estimations: [TaskEstimation]) -> TaskPattern
    /// Pure function: generate insight text from a pattern
    static func insightText(for pattern: TaskPattern) -> String
}
```

**Input:** `[TaskEstimation]` from existing SwiftData queries (already available via `SessionRepository`)
**Output:** Value types consumed by ViewModels
**No new framework needed.**

**Confidence:** HIGH -- this is pure Swift business logic using data types that already exist.

### ReflectionGenerator

**Purpose:** Summarize a week of sessions into a reflection with highlights and growth areas.
**Follows pattern of:** `FeedbackGenerator`

```swift
// Domain/ReflectionGenerator.swift -- new file
struct WeeklyReflectionData {
    let weekStartDate: Date
    let sessionsCompleted: Int
    let averageAccuracy: Double
    let bestTask: String?
    let growthArea: String?
    let streakStatus: String
    let xpEarned: Int
    let headline: String
    let bodyText: String
}

struct ReflectionGenerator {
    /// Pure function: generate reflection from a week of sessions
    static func generate(
        sessions: [GameSession],
        weekStart: Date,
        playerProfile: PlayerProfile
    ) -> WeeklyReflectionData
}
```

**No new framework needed.**

**Confidence:** HIGH -- pure Swift, straightforward aggregation logic.

### RoutineTemplateProvider

**Purpose:** Provide pre-built routine templates for the guided self-set routine creation flow.
**Why a domain engine:** Templates are static data with validation logic. No persistence needed for templates themselves.

```swift
// Domain/RoutineTemplateProvider.swift -- new file
struct RoutineTemplate {
    let name: String
    let displayName: String
    let suggestedTasks: [TaskTemplate]
    let suggestedDays: [Int]
    let category: TemplateCategory
}

struct TaskTemplate {
    let name: String
    let displayName: String
    let suggestedDurationSeconds: Int?
}

enum TemplateCategory: String, CaseIterable {
    case morning, afterSchool, sports, creative, weekend
}

struct RoutineTemplateProvider {
    static let templates: [RoutineTemplate] = [...]
}
```

**No new framework needed.**

**Confidence:** HIGH -- static data.

---

## New SwiftData Models (Schema Evolution)

### WeeklyReflection

**Purpose:** Persist generated weekly reflections so the player can review past weeks.

```swift
@Model
final class WeeklyReflection {
    var weekStartDate: Date = Date.now
    var sessionsCompleted: Int = 0
    var averageAccuracy: Double = 0.0
    var bestTaskName: String = ""
    var growthAreaTaskName: String = ""
    var headline: String = ""
    var bodyText: String = ""
    var xpEarned: Int = 0
    var createdAt: Date = Date.now

    init(/* ... */) { /* ... */ }
}
```

**CloudKit compatibility:** All properties have defaults. No relationships (reflections are standalone summaries). No unique constraints. This is CloudKit-safe.

### Model changes to existing types

**Routine:** Add `createdByPlayer: Bool = false` to distinguish parent-created vs self-set routines. Default is `false` for backward compatibility with existing data.

**PlayerProfile:** Add `lastReflectionDate: Date?` to track when the last weekly reflection was generated.

**No migration needed** if using SwiftData's lightweight migration (adding properties with defaults is automatically handled).

**Confidence:** MEDIUM -- SwiftData lightweight migration for adding optional/defaulted properties works in iOS 17+. Verify that adding `createdByPlayer` to `Routine` does not require explicit migration with existing CloudKit data.

---

## Real Sound Assets

### Current State

5 placeholder .wav files in `Resources/Sounds/`, each 8,864 bytes (identical size = clearly generated placeholders, likely silence or a basic tone):

| File | Game Event |
|------|------------|
| `estimate_lock.wav` | Player locks in their time estimate |
| `reveal.wav` | Accuracy reveal moment |
| `level_up.wav` | Player levels up |
| `personal_best.wav` | New personal best achieved |
| `session_complete.wav` | All tasks in a quest finished |

### What to Replace With

**Format:** Keep `.wav` (uncompressed) for short SFX. `AVAudioPlayer` handles .wav with zero latency. Do NOT switch to .mp3 or .aac for game SFX -- compression adds decode latency.

**Alternative:** `.caf` (Core Audio Format) is Apple's preferred format and supports both compressed and uncompressed. For short SFX (<2 seconds), the difference is negligible. Stick with `.wav` since the existing `SoundManager` is already configured for it.

**Recommended sound characteristics for a 13-year-old's game:**

| Sound | Character | Duration | Notes |
|-------|-----------|----------|-------|
| `estimate_lock.wav` | Crisp confirmation click/tap | 0.2-0.5s | Satisfying, not mechanical |
| `reveal.wav` | Whoosh or unveil flourish | 0.5-1.0s | Build anticipation |
| `level_up.wav` | Ascending chime/fanfare | 1.0-2.0s | Celebratory, not childish |
| `personal_best.wav` | Achievement sparkle/ding | 0.5-1.0s | Distinct from level_up |
| `session_complete.wav` | Warm completion tone | 1.0-1.5s | Satisfying closure |

**Sourcing options (royalty-free, commercial use):**

| Source | License | Cost | Best For |
|--------|---------|------|----------|
| **freesound.org** | Creative Commons (CC0, CC-BY) | Free | Individual SFX, large catalog |
| **Pixabay** (audio section) | Pixabay License (free commercial use) | Free | Curated game SFX packs |
| **Mixkit** | Mixkit License (free commercial use) | Free | Game sound effects category |
| **Zapsplat** | Standard License (free with attribution OR paid without) | Free/Paid | Broad catalog, good quality |
| **Apple GarageBand** sound library | Royalty-free for any project | Free (ships with macOS) | Can create custom short SFX |

**Recommendation:** Use **freesound.org** with CC0 (public domain) filter. This avoids any attribution requirements in the app. If CC0 options are insufficient, use CC-BY (attribution in app settings or about screen).

**No code changes needed.** The `SoundManager` loads files by name from the bundle. Replace the 5 .wav files with real ones keeping the same filenames. Zero code changes.

**Potential new sounds for v2.0 features:**

| Sound | Event | Priority |
|-------|-------|----------|
| `routine_created.wav` | Player creates their own routine | Medium |
| `reflection_ready.wav` | Weekly reflection available | Low |
| `insight_appear.wav` | Pattern insight surfaces during gameplay | Low |

These are optional -- v2.0 can ship with just the 5 core sounds replaced. Add additional sounds only if the UX calls for them during implementation.

**Confidence:** HIGH -- This is an asset swap, not a technical change.

---

## What NOT to Add

| Temptation | Why Not |
|------------|---------|
| **Third-party analytics (Firebase, Amplitude)** | Surveillance tool feel for a 13-year-old's game. Analytics happen through the pattern analyzer and weekly reflections, surfaced to the PLAYER, not extracted to a backend. |
| **Core ML / CreateML** | Overkill for pattern analysis. The estimation data is simple numeric time series. Standard deviation, moving averages, and linear trend detection are 20 lines of Swift. ML frameworks add binary size and complexity for no benefit at this data scale. |
| **SwiftUI Charts alternatives (DGCharts, etc.)** | Swift Charts already handles everything needed. Weekly reflection charts are the same accuracy-over-time pattern already built in v1.0. |
| **WidgetKit** | Tempting for showing streaks on home screen but out of scope for v2.0. Would require a separate widget extension target, shared App Group container, and adds build complexity. Defer to v3.0 if the player wants it. |
| **BackgroundTasks framework** | Not needed. Weekly reflections can be generated on-demand when the app opens and a week has passed. Background processing adds entitlement complexity for minimal benefit. |
| **StoreKit** | No in-app purchases. This is a personal tool, not a monetized product. |
| **App Intents / Shortcuts** | Cool but out of scope. Defer to v3.0. |
| **Combine** | The app uses @Observable pattern. Combine is not needed for any v2.0 feature. Timer-based functionality (if any) can use Swift concurrency (`Task.sleep`). |
| **Third-party CloudKit wrapper (CloudKitCodable, etc.)** | SwiftData's built-in CloudKit support handles everything. Adding a wrapper adds a dependency for no benefit. |

---

## Stack Changes Summary

### Added to project.yml

```yaml
dependencies:
  - sdk: SwiftUI.framework
  - sdk: SwiftData.framework
  - sdk: SpriteKit.framework
  - sdk: CryptoKit.framework
  - sdk: CloudKit.framework          # NEW for v2.0
```

### Added to modelContainer

```swift
// New model types registered
.modelContainer(for: [
    Routine.self,
    RoutineTask.self,
    GameSession.self,
    TaskEstimation.self,
    PlayerProfile.self,
    WeeklyReflection.self,           // NEW for v2.0
])
```

### New files (code, not libraries)

| File | Layer | Purpose |
|------|-------|---------|
| `Domain/PatternAnalyzer.swift` | Domain | Per-task estimation pattern analysis |
| `Domain/ReflectionGenerator.swift` | Domain | Weekly reflection summary generation |
| `Domain/RoutineTemplateProvider.swift` | Domain | Static routine templates for guided creation |
| `Models/WeeklyReflection.swift` | Model | Persisted weekly reflection |
| `Features/Player/Views/MyPatternsView.swift` | UI | "My Patterns" screen |
| `Features/Player/Views/WeeklyReflectionView.swift` | UI | Weekly reflection display |
| `Features/Player/Views/RoutineCreatorView.swift` | UI | Player-facing guided routine creation |
| `Features/Player/ViewModels/PatternViewModel.swift` | ViewModel | Mediates pattern analysis to UI |
| `Features/Player/ViewModels/ReflectionViewModel.swift` | ViewModel | Mediates reflection data to UI |
| `Features/Player/ViewModels/RoutineCreatorViewModel.swift` | ViewModel | Guided routine creation flow |

### Modified files

| File | Change |
|------|--------|
| `TimeQuestApp.swift` | Add CloudKit ModelConfiguration, register new model types |
| `project.yml` | Add CloudKit.framework dependency, add iCloud/CloudKit entitlements |
| `Models/Routine.swift` | Add `createdByPlayer: Bool = false` property |
| `Models/PlayerProfile.swift` | Add `lastReflectionDate: Date?` property |
| `AppDependencies.swift` | No change needed -- new ViewModels are created at the view level per existing pattern |
| `PlayerHomeView.swift` | Add navigation to My Patterns and Weekly Reflection |
| `Resources/Sounds/*.wav` | Replace 5 placeholder files with real audio |

### Unchanged

Everything else. The architecture, dependency injection, repository pattern, domain engine pattern, and build system remain identical.

---

## Entitlements Required (New for v2.0)

```xml
<!-- TimeQuest.entitlements -->
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.timequest.app</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudDocuments</string>
    <string>CloudKit</string>
</array>
```

**Note:** This requires an Apple Developer Program membership ($99/year) to provision CloudKit containers. The app can be developed and tested with Xcode's CloudKit console and simulator, but real device testing requires a signed provisioning profile with iCloud capability.

**Confidence:** MEDIUM -- entitlement format is standard, but the exact keys for SwiftData-managed CloudKit (vs. manual CloudKit) should be verified. SwiftData may only require the `CloudKit` service, not `CloudDocuments`.

---

## Integration Points with Existing Architecture

### How new engines integrate

```
Existing:                          New:
SessionRepository                  PatternAnalyzer
  .fetchAllSessions()        -->     .analyze(taskName:, estimations:)
  .fetchSessions(for:)              ReflectionGenerator
                                       .generate(sessions:, weekStart:, profile:)

RoutineEditorViewModel             RoutineCreatorViewModel
  (parent-facing)                    (player-facing, uses RoutineTemplateProvider)
  |                                  |
  v                                  v
RoutineRepository.save()           RoutineRepository.save()
  (both go through same repo -- createdByPlayer flag distinguishes them)
```

### Data flow for pattern insights (in-gameplay)

```
Player completes a task estimation
  -> GameSessionViewModel.completeActiveTask() [existing]
    -> Saves TaskEstimation [existing]
    -> PatternAnalyzer.analyze() [NEW -- called after save]
      -> Returns TaskPattern with insight
    -> GameSessionViewModel exposes currentInsight: String? [NEW property]
  -> AccuracyRevealView shows insight below feedback [NEW UI element]
```

### Data flow for weekly reflection

```
App launches (or returns from background)
  -> PlayerHomeView.onAppear [existing]
    -> Check: has it been 7+ days since lastReflectionDate?
      -> YES: ReflectionViewModel.generateReflection()
        -> Fetches last 7 days of sessions via SessionRepository
        -> Calls ReflectionGenerator.generate() [pure domain]
        -> Saves WeeklyReflection model
        -> Updates PlayerProfile.lastReflectionDate
        -> Shows "reflection ready" indicator on PlayerHomeView
      -> NO: Skip
```

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| CloudKit via SwiftData | MEDIUM | API exists and was designed for this. Exact behavior with existing model relationships needs validation during implementation. Test on real device early. |
| Pattern analysis engine | HIGH | Pure Swift math on existing data types. No framework uncertainty. |
| Weekly reflections | HIGH | Pure Swift generation + standard SwiftData persistence. |
| Self-set routines | HIGH | Reuses existing RoutineEditorViewModel pattern. Minimal new code. |
| Real sound assets | HIGH | Asset swap. Zero code change. |
| Schema migration | MEDIUM | Adding defaulted properties should be lightweight-migrated automatically. Verify with existing data on device. |
| Entitlements/provisioning | LOW | Requires Apple Developer account setup and correct entitlement configuration. Exact entitlements for SwiftData+CloudKit not verified against current docs. |

---

## Sources

- Existing TimeQuest v1.0 codebase (46 Swift files analyzed in full)
- v1.0 STACK.md research (2026-02-12) -- established base stack decisions
- Apple Developer Documentation (training data, not live-verified): SwiftData ModelConfiguration, CloudKit integration
- WWDC 2023: "Meet SwiftData", "Build an app with SwiftData" (CloudKit configuration demonstrated)
- WWDC 2024: "What's new in SwiftData" (improvements to CloudKit sync)
- **NOTE:** WebSearch and WebFetch were unavailable during this session. CloudKit entitlement configuration and SwiftData CloudKit edge cases (cascade delete sync, relationship conflict resolution) should be verified against current Apple documentation before implementation begins.
