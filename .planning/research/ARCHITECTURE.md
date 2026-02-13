# Architecture Patterns: v2.0 Integration

**Domain:** v2.0 feature integration into existing TimeQuest iOS app (contextual insights, self-set routines, iCloud backup, weekly reflections)
**Researched:** 2026-02-13
**Overall Confidence:** MEDIUM (training data only -- web/Context7 unavailable; CloudKit constraints based on training data through May 2025)

---

## Existing Architecture Snapshot

Before detailing v2.0 changes, here is the concrete current state from the shipped v1.0 codebase (46 Swift files, 3,575 LOC).

### Current Layer Map

```
+-----------------------------------------------------------------------+
| UI Layer (SwiftUI)                                                     |
|  Features/Parent/Views/   Features/Player/Views/   Features/Shared/   |
|  - ParentDashboardView    - PlayerHomeView          - PINEntryView     |
|  - RoutineEditorView      - QuestView               - AccuracyMeter   |
|  - RoutineListView        - EstimationInputView     - LevelBadgeView  |
|  - SchedulePickerView     - TaskActiveView          - StreakBadgeView  |
|  - TaskEditorView         - AccuracyRevealView      - XPBarView       |
|                           - SessionSummaryView      - TimeFormatting   |
|                           - PlayerStatsView                            |
|                           - AccuracyTrendChartView                     |
|                           - OnboardingView                             |
|                           - NotificationSettingsView                   |
+-----------------------------------------------------------------------+
| ViewModel Layer (@Observable, @MainActor)                              |
|  - RoutineEditorViewModel  (value-type RoutineEditState pattern)       |
|  - GameSessionViewModel    (QuestPhase state machine)                  |
|  - ProgressionViewModel    (chart data, personal bests)                |
+-----------------------------------------------------------------------+
| Domain Layer (pure Swift, zero framework imports)                      |
|  - TimeEstimationScorer    - XPEngine                                  |
|  - FeedbackGenerator       - LevelCalculator                           |
|  - CalibrationTracker      - StreakTracker                             |
|  - PersonalBestTracker                                                 |
+-----------------------------------------------------------------------+
| Data Layer (SwiftData + Repository Protocols)                          |
|  Models:       Routine, RoutineTask, GameSession, TaskEstimation,      |
|                PlayerProfile                                           |
|  Repositories: RoutineRepositoryProtocol (SwiftDataRoutineRepository)  |
|                SessionRepositoryProtocol (SwiftDataSessionRepository)   |
|                PlayerProfileRepositoryProtocol (SwiftDataPlayerProfile.)|
+-----------------------------------------------------------------------+
| App Layer                                                              |
|  - TimeQuestApp (ModelContainer registration)                          |
|  - ContentView (ModelContext -> AppDependencies bridge)                 |
|  - AppDependencies (@Observable composition root)                      |
|  - RoleRouter (AppRole enum, RoleState, PIN gate)                      |
+-----------------------------------------------------------------------+
| Services                                                               |
|  - SoundManager, NotificationManager                                   |
+-----------------------------------------------------------------------+
```

### Key Architectural Patterns Already Established

1. **Value-type editing**: RoutineEditorViewModel uses `RoutineEditState` (struct) to prevent SwiftData auto-save corruption. Only writes to @Model on explicit `save()`.
2. **Pure domain engines**: All business logic in `Domain/` has zero Foundation-only imports. No SwiftData, no SwiftUI.
3. **Repository abstraction**: `@MainActor` protocol -> SwiftData implementation. AppDependencies holds concrete instances.
4. **QuestPhase state machine**: `.selecting -> .estimating -> .active -> .revealing -> .summary` drives the game loop.
5. **Composition root**: AppDependencies created in ContentView with modelContext, injected via `.environment()`.
6. **ModelContainer registration**: In TimeQuestApp `WindowGroup.modelContainer(for: [...])` lists all model types.

---

## v2.0 Feature Integration Plan

### Feature 1: Contextual Learning Insights (Pattern Detection)

**What it is:** Analyze TaskEstimation history to detect per-task patterns (consistent over/underestimation, time-of-day effects, improving/stagnating trends) and surface them as insights both in-gameplay and in a dedicated "My Patterns" screen.

#### New Components

| Component | Layer | Type | File Path |
|-----------|-------|------|-----------|
| `InsightEngine` | Domain | Pure struct (static methods) | `Domain/InsightEngine.swift` |
| `InsightType` | Domain | Enum + associated values | `Domain/InsightEngine.swift` |
| `InsightsViewModel` | ViewModel | @Observable @MainActor | `Features/Player/ViewModels/InsightsViewModel.swift` |
| `MyPatternsView` | View | SwiftUI | `Features/Player/Views/MyPatternsView.swift` |
| `InsightCardView` | View | SwiftUI | `Features/Shared/Components/InsightCardView.swift` |

#### Data Model Changes

**None.** The existing `TaskEstimation` model already contains everything needed for pattern detection:
- `taskDisplayName` -- group by task
- `estimatedSeconds` / `actualSeconds` / `differenceSeconds` -- compute bias direction
- `accuracyPercent` -- trend analysis
- `recordedAt` -- time-of-day and trend-over-time analysis
- `session` relationship -> `session.routine` -- group by routine

The insight engine operates as a read-only analytics layer over existing data. No schema migration required.

#### InsightEngine Design (Pure Domain)

```swift
// Domain/InsightEngine.swift
import Foundation

enum InsightType: Equatable {
    case consistentBias(taskName: String, direction: BiasDirection, avgSeconds: Double)
    case improvingTask(taskName: String, recentAccuracy: Double, priorAccuracy: Double)
    case stagnatingTask(taskName: String, accuracy: Double, sessionCount: Int)
    case bestTimeOfDay(hour: Int, avgAccuracy: Double)
    case fastestImproving(taskName: String, improvementPercent: Double)
}

enum BiasDirection: String {
    case over   // consistently overestimates
    case under  // consistently underestimates
}

struct Insight: Identifiable {
    let id = UUID()
    let type: InsightType
    let headline: String   // "You always underestimate Packing"
    let body: String       // "Your estimates for Packing average 4m12s under..."
    let emoji: String      // SF Symbol name
}

struct InsightEngine {
    /// Minimum estimations per task before generating insights
    static let minimumSampleSize = 5

    /// Generate all applicable insights from estimation history.
    /// Pure function: takes data in, returns insights out.
    static func generateInsights(
        estimations: [EstimationSnapshot],
        currentHour: Int = Calendar.current.component(.hour, from: .now)
    ) -> [Insight] {
        var insights: [Insight] = []
        insights.append(contentsOf: detectBiases(estimations))
        insights.append(contentsOf: detectImprovements(estimations))
        insights.append(contentsOf: detectBestTimeOfDay(estimations, currentHour: currentHour))
        return insights
    }

    // ... private static methods for each detection type
}

/// Value-type snapshot of TaskEstimation data.
/// Decouples insight engine from SwiftData @Model.
struct EstimationSnapshot {
    let taskDisplayName: String
    let estimatedSeconds: Double
    let actualSeconds: Double
    let differenceSeconds: Double
    let accuracyPercent: Double
    let recordedAt: Date
}
```

**Key design decision:** The InsightEngine takes `[EstimationSnapshot]` (a value type), NOT `[TaskEstimation]` (a SwiftData @Model). This preserves the pure-domain-engine pattern. The ViewModel bridges between SwiftData and the domain layer by mapping `TaskEstimation` -> `EstimationSnapshot` before calling InsightEngine.

#### Data Flow

```
PlayerStatsView / MyPatternsView
  -> InsightsViewModel.loadInsights()
    -> sessionRepository.fetchAllSessions()
    -> map session.orderedEstimations -> [EstimationSnapshot]
    -> InsightEngine.generateInsights(estimations:)
    -> viewModel.insights = [Insight]
  -> View renders InsightCardView for each Insight
```

For in-gameplay contextual hints (shown during estimation phase):

```
GameSessionViewModel.startQuest()
  -> fetch previous estimations for current task
  -> InsightEngine.generateInsights(estimations: filteredForThisTask)
  -> if insight found, set viewModel.contextualHint = insight
  -> EstimationInputView shows hint below input ("You usually underestimate this one")
```

#### Integration Points with Existing Code

| Existing Component | Change | Type |
|-------------------|--------|------|
| `GameSessionViewModel` | Add optional `contextualHint: Insight?` property; populate during `startQuest()` | Minor addition |
| `PlayerHomeView` | Add NavigationLink to MyPatternsView in stats section | Minor addition |
| `PlayerStatsView` | Add insights section above/below existing charts | Minor addition |
| `EstimationInputView` | Show contextual hint if available | Minor addition |
| `SessionRepository` | No changes -- `fetchAllSessions()` already exists | None |
| `AppDependencies` | No changes -- InsightEngine is static, no instance needed | None |

---

### Feature 2: Self-Set Routines (Player-Created Routines)

**What it is:** The player can create her own routines alongside parent-created ones. This transfers ownership and signals the skill is internalizing ("she wants to estimate things on her own").

#### Data Model Changes

**Add `createdBy` field to Routine model.** This is the only schema change needed for self-set routines.

```swift
// Models/Routine.swift -- MODIFIED
@Model
final class Routine {
    var name: String
    var displayName: String
    var activeDays: [Int]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String  // NEW: "parent" or "player"

    @Relationship(deleteRule: .cascade, inverse: \RoutineTask.routine)
    var tasks: [RoutineTask] = []

    @Relationship(deleteRule: .cascade, inverse: \GameSession.routine)
    var sessions: [GameSession] = []
    // ...
}
```

**SwiftData migration consideration:** Adding a new stored property with a default value to an existing @Model is a lightweight migration. SwiftData handles this automatically -- no manual migration plan needed. The existing routines will have `createdBy` set to the default value.

**Use `String` not an enum for `createdBy`:** SwiftData stores enums as their raw values, and String enums work well. However, storing as raw `String` gives maximum forward compatibility (e.g., adding "template" creator later) without migration. Use a `RoutineCreator` enum in the domain layer that maps to/from the string.

#### New Components

| Component | Layer | Type | File Path |
|-----------|-------|------|-----------|
| `RoutineCreator` | Domain | Enum | `Domain/RoutineCreator.swift` |
| `PlayerRoutineEditorViewModel` | ViewModel | @Observable @MainActor | `Features/Player/ViewModels/PlayerRoutineEditorViewModel.swift` |
| `PlayerRoutineEditorView` | View | SwiftUI | `Features/Player/Views/PlayerRoutineEditorView.swift` |
| `RoutineTemplates` | Domain | Struct with static data | `Domain/RoutineTemplates.swift` |

#### Design Decision: Reuse vs. Separate Editor

**Recommendation: Create a separate PlayerRoutineEditorView rather than reusing the parent's RoutineEditorView.**

Rationale:
- The parent editor has `name` (internal) + `displayName` (player-facing) fields -- the player should only see one name field
- The parent editor's language is setup-oriented ("Schedule", "Active days") -- the player's should be game-framed ("When do you want this quest?", "Quest days")
- The player editor should offer templates ("Getting ready for a friend's house", "Homework session", "Activity prep") -- the parent editor does not
- The `RoutineEditorViewModel`'s `RoutineEditState` value-type pattern should be reused. The VM logic for task add/remove/reorder is identical. Only the View differs.

**Solution:** Create `PlayerRoutineEditorViewModel` that wraps the same `RoutineEditState` struct but auto-sets `createdBy = "player"` and `name = displayName` (player doesn't need separate internal names). The VM can even subclass or compose with the existing RoutineEditorViewModel's save logic, though composition is cleaner:

```swift
// Features/Player/ViewModels/PlayerRoutineEditorViewModel.swift
@MainActor
@Observable
final class PlayerRoutineEditorViewModel {
    var editState: RoutineEditState
    var selectedTemplate: RoutineTemplate?

    private let repository: RoutineRepositoryProtocol
    private let modelContext: ModelContext

    func save() throws {
        // Set name = displayName (player doesn't see internal names)
        editState.name = editState.displayName
        let routine = Routine(
            name: editState.name,
            displayName: editState.displayName,
            activeDays: editState.activeDays,
            isActive: true,
            createdBy: RoutineCreator.player.rawValue
        )
        // ... same task creation logic as RoutineEditorViewModel
    }
}
```

#### Routine Templates

```swift
// Domain/RoutineTemplates.swift
import Foundation

struct RoutineTemplate: Identifiable {
    let id = UUID()
    let name: String            // "Friend's House Prep"
    let suggestedTasks: [String] // ["Pick outfit", "Pack bag", "Check directions"]
    let emoji: String           // SF Symbol
}

struct RoutineTemplates {
    static let all: [RoutineTemplate] = [
        RoutineTemplate(
            name: "Homework Session",
            suggestedTasks: ["Get materials", "Work time", "Pack up"],
            emoji: "book.fill"
        ),
        RoutineTemplate(
            name: "Going to a Friend's",
            suggestedTasks: ["Pick outfit", "Get ready", "Pack what you need", "Check directions"],
            emoji: "person.2.fill"
        ),
        RoutineTemplate(
            name: "Activity Prep",
            suggestedTasks: ["Gather gear", "Get changed", "Pack bag", "Snack"],
            emoji: "figure.run"
        ),
        RoutineTemplate(
            name: "Custom Quest",
            suggestedTasks: [],
            emoji: "sparkles"
        ),
    ]
}
```

#### Integration Points with Existing Code

| Existing Component | Change | Type |
|-------------------|--------|------|
| `Routine` model | Add `createdBy: String` property with default `"parent"` | Schema addition (auto-migrated) |
| `RoutineEditorViewModel.createNew()` | Set `createdBy = "parent"` on new routines | Minor change |
| `RoutineRepository.fetchActiveForToday()` | No change -- already fetches all active routines regardless of creator | None |
| `PlayerHomeView` | Add "Create Quest" button that navigates to PlayerRoutineEditorView | UI addition |
| `PlayerHomeView.questCard()` | Optionally show a badge for player-created quests ("Your Quest") | Minor UI tweak |
| `TimeQuestApp` | No change -- Routine model is already registered in ModelContainer | None |

#### Data Flow

```
PlayerHomeView -> "Create Quest" button
  -> PlayerRoutineEditorView (sheet)
    -> PlayerRoutineEditorViewModel (RoutineEditState with templates)
    -> User picks template or starts blank
    -> User edits tasks, sets quest days
    -> save() -> RoutineRepository.save() with createdBy = "player"
  -> PlayerHomeView refreshes todayQuests -> shows new quest in list
```

---

### Feature 3: iCloud/CloudKit Backup (SwiftData Sync)

**What it is:** Sync SwiftData to iCloud so progress is preserved across device replacement, app reinstall, or (eventually) multi-device access.

#### CloudKit Requirements for SwiftData Models

**Confidence: MEDIUM** -- Based on training data knowledge of SwiftData + CloudKit constraints. These constraints are well-documented but the exact API surface should be verified against current Xcode SDK.

SwiftData supports CloudKit sync through `ModelConfiguration`. To enable it, the data models must satisfy CloudKit compatibility requirements:

**Required model constraints:**

1. **All properties must have default values or be optional.** CloudKit records arrive asynchronously; the model must be constructable without all fields present.
2. **No unique constraints.** CloudKit does not support server-side uniqueness enforcement. The `#Unique` macro cannot be used on any model that syncs.
3. **Relationships must be optional.** Both sides of a relationship must be optional (`var routine: Routine?`, not `var routine: Routine`).
4. **No transformable attributes without explicit support.** Custom Codable types in arrays (like `[Int]` for `activeDays`) work, but complex nested Codable types may need verification.

**Current model audit against CloudKit constraints:**

| Model | Property | CloudKit Compatible? | Issue | Fix |
|-------|----------|---------------------|-------|-----|
| `Routine` | `name: String` | NO -- no default | Missing default | Add `= ""` |
| `Routine` | `displayName: String` | NO -- no default | Missing default | Add `= ""` |
| `Routine` | `activeDays: [Int]` | MAYBE | Array of primitives should work | Verify with CloudKit |
| `Routine` | `isActive: Bool` | YES | Has implicit default | OK |
| `Routine` | `createdAt: Date` | YES | Default `= .now` | OK |
| `RoutineTask` | `name: String` | NO -- no default | Missing default | Add `= ""` |
| `RoutineTask` | `displayName: String` | NO -- no default | Missing default | Add `= ""` |
| `RoutineTask` | `orderIndex: Int` | YES | Default `= 0` | OK |
| `RoutineTask` | `routine: Routine?` | YES | Already optional | OK |
| `GameSession` | `routine: Routine?` | YES | Already optional | OK |
| `GameSession` | `startedAt: Date` | YES | Default `= .now` | OK |
| `GameSession` | `isCalibration: Bool` | YES | Default `= false` (implicit) | Verify -- may need explicit default |
| `TaskEstimation` | Multiple non-optional, no-default properties | NO | 7 properties lack defaults | Add defaults to all |
| `PlayerProfile` | All properties | YES | All have defaults | OK |

**Summary of required changes for CloudKit compatibility:**

```swift
// Routine -- add defaults
var name: String = ""
var displayName: String = ""
var activeDays: [Int] = []

// RoutineTask -- add defaults
var name: String = ""
var displayName: String = ""
var referenceDurationSeconds: Int? = nil  // already optional, OK

// GameSession -- verify isCalibration has explicit default
var isCalibration: Bool = false  // already has default in init, but stored property may need it

// TaskEstimation -- add defaults to ALL stored properties
var taskDisplayName: String = ""
var estimatedSeconds: Double = 0
var actualSeconds: Double = 0
var differenceSeconds: Double = 0
var accuracyPercent: Double = 0
var ratingRawValue: String = ""
var orderIndex: Int = 0
var recordedAt: Date = .now
```

**These default values do not change runtime behavior.** The existing `init()` methods still set all values explicitly. The defaults only satisfy CloudKit's requirement that a model can be partially initialized during sync.

#### ModelConfiguration Changes

```swift
// TimeQuestApp.swift -- MODIFIED
@main
struct TimeQuestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Routine.self,
            RoutineTask.self,
            GameSession.self,
            TaskEstimation.self,
            PlayerProfile.self
        ], cloudKitDatabase: .automatic)  // <-- Enable CloudKit sync
    }
}
```

**Alternative approach using ModelConfiguration:**

```swift
let config = ModelConfiguration(
    cloudKitDatabase: .automatic  // or .private("iCloud.com.yourteam.TimeQuest")
)
let container = try ModelContainer(
    for: Routine.self, RoutineTask.self, GameSession.self,
         TaskEstimation.self, PlayerProfile.self,
    configurations: config
)
```

#### Entitlements and Capabilities

| Requirement | What to Do |
|-------------|------------|
| iCloud capability | Enable in Xcode target -> Signing & Capabilities -> iCloud |
| CloudKit container | Create container `iCloud.com.{teamID}.TimeQuest` |
| Background modes | Enable "Remote notifications" for push-based sync triggers |
| Push notifications entitlement | Required for CloudKit change notifications |

#### CloudKit Database Type

**Use `.private` database (the default for `.automatic`).** Each user's data syncs only to their own iCloud account. This is correct for TimeQuest because:
- Data is personal (one player's estimation history)
- No sharing between accounts needed
- Private database has the most generous CloudKit quotas
- No CloudKit Dashboard schema management needed (schema auto-created from SwiftData models)

#### Architecture Impact

**Minimal.** The repository layer does not change. Repositories already call `modelContext.save()` and `modelContext.fetch()`. CloudKit sync happens transparently beneath the ModelContext layer. The main changes are:

1. Model property defaults (migration-safe additions)
2. ModelContainer configuration (one-line change)
3. Xcode entitlements (project configuration, not code)
4. Conflict resolution policy (see Pitfalls section below)

**No new components needed** for basic iCloud backup. CloudKit sync is infrastructure, not feature code.

#### Conflict Resolution

SwiftData with CloudKit uses **last-writer-wins** conflict resolution by default. For TimeQuest this is acceptable because:
- Single-user app (one player, one device at a time)
- Primary use case is backup/restore, not real-time multi-device editing
- Estimation data is append-only (new TaskEstimation records, never edited)
- The only mutable models are `Routine` (edited by parent) and `PlayerProfile` (updated at session end)

**Risk scenario:** User plays on old device, then restores to new device. If both devices have different PlayerProfile.totalXP, last-writer-wins could lose XP. Mitigation: PlayerProfile updates are monotonically increasing (XP only goes up, streak only changes once per day). A merge conflict here means the user sees the latest state, which is the desired behavior.

#### Important Caveats

| Caveat | Impact | Mitigation |
|--------|--------|------------|
| CloudKit sync is eventual, not instant | User may not see synced data for seconds to minutes | Show "syncing" indicator; design for offline-first |
| First sync after enabling CloudKit uploads entire local store | May take several minutes with large history | Enable CloudKit early (before data grows large) |
| CloudKit has per-record size limits (~1MB) | Not an issue -- our records are tiny (strings + doubles + dates) | None needed |
| Array properties (`activeDays: [Int]`) may have CloudKit quirks | Codable arrays are serialized; verify they round-trip correctly | Test early with CloudKit enabled |
| `isCalibration` on GameSession is not explicitly defaulted at property declaration | CloudKit requires default at property level, not just in init | Add explicit `= false` at property declaration |

---

### Feature 4: Weekly Reflection Summaries

**What it is:** A brief weekly summary showing estimation accuracy trends, best moments, patterns detected, and progress toward goals. Presented as a screen the player can review, optionally triggered by a notification.

#### New Components

| Component | Layer | Type | File Path |
|-----------|-------|------|-----------|
| `WeeklyReflectionEngine` | Domain | Pure struct (static methods) | `Domain/WeeklyReflectionEngine.swift` |
| `WeeklyReflection` | Domain | Value type | `Domain/WeeklyReflectionEngine.swift` |
| `WeeklyReflectionViewModel` | ViewModel | @Observable @MainActor | `Features/Player/ViewModels/WeeklyReflectionViewModel.swift` |
| `WeeklyReflectionView` | View | SwiftUI | `Features/Player/Views/WeeklyReflectionView.swift` |
| `WeeklyReflectionSummary` | Model (optional) | @Model | `Models/WeeklyReflectionSummary.swift` |

#### Design: Compute vs. Store

**Recommendation: Compute reflections on-demand from existing data, with optional caching.**

Rationale:
- All data needed (TaskEstimation, GameSession, PlayerProfile) already exists
- Computing a weekly summary from ~7 days of sessions is cheap (tens to low hundreds of records)
- Storing summaries would add a new @Model, a migration, and CloudKit sync overhead for data that can be reconstructed
- Exception: if we want to show "Your reflection from 3 weeks ago" comparisons, caching the computed summary is worthwhile

**Compromise approach:** Compute live for the current week. Optionally persist `WeeklyReflectionSummary` as a lightweight cache for historical reflections (defer persistence to later if not needed immediately).

#### WeeklyReflectionEngine Design

```swift
// Domain/WeeklyReflectionEngine.swift
import Foundation

struct WeeklyReflection {
    let weekStartDate: Date
    let weekEndDate: Date
    let sessionsCompleted: Int
    let totalEstimations: Int
    let averageAccuracy: Double
    let accuracyChange: Double       // vs. prior week (+/- percent)
    let bestEstimation: BestMoment?  // closest estimate of the week
    let mostImproved: String?        // task name that improved most
    let consistentBias: BiasInfo?    // "You overestimated 70% of the time"
    let streakStatus: StreakInfo
    let insights: [Insight]          // reuses InsightEngine types
}

struct BestMoment {
    let taskName: String
    let differenceSeconds: Double
    let date: Date
}

struct BiasInfo {
    let direction: BiasDirection
    let percent: Double
}

struct StreakInfo {
    let current: Int
    let isActive: Bool
    let longestThisWeek: Int
}

struct WeeklyReflectionEngine {
    /// Generate a weekly reflection from session data.
    /// Pure function: estimation snapshots in, reflection out.
    static func generateReflection(
        currentWeekEstimations: [EstimationSnapshot],
        priorWeekEstimations: [EstimationSnapshot],
        sessionsThisWeek: Int,
        currentStreak: Int,
        isStreakActive: Bool,
        weekStart: Date,
        weekEnd: Date
    ) -> WeeklyReflection {
        // ... compute all fields from input data
    }
}
```

**Key design decision:** WeeklyReflectionEngine takes the same `EstimationSnapshot` type as InsightEngine. This means the mapping from SwiftData models to value types happens once, in the ViewModel, and both engines consume the same data format.

#### Data Flow

```
PlayerHomeView (weekly prompt banner)
  -> WeeklyReflectionView (NavigationLink)
    -> WeeklyReflectionViewModel.loadReflection()
      -> sessionRepository.fetchAllSessions()
      -> filter to current week + prior week
      -> map to [EstimationSnapshot]
      -> WeeklyReflectionEngine.generateReflection(...)
      -> InsightEngine.generateInsights(currentWeekEstimations)
      -> viewModel.reflection = WeeklyReflection
    -> View renders summary cards

Notification trigger (optional):
  -> NotificationManager.scheduleWeeklyReflection(dayOfWeek: .sunday, hour: 18)
  -> Notification: "Your weekly Time Sense report is ready"
  -> User opens app -> PlayerHomeView shows reflection banner
```

#### Integration Points with Existing Code

| Existing Component | Change | Type |
|-------------------|--------|------|
| `PlayerHomeView` | Add conditional banner "Your weekly report is ready" when it's Sunday/Monday and reflection hasn't been viewed | UI addition |
| `PlayerProfile` | Add `lastReflectionViewedDate: Date?` to track whether current week's reflection has been seen | Schema addition (auto-migrated) |
| `NotificationManager` | Add `scheduleWeeklyReflection()` method | Method addition |
| `SessionRepository` | No changes -- `fetchAllSessions()` already exists | None |
| `InsightEngine` | Reused directly -- no changes | None |

---

## New Model Summary (All Changes)

### Modified Models

```swift
// Routine.swift -- 2 changes
@Model
final class Routine {
    var name: String = ""                    // CHANGED: add default for CloudKit
    var displayName: String = ""             // CHANGED: add default for CloudKit
    var activeDays: [Int] = []               // CHANGED: add default for CloudKit
    var isActive: Bool = true                // unchanged (already has default)
    var createdAt: Date = .now               // unchanged (already has default)
    var updatedAt: Date = .now               // unchanged (already has default)
    var createdBy: String = "parent"         // NEW: for self-set routines + CloudKit default
    // ... relationships unchanged
}

// RoutineTask.swift -- 2 changes
@Model
final class RoutineTask {
    var name: String = ""                    // CHANGED: add default for CloudKit
    var displayName: String = ""             // CHANGED: add default for CloudKit
    var referenceDurationSeconds: Int? = nil // unchanged
    var orderIndex: Int = 0                  // unchanged (already has default)
    var routine: Routine?                    // unchanged
}

// TaskEstimation.swift -- all properties get defaults for CloudKit
@Model
final class TaskEstimation {
    var taskDisplayName: String = ""         // CHANGED: add default
    var estimatedSeconds: Double = 0         // CHANGED: add default
    var actualSeconds: Double = 0            // CHANGED: add default
    var differenceSeconds: Double = 0        // CHANGED: add default
    var accuracyPercent: Double = 0          // CHANGED: add default
    var ratingRawValue: String = ""          // CHANGED: add default
    var orderIndex: Int = 0                  // unchanged (already has default)
    var recordedAt: Date = .now              // CHANGED: add default
    var session: GameSession?                // unchanged
}

// GameSession.swift -- 1 change
@Model
final class GameSession {
    var routine: Routine?                    // unchanged
    var startedAt: Date = .now               // CHANGED: add explicit default at property level
    var completedAt: Date? = nil             // unchanged
    var isCalibration: Bool = false          // CHANGED: add explicit default at property level
    var xpEarned: Int = 0                    // unchanged (already has default)
    // ... relationships unchanged
}

// PlayerProfile.swift -- 1 new property
@Model
final class PlayerProfile {
    var totalXP: Int = 0                     // unchanged
    var currentStreak: Int = 0               // unchanged
    var lastPlayedDate: Date?                // unchanged
    var notificationsEnabled: Bool = true    // unchanged
    var notificationHour: Int = 7            // unchanged
    var notificationMinute: Int = 30         // unchanged
    var soundEnabled: Bool = true            // unchanged
    var createdAt: Date = Date.now           // unchanged
    var lastReflectionViewedDate: Date?      // NEW: weekly reflection tracking
}
```

### New Models (Optional)

```swift
// Models/WeeklyReflectionSummary.swift -- OPTIONAL, defer if not needed
@Model
final class WeeklyReflectionSummary {
    var weekStartDate: Date = .now
    var sessionsCompleted: Int = 0
    var averageAccuracy: Double = 0
    var accuracyChange: Double = 0
    var bestTaskName: String = ""
    var bestDifferenceSeconds: Double = 0
    var createdAt: Date = .now

    init(from reflection: WeeklyReflection) { ... }
}
```

### Migration Safety Assessment

All model changes are **additive**:
- Adding default values to existing properties: SwiftData handles automatically (lightweight migration)
- Adding new optional properties (`lastReflectionViewedDate`, `createdBy`): SwiftData handles automatically
- Adding new stored property with default (`createdBy: String = "parent"`): Existing records get the default value

**No manual migration plan needed.** SwiftData's automatic lightweight migration covers all these changes. This is because we are only:
1. Adding defaults to existing properties (no-op for existing data)
2. Adding new properties with defaults (existing records get default)
3. NOT renaming, removing, or changing types of existing properties

---

## New Domain Engines

### Complete Inventory

| Engine | Purpose | Input | Output | Dependencies |
|--------|---------|-------|--------|--------------|
| `InsightEngine` | Pattern detection across estimation history | `[EstimationSnapshot]` | `[Insight]` | None (pure) |
| `WeeklyReflectionEngine` | Weekly summary computation | `[EstimationSnapshot]` + metadata | `WeeklyReflection` | None (pure) |
| `RoutineTemplates` | Static template data for player routine creation | None | `[RoutineTemplate]` | None (static data) |

These follow the existing pattern: pure Swift structs with static methods, zero framework imports, value-type inputs and outputs.

### Shared Value Types

```swift
// Domain/EstimationSnapshot.swift -- NEW shared type
import Foundation

/// Value-type snapshot of TaskEstimation data.
/// Used by InsightEngine and WeeklyReflectionEngine.
/// Decouples domain engines from SwiftData @Model types.
struct EstimationSnapshot {
    let taskDisplayName: String
    let estimatedSeconds: Double
    let actualSeconds: Double
    let differenceSeconds: Double
    let accuracyPercent: Double
    let recordedAt: Date
    let routineDisplayName: String?
}

extension TaskEstimation {
    /// Bridge from SwiftData model to domain value type.
    func toSnapshot() -> EstimationSnapshot {
        EstimationSnapshot(
            taskDisplayName: taskDisplayName,
            estimatedSeconds: estimatedSeconds,
            actualSeconds: actualSeconds,
            differenceSeconds: differenceSeconds,
            accuracyPercent: accuracyPercent,
            recordedAt: recordedAt,
            routineDisplayName: session?.routine?.displayName
        )
    }
}
```

**Note:** The `toSnapshot()` extension on TaskEstimation is in the Domain layer but imports SwiftData indirectly through the model. To keep domain truly pure, this extension should live in a bridge file (e.g., `Repositories/EstimationSnapshotBridge.swift` or alongside the ViewModel). The InsightEngine and WeeklyReflectionEngine themselves remain pure.

---

## Updated AppDependencies

```swift
// App/AppDependencies.swift -- minimal changes
@MainActor
@Observable
final class AppDependencies {
    let routineRepository: RoutineRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    let playerProfileRepository: PlayerProfileRepositoryProtocol
    let soundManager: SoundManager
    let notificationManager: NotificationManager
    // No new dependencies needed.
    // InsightEngine, WeeklyReflectionEngine, RoutineTemplates are all static/value types.
    // ViewModels create them locally.
}
```

**No changes to AppDependencies.** The new domain engines are all stateless (static methods on structs). They don't need to be instantiated or injected. ViewModels call them directly. This is consistent with how existing engines (TimeEstimationScorer, XPEngine, etc.) work.

---

## Updated File Structure

```
TimeQuest/
  App/
    TimeQuestApp.swift              # MODIFIED: CloudKit config
    AppDependencies.swift           # unchanged
    RoleRouter.swift                # unchanged
    ContentView (inline)            # unchanged

  Models/
    Routine.swift                   # MODIFIED: defaults + createdBy
    RoutineTask.swift               # MODIFIED: defaults
    GameSession.swift               # MODIFIED: explicit defaults
    TaskEstimation.swift            # MODIFIED: defaults
    PlayerProfile.swift             # MODIFIED: lastReflectionViewedDate
    WeeklyReflectionSummary.swift   # NEW (optional, defer)

  Repositories/
    RoutineRepository.swift         # unchanged
    SessionRepository.swift         # unchanged
    PlayerProfileRepository.swift   # unchanged
    EstimationSnapshotBridge.swift  # NEW: TaskEstimation -> EstimationSnapshot

  Domain/
    CalibrationTracker.swift        # unchanged
    FeedbackGenerator.swift         # unchanged
    LevelCalculator.swift           # unchanged
    PersonalBestTracker.swift       # unchanged
    StreakTracker.swift              # unchanged
    TimeEstimationScorer.swift      # unchanged
    XPEngine.swift                  # unchanged
    InsightEngine.swift             # NEW: pattern detection
    WeeklyReflectionEngine.swift    # NEW: weekly summary computation
    RoutineTemplates.swift          # NEW: player routine templates
    RoutineCreator.swift            # NEW: enum for routine ownership
    EstimationSnapshot.swift        # NEW: shared domain value type

  Features/
    Parent/
      ViewModels/
        RoutineEditorViewModel.swift    # MINOR: set createdBy = "parent"
      Views/
        (all unchanged)

    Player/
      ViewModels/
        GameSessionViewModel.swift      # MINOR: add contextualHint property
        ProgressionViewModel.swift      # unchanged
        InsightsViewModel.swift         # NEW
        WeeklyReflectionViewModel.swift # NEW
        PlayerRoutineEditorViewModel.swift # NEW
      Views/
        PlayerHomeView.swift            # MODIFIED: add Create Quest + reflection banner
        MyPatternsView.swift            # NEW
        WeeklyReflectionView.swift      # NEW
        PlayerRoutineEditorView.swift   # NEW
        EstimationInputView.swift       # MINOR: show contextual hint
        (other views unchanged)

    Shared/
      Components/
        InsightCardView.swift           # NEW

  Services/
    SoundManager.swift              # unchanged
    NotificationManager.swift       # MODIFIED: add weekly reflection scheduling

  Game/
    AccuracyRevealScene.swift       # unchanged
    CelebrationScene.swift          # unchanged
```

**New file count:** ~12 new files. **Modified file count:** ~8 files. Total codebase grows from 46 to ~58 Swift files.

---

## Build Order (Dependency-Driven)

The features have this dependency graph:

```
EstimationSnapshot (shared value type)
  |
  +---> InsightEngine (depends on EstimationSnapshot)
  |       |
  |       +---> Contextual Insights feature (depends on InsightEngine)
  |       |
  |       +---> Weekly Reflections (depends on InsightEngine for insight reuse)
  |
  +---> WeeklyReflectionEngine (depends on EstimationSnapshot)

Routine.createdBy (schema change)
  |
  +---> Self-Set Routines (depends on createdBy field)

CloudKit defaults (schema changes)
  |
  +---> iCloud Backup (depends on all models having defaults)
```

### Recommended Build Phases

**Phase 1: Data Foundation + CloudKit**
1. Add property defaults to all models (CloudKit compatibility)
2. Add `createdBy` to Routine
3. Add `lastReflectionViewedDate` to PlayerProfile
4. Add `EstimationSnapshot` value type + bridge extension
5. Enable CloudKit in ModelConfiguration
6. Add iCloud entitlement
7. Test: verify existing app works with defaults, CloudKit sync works

**Rationale:** Do schema changes first because everything else depends on them. CloudKit is infrastructure that doesn't affect feature code. Getting it working early means all subsequent data is synced from day one.

**Phase 2: Contextual Learning Insights**
1. Build `InsightEngine` (pure domain, test-first)
2. Build `InsightsViewModel`
3. Build `InsightCardView` (shared component)
4. Build `MyPatternsView`
5. Add contextual hints to `GameSessionViewModel` + `EstimationInputView`
6. Add navigation from PlayerHomeView/PlayerStatsView to MyPatternsView
7. Test: verify insights generate correctly from real estimation data

**Rationale:** InsightEngine is a prerequisite for Weekly Reflections (which reuses insights). Building it first unlocks both features. The pattern detection logic is the most complex new domain code and benefits from early testing.

**Phase 3: Self-Set Routines**
1. Build `RoutineTemplates` (static data)
2. Build `RoutineCreator` enum
3. Build `PlayerRoutineEditorViewModel`
4. Build `PlayerRoutineEditorView`
5. Add "Create Quest" button to PlayerHomeView
6. Update `RoutineEditorViewModel` to set `createdBy = "parent"`
7. Test: player can create routine from template, routine appears in quest list

**Rationale:** Self-set routines depend on the `createdBy` schema change (done in Phase 1) but are otherwise independent of insights. Could be built in parallel with Phase 2 if resources allow.

**Phase 4: Weekly Reflections**
1. Build `WeeklyReflectionEngine` (pure domain, test-first)
2. Build `WeeklyReflectionViewModel`
3. Build `WeeklyReflectionView`
4. Add reflection banner to PlayerHomeView
5. Add weekly notification scheduling to NotificationManager
6. Test: weekly summary renders correctly, notification fires on schedule

**Rationale:** Depends on InsightEngine (reuses insight types). Must come after Phase 2. Weekly reflections are the least critical feature and benefit from having more estimation data to summarize.

---

## Anti-Patterns to Avoid (v2.0-Specific)

### Anti-Pattern: Domain Engines Importing SwiftData

**What:** InsightEngine or WeeklyReflectionEngine directly accepting `[TaskEstimation]` (SwiftData @Model).

**Why bad:** Breaks the pure-domain-engine pattern. Makes engines untestable without ModelContainer. Creates hidden MainActor requirements.

**Instead:** Use EstimationSnapshot value type. The ViewModel bridges between SwiftData and domain.

### Anti-Pattern: Storing Computed Insights as @Model

**What:** Creating an `@Model Insight` class to persist detected patterns.

**Why bad:** Insights are computed from underlying data that changes every session. Persisted insights go stale. Creates cache invalidation headaches. Adds CloudKit sync overhead for derived data.

**Instead:** Compute insights fresh each time from TaskEstimation data. It's fast (tens to hundreds of records, simple aggregation).

### Anti-Pattern: Modifying Existing Inits for CloudKit Defaults

**What:** Changing existing `init()` methods to use default parameter values instead of adding property-level defaults.

**Why bad:** CloudKit requires defaults at the stored property declaration level (`var name: String = ""`), not in the init. CloudKit initializes records by setting properties directly, bypassing custom inits.

**Instead:** Add defaults at the property declaration level. Keep existing inits unchanged.

### Anti-Pattern: Using CloudKit Shared Database

**What:** Configuring SwiftData with `.shared` CloudKit database for family sharing.

**Why bad:** Shared databases require CKShare management, participant invitations, and complex permission handling. Massive scope creep for a single-user backup feature. Also leaks parent-configured data to the player's iCloud account in a visible way.

**Instead:** Use `.private` (the default). Each iCloud account gets its own synced copy. If family sharing is needed later, it's a separate feature.

### Anti-Pattern: Player Editor Reusing Parent Editor Views

**What:** Showing the parent's RoutineEditorView to the player with minor conditionals.

**Why bad:** The parent editor has `name`/`displayName` dual fields, setup-oriented language, and no templates. Conditionally hiding fields creates a confusing view with lots of `if isPlayerMode` branches.

**Instead:** Separate view (PlayerRoutineEditorView) reusing the same RoutineEditState struct and save logic. Different views, shared data types.

---

## Scalability Considerations

| Concern | Current (v1.0) | After v2.0 | Future Risk |
|---------|----------------|------------|-------------|
| InsightEngine performance | N/A | Processes all TaskEstimations. At 100 sessions x 5 tasks = 500 records. Trivial. | At 1000+ sessions, add date-range filtering (last 90 days). |
| CloudKit sync volume | N/A | All records sync. ~500 records initial upload. | At 10K+ records, consider archiving old sessions to reduce sync payload. |
| Weekly reflection computation | N/A | Processes ~1 week of data. Trivial. | No scaling concern. Always bounded to 7 days. |
| Player-created routines | 0 routines | 2-5 routines. Same as parent routines. | No scaling concern. Routines are metadata, not high-volume data. |
| EstimationSnapshot mapping | N/A | Maps SwiftData models to value types. Linear O(n). | Marginal cost. Could cache snapshots if profiling shows concern. |

---

## Sources

- **Existing codebase analysis**: All 46 Swift files read and analyzed directly from `/Users/davezabihaylo/Desktop/Claude Cowork/GSD/TimeQuest/`
- **SwiftData + CloudKit constraints**: Training data knowledge of WWDC 2023/2024 SwiftData sessions, Apple documentation on CloudKit compatibility requirements. MEDIUM confidence -- constraints are well-documented but exact API syntax should be verified against current Xcode SDK.
- **SwiftData migration behavior**: Training data knowledge of lightweight migration support in SwiftData (additive changes auto-migrated). MEDIUM confidence.
- **ModelConfiguration API**: Training data knowledge of `cloudKitDatabase` parameter options (`.automatic`, `.private`, `.none`). MEDIUM confidence -- verify exact parameter names in current SDK.
- **Architecture patterns**: Direct observation of existing codebase patterns (pure domain engines, value-type editing, repository protocols, composition root). HIGH confidence -- these are the actual shipped patterns.

**Confidence note:** Web search and Context7 were unavailable during this session. All CloudKit-specific claims are based on training data through May 2025. The SwiftData + CloudKit integration API was stable by that point (introduced WWDC 2023, refined WWDC 2024), but exact syntax should be verified against current Xcode documentation during implementation. The property-default requirements for CloudKit compatibility are well-established and unlikely to have changed.
