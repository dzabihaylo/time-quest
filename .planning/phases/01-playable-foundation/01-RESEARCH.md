# Phase 1: Playable Foundation - Research

**Researched:** 2026-02-12
**Domain:** iOS app with SwiftUI + SwiftData + SpriteKit -- dual-mode (parent/player) app with time-estimation game loop
**Confidence:** MEDIUM-HIGH

## Summary

Phase 1 builds the entire vertical slice of TimeQuest: SwiftData models and repositories, a dual-mode app shell (player-default with hidden parent access), parent routine CRUD, and the core gameplay loop (quest selection, estimation, silent timer, accuracy feedback). The tech stack is 100% Apple first-party: SwiftUI for UI, SwiftData for persistence, SpriteKit (via SpriteView) for game scenes, and the Observation framework for state management. No third-party dependencies are needed.

The biggest technical risk is SwiftData's relationship handling. SwiftData does not preserve array ordering in relationships, which directly impacts the ordered-tasks-in-a-routine requirement (PRNT-02, PRNT-06). The workaround is well-documented: add an explicit `orderIndex` integer property to child models and sort via computed properties. Additionally, SwiftData has known bugs around relationship inverse updates across iOS 17 and iOS 18, requiring explicit inverse declarations and careful insert-before-relate patterns. These are manageable but must be planned for from the start.

The timer accuracy concern is a non-issue for this app's design. Since the player taps "done" when finished (no visible countdown), elapsed time is simply `doneDate.timeIntervalSince(startDate)`. This uses `Date` which is monotonic-clock-adjacent and survives background/foreground transitions accurately. The app does not need a running display timer -- just two timestamps.

**Primary recommendation:** Use SwiftData with explicit orderIndex properties for task ordering, repository protocols for testability, `@Observable` ViewModels, and `Date`-based elapsed time measurement. Keep SpriteKit minimal in Phase 1 -- use it only for the accuracy feedback reveal animation, not for the entire UI.

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| SwiftUI | Ships with iOS 17+ SDK | All UI: parent setup, player game screens, navigation, onboarding | Declarative, fastest iteration for solo dev, accessibility built-in |
| SwiftData | Ships with iOS 17+ SDK | Local persistence for routines, tasks, sessions, estimations | Apple's modern persistence; `@Model` macro, SwiftUI integration via `@Query` |
| SpriteKit (SpriteView) | Ships with iOS 17+ SDK | Accuracy feedback animations, celebration effects | First-party 2D engine; `SpriteView` embeds in SwiftUI with 2 lines |
| Observation framework (`@Observable`) | Ships with iOS 17+ SDK | ViewModel state management | Replaces `ObservableObject`; fine-grained property tracking, less boilerplate |
| Swift 6.2 | Ships with Xcode 26.2+ | Language | Current stable as of Feb 2026 |

### Supporting

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| Swift Testing (`@Test`, `#expect`) | Ships with Xcode 26 | Unit tests for domain logic, scoring, data models | All new test files; cleaner syntax than XCTest |
| XCTest | Ships with Xcode | UI tests, integration tests | XCUITest flows for critical paths |
| SF Symbols 6 | Ships with Xcode | Icons throughout UI | Every icon; scalable, accessible, no asset management |
| UserDefaults | Ships with iOS SDK | Parent PIN hash, onboarding-completed flags, preferences | Tiny key-value preferences only; never structured data |
| SwiftLint | Latest stable (Homebrew) | Code quality enforcement | Build phase script; catches solo-dev blind spots |

### Platform Target

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Deployment target | iOS 17.0+ | SwiftData requires iOS 17. Acceptable -- teens run latest iOS. |
| Xcode | 26.2 (current stable, Dec 2025) | Ships with Swift 6.2.3 and iOS 18 SDK |
| Swift | 6.2.x | Current stable. Strict concurrency default. |

**Confidence:** HIGH for framework choices (all first-party, well-established). MEDIUM for exact version numbers (Xcode 26.3 RC exists as of Feb 3, 2026 -- use whatever is stable at project start).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData | Core Data | More boilerplate but more stable/mature. SwiftData is adequate for this app's simple schema. |
| @Observable | TCA (Composable Architecture) | Excellent for complex apps but heavy learning curve; overkill for solo dev at this scale |
| SpriteKit | Pure SwiftUI animations | SpriteKit gives particle effects and richer game feel; but Phase 1 could survive with SwiftUI-only animations if SpriteKit adds friction |
| Repository pattern | Direct @Query in views | Simpler but harder to test; repository pattern adds ~50 lines of boilerplate but enables unit testing without SwiftData containers |

**Installation:**
```bash
# No SPM packages needed -- all first-party frameworks
# Build tool only:
brew install swiftlint
```

## Architecture Patterns

### Recommended Project Structure

```
TimeQuest/
  App/
    TimeQuestApp.swift              # @main entry point, ModelContainer setup
    AppDependencies.swift           # Composition root for DI
    RoleRouter.swift                # Player/parent mode switching

  Models/                           # SwiftData @Model classes
    Routine.swift
    RoutineTask.swift
    GameSession.swift
    TaskEstimation.swift
    AppSettings.swift               # Singleton for app-level config (PIN hash, onboarding state)

  Repositories/                     # Data access abstraction
    RoutineRepository.swift         # Protocol + SwiftData implementation
    SessionRepository.swift         # Protocol + SwiftData implementation

  Domain/                           # Pure Swift logic -- no framework imports
    TimeEstimationScorer.swift      # Accuracy scoring (pure function)
    RoutineManager.swift            # Validation, business rules for routine CRUD
    CalibrationTracker.swift        # Tracks whether session is in calibration phase (first 3-5)
    FeedbackGenerator.swift         # Generates curiosity-framed feedback text

  Features/
    Parent/
      Views/
        ParentDashboardView.swift
        RoutineListView.swift
        RoutineEditorView.swift
        TaskEditorView.swift
        SchedulePickerView.swift
      ViewModels/
        ParentViewModel.swift
        RoutineEditorViewModel.swift

    Player/
      Views/
        PlayerHomeView.swift        # Quest selection
        QuestView.swift             # Active gameplay
        EstimationInputView.swift   # "How long will this take?"
        TaskActiveView.swift        # "Do it now!" (no clock)
        AccuracyRevealView.swift    # Feedback after each task
        SessionSummaryView.swift    # End-of-session recap
        OnboardingView.swift        # First-launch experience
      ViewModels/
        GameSessionViewModel.swift
        EstimationViewModel.swift

    Shared/
      Views/
        PINEntryView.swift
      Components/
        AccuracyMeter.swift         # Visual accuracy indicator
        TimeFormatting.swift        # Duration display helpers

  Game/                             # SpriteKit scenes (Phase 1: minimal)
    AccuracyRevealScene.swift       # Animated accuracy reveal
    Particles/
      DiscoveryParticle.sks         # Particle effect for "big discovery" moments

  Resources/
    Assets.xcassets
```

### Pattern 1: Role Router with Hidden Gesture + PIN Gate

**What:** App defaults to player mode. Parent mode is accessed via a hidden gesture (triple-tap on a non-interactive area or long-press on app logo) followed by a 4-digit PIN. No visible "settings" or "parent" button anywhere in the player UI.

**When to use:** App launch, always. Player mode is the default.

**Why:** FOUN-01 (player-default), FOUN-02 (hidden gesture + PIN), FOUN-03 (zero parent evidence).

```swift
// RoleRouter.swift
enum AppRole {
    case player
    case parent
}

@Observable
final class RoleState {
    var currentRole: AppRole = .player
    var showingPINEntry = false

    func requestParentAccess() {
        showingPINEntry = true
    }

    func grantParentAccess() {
        currentRole = .parent
        showingPINEntry = false
    }

    func exitParentMode() {
        currentRole = .player
    }
}

struct RoleRouter: View {
    @State private var roleState = RoleState()

    var body: some View {
        Group {
            switch roleState.currentRole {
            case .player:
                PlayerHomeView()
                    .environment(roleState)
            case .parent:
                ParentDashboardView()
                    .environment(roleState)
            }
        }
        .sheet(isPresented: $roleState.showingPINEntry) {
            PINEntryView(onSuccess: { roleState.grantParentAccess() })
        }
    }
}
```

**Hidden gesture implementation:**
```swift
// On the player home screen, attach to a non-interactive element (e.g., app logo)
.onTapGesture(count: 3) {
    roleState.requestParentAccess()
}
// Alternative: long press on a specific decorative element
.onLongPressGesture(minimumDuration: 2.0) {
    roleState.requestParentAccess()
}
```

**PIN storage:** Hash the PIN with a simple SHA-256 and store in UserDefaults. This is a parental convenience gate, not a security boundary. Do NOT use Keychain for v1 -- it adds complexity without meaningful security gain (the "attacker" is a curious 13-year-old, not a threat actor).

### Pattern 2: SwiftData Models with Explicit Order Index

**What:** Since SwiftData does not preserve array ordering in relationships, use an explicit `orderIndex: Int` property on child models and sort via computed properties.

**When to use:** Any ordered relationship (tasks within a routine).

**Why this matters:** PRNT-02 requires ordered tasks. PRNT-06 requires reordering. Without explicit ordering, tasks appear in random database order on reload.

```swift
@Model
final class Routine {
    var name: String                    // Internal name ("School Morning")
    var displayName: String             // Player-facing ("Morning Quest")
    var activeDays: [Int]               // 1=Sun, 2=Mon, ..., 7=Sat (Codable array)
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RoutineTask.routine)
    var tasks: [RoutineTask] = []

    // Ordered access -- ALWAYS use this, never raw `tasks`
    var orderedTasks: [RoutineTask] {
        tasks.sorted { $0.orderIndex < $1.orderIndex }
    }
}

@Model
final class RoutineTask {
    var name: String                    // Internal ("Take a shower")
    var displayName: String             // Player-facing ("Shower Time")
    var referenceDurationSeconds: Int?  // Parent's estimate (hidden from player)
    var orderIndex: Int                 // Explicit ordering
    var routine: Routine?               // Inverse (optional required by SwiftData)
}
```

**Reorder operation:**
```swift
func reorderTasks(_ routine: Routine, from source: IndexSet, to destination: Int) {
    var ordered = routine.orderedTasks
    ordered.move(fromOffsets: source, toOffset: destination)
    for (index, task) in ordered.enumerated() {
        task.orderIndex = index
    }
    // SwiftData auto-saves or call context.save()
}
```

### Pattern 3: Date-Based Elapsed Time (No Running Timer Display)

**What:** Record `startedAt = Date.now` when player begins a task, record `completedAt = Date.now` when player taps "done". Elapsed time = `completedAt.timeIntervalSince(startedAt)`. No visible timer. No Timer.publish. No frame-by-frame updates.

**When to use:** Core gameplay loop -- every task estimation (GAME-02, GAME-03).

**Why:** The entire point is that no clock is visible (success criterion 4). `Date` uses the system clock and survives app backgrounding -- if the player switches apps mid-task, the elapsed time is still correct because both dates reference wall-clock time.

```swift
@Observable
final class TaskTimingState {
    var startedAt: Date?
    var completedAt: Date?

    var elapsedSeconds: TimeInterval? {
        guard let start = startedAt, let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }

    func startTask() {
        startedAt = Date.now
        completedAt = nil
    }

    func completeTask() {
        completedAt = Date.now
    }
}
```

**Background handling:** If the app is killed mid-task, persist `startedAt` to UserDefaults or SwiftData. On relaunch, check for an incomplete task and either resume or discard it gracefully.

### Pattern 4: Pure Domain Engines (No Framework Imports)

**What:** `TimeEstimationScorer`, `FeedbackGenerator`, and `CalibrationTracker` are plain Swift structs/classes with zero SwiftUI or SwiftData imports. They take data in and return results out.

**When to use:** All game logic, scoring, and feedback generation.

```swift
// TimeEstimationScorer.swift -- pure Swift, no imports beyond Foundation
struct EstimationResult {
    let estimatedSeconds: TimeInterval
    let actualSeconds: TimeInterval
    let differenceSeconds: TimeInterval    // signed: positive = overestimate
    let absDifferenceSeconds: TimeInterval
    let accuracyPercent: Double            // 0-100, 100 = perfect
    let rating: AccuracyRating
}

enum AccuracyRating: String, Codable {
    case spot_on    // within 10% or 15 seconds
    case close      // within 25%
    case off        // within 50%
    case way_off    // beyond 50%
}

struct TimeEstimationScorer {
    static func score(estimated: TimeInterval, actual: TimeInterval) -> EstimationResult {
        let difference = estimated - actual
        let absDiff = abs(difference)

        // For very short tasks (< 60s), use absolute threshold
        // For longer tasks, use percentage
        let accuracy: Double
        if actual < 60 {
            accuracy = max(0, 100 - (absDiff / 60 * 100))
        } else {
            accuracy = max(0, 100 - (absDiff / actual * 100))
        }

        let rating: AccuracyRating
        if absDiff <= max(15, actual * 0.10) {
            rating = .spot_on
        } else if absDiff <= actual * 0.25 {
            rating = .close
        } else if absDiff <= actual * 0.50 {
            rating = .off
        } else {
            rating = .way_off
        }

        return EstimationResult(
            estimatedSeconds: estimated,
            actualSeconds: actual,
            differenceSeconds: difference,
            absDifferenceSeconds: absDiff,
            accuracyPercent: accuracy,
            rating: rating
        )
    }
}
```

### Pattern 5: Repository Protocol for Testability

**What:** Wrap SwiftData access behind a protocol so domain logic and ViewModels can be tested with in-memory fakes.

**Architecture decision:** There is a debate in the SwiftUI community about whether repository patterns are needed with SwiftData. Some argue "views are the view model" and `@Query` should be used directly. For TimeQuest, the repository pattern is justified because:
1. Domain engines (scorer, calibration tracker) need data access without SwiftUI
2. The parent and player flows share data but have different access patterns
3. Unit testing game logic without SwiftData containers is essential

```swift
protocol RoutineRepositoryProtocol {
    func fetchAll() -> [Routine]
    func fetchActiveForToday() -> [Routine]
    func save(_ routine: Routine) throws
    func delete(_ routine: Routine) throws
}

@MainActor
final class SwiftDataRoutineRepository: RoutineRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchActiveForToday() -> [Routine] {
        let todayWeekday = Calendar.current.component(.weekday, from: Date.now)
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.activeDays.contains(todayWeekday) }
    }
    // ...
}
```

**Note on predicate limitation:** SwiftData predicates cannot filter on properties inside Codable arrays (like `activeDays: [Int]`). The workaround is to fetch all active routines and filter in Swift. This is acceptable for the small data volumes in this app (< 20 routines).

### Anti-Patterns to Avoid

- **Passing @Model objects directly to views without ViewModel mediation:** SwiftData auto-saves on context changes. Editing a routine name in a text field would save immediately -- no "cancel" support. Use value-type editing state in ViewModels, write back to @Model on explicit save.

- **Using Timer.publish for elapsed time tracking:** Fragile across background/foreground transitions, wastes CPU for a feature that needs no visual display. Use Date-based timestamps instead.

- **Storing the PIN in plaintext:** Hash with SHA-256 minimum. Store hash in UserDefaults. Compare hash on entry.

- **Making SpriteKit scenes manage game state:** SpriteKit scenes should only handle rendering. Game state lives in @Observable ViewModels that SpriteKit scenes read.

- **Using @Query for ViewModels that need to write data:** @Query is read-only and view-bound. ViewModels that perform CRUD need ModelContext directly (via repository).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Ordered lists in SwiftData | Custom linked-list or sorted-set persistence | `orderIndex: Int` property + computed sorted accessor | SwiftData doesn't preserve array order; orderIndex is the documented community pattern |
| Duration formatting | Custom string formatting for "2m 30s" | `Duration.UnitsFormatStyle` or `DateComponentsFormatter` | Edge cases (hours, zero-minutes, singular/plural) are handled |
| Day-of-week scheduling | Bitmask or custom weekday struct | `[Int]` with Calendar.current weekday values | Standard Foundation pattern; Codable for free |
| PIN hashing | Raw string comparison | `SHA256` from CryptoKit (2 lines of code) | Never compare plaintext PINs even for a parental gate |
| Accessibility for game elements | Manual VoiceOver strings | SwiftUI `.accessibilityLabel()` + `.accessibilityHint()` | Built-in, works with Dynamic Type and VoiceOver automatically |
| In-memory test containers | Mock objects with manual state | `ModelConfiguration(isStoredInMemoryOnly: true)` | SwiftData's built-in test support; creates isolated container per test |

**Key insight:** The entire stack is first-party Apple frameworks. The "don't hand-roll" principle here means: use the Apple-provided API even when it seems like rolling your own would be simpler. The edge cases in date formatting, accessibility, and data persistence are already solved.

## Common Pitfalls

### Pitfall 1: SwiftData Array Ordering Loss

**What goes wrong:** You define `var tasks: [RoutineTask]` as a relationship on Routine. Tasks appear in correct order during the session. On app restart, tasks appear in random order because SwiftData (backed by SQLite) does not preserve array element order.
**Why it happens:** Relational databases store rows, not ordered arrays. SwiftData's `@Relationship` array is an unordered set under the hood.
**How to avoid:** Always use an `orderIndex: Int` property on child models. Access via `routine.orderedTasks` (computed property with `.sorted`). Never rely on the raw array order.
**Warning signs:** Tasks randomly reorder between app launches; reorder operations appear to work then reset.
**Confidence:** HIGH -- well-documented issue confirmed by multiple sources including Apple Developer Forums and Hacking with Swift.

### Pitfall 2: SwiftData Relationship Initialization Crash

**What goes wrong:** Setting relationship properties in a model's `init()` causes runtime crashes like "Failed to find any currently loaded container."
**Why it happens:** SwiftData creates the object first, then inserts it into a context. Relationship assignment requires both objects to be in the same context.
**How to avoid:** Create the parent object, insert it into context, create the child, insert it, THEN set the relationship. Or: create both, insert both, then relate them.
**Warning signs:** Runtime crash on object creation, especially in seed data or test setup.
**Confidence:** HIGH -- documented by fatbobman.com and Apple Developer Forums.

```swift
// WRONG
let routine = Routine(name: "Morning")
let task = RoutineTask(name: "Shower", routine: routine) // Crash risk

// RIGHT
let routine = Routine(name: "Morning")
modelContext.insert(routine)
let task = RoutineTask(name: "Shower")
modelContext.insert(task)
task.routine = routine  // Set relationship after both are in context
// Or: routine.tasks.append(task)
```

### Pitfall 3: SwiftData Auto-Save Surprises

**What goes wrong:** User starts editing a routine name in the parent editor. Types halfway. Switches apps. SwiftData auto-saves the partial edit because the @Model was mutated directly.
**Why it happens:** SwiftData auto-saves on context changes by default. Any mutation to a @Model property is immediately queued for persistence.
**How to avoid:** Use value-type editing state in ViewModels. Copy @Model data into a struct for editing. Write back to the @Model only on explicit "Save" action.
**Warning signs:** Partial data appears after app restart; "Cancel" button on edit screens doesn't undo changes.
**Confidence:** HIGH -- this is a known SwiftData design characteristic.

```swift
// Editing pattern: copy to struct, edit struct, write back on save
struct RoutineEditState {
    var name: String
    var displayName: String
    var activeDays: [Int]
    var isActive: Bool
}

@Observable
final class RoutineEditorViewModel {
    var editState: RoutineEditState
    private let routine: Routine
    private let repository: RoutineRepositoryProtocol

    init(routine: Routine, repository: RoutineRepositoryProtocol) {
        self.routine = routine
        self.editState = RoutineEditState(
            name: routine.name,
            displayName: routine.displayName,
            activeDays: routine.activeDays,
            isActive: routine.isActive
        )
        self.repository = repository
    }

    func save() throws {
        routine.name = editState.name
        routine.displayName = editState.displayName
        routine.activeDays = editState.activeDays
        routine.isActive = editState.isActive
        routine.updatedAt = Date.now
        try repository.save(routine)
    }
}
```

### Pitfall 4: Parent Language Leaking into Player UI

**What goes wrong:** A routine named "School Morning Routine" appears in the player UI. The player recognizes it as something her parent configured. The "my game" illusion breaks.
**Why it happens:** Developer uses `routine.name` instead of `routine.displayName` in the player flow. Or parent sets displayName to the same value as name.
**How to avoid:** Player views ONLY access `displayName`. Parent editor should encourage fun/game-like display names with placeholder text like "Give it a quest name! (e.g., Morning Quest)". Validation: if displayName is empty, fall back to a generic game name, NEVER to the parent's internal name.
**Warning signs:** Player screens showing words like "routine," "task," "schedule," or realistic activity names.
**Confidence:** HIGH -- architectural decision, not technology uncertainty.

### Pitfall 5: Predicate Filtering on Codable Properties

**What goes wrong:** You try to write a SwiftData predicate like `#Predicate { $0.activeDays.contains(todayWeekday) }` and the compiler rejects it or it crashes at runtime.
**Why it happens:** SwiftData predicates have limited support for operations on Codable-encoded properties stored as JSON blobs in SQLite.
**How to avoid:** Fetch with simpler predicates (e.g., `isActive == true`) and filter the result set in Swift. For this app's data volumes (< 20 routines), this is negligible performance-wise.
**Warning signs:** Compiler errors in `#Predicate` blocks; runtime crashes with "unsupported predicate."
**Confidence:** HIGH -- confirmed by multiple sources including fatbobman.com.

### Pitfall 6: ScenePhase Not Handling All Lifecycle Cases

**What goes wrong:** You rely solely on `ScenePhase.background` to save in-progress task timing data. The app is killed by the system without transitioning through `.background`, and timing data is lost.
**Why it happens:** `ScenePhase` has only 3 states and may not fire for all termination scenarios (force-quit, memory pressure kill).
**How to avoid:** Persist timing start state (`startedAt` Date) eagerly to UserDefaults or SwiftData immediately when a task begins. On relaunch, check for orphaned in-progress tasks.
**Warning signs:** Lost session data after unexpected app termination.
**Confidence:** MEDIUM -- ScenePhase limitations are documented but edge cases depend on iOS version.

## Code Examples

### SwiftData Model Container Setup

```swift
// TimeQuestApp.swift
@main
struct TimeQuestApp: App {
    var body: some Scene {
        WindowGroup {
            RoleRouter()
        }
        .modelContainer(for: [
            Routine.self,
            RoutineTask.self,
            GameSession.self,
            TaskEstimation.self
        ])
    }
}
```

### In-Memory Container for Testing

```swift
// Source: hackingwithswift.com/quick-start/swiftdata
@MainActor
final class RoutineRepositoryTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Routine.self, RoutineTask.self,
            configurations: config
        )
        context = container.mainContext
    }

    func testFetchActiveRoutines() throws {
        let routine = Routine(name: "Test", displayName: "Quest", activeDays: [2, 3, 4, 5, 6], isActive: true)
        context.insert(routine)
        try context.save()

        let repo = SwiftDataRoutineRepository(modelContext: context)
        let active = repo.fetchAll().filter { $0.isActive }
        XCTAssertEqual(active.count, 1)
    }
}
```

### Estimation Input with Duration Picker

```swift
// EstimationInputView.swift -- player estimates task duration
struct EstimationInputView: View {
    let taskDisplayName: String
    @Binding var estimatedMinutes: Int
    @Binding var estimatedSeconds: Int
    var onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("How long will this take?")
                .font(.title2)
                .fontWeight(.semibold)

            Text(taskDisplayName)
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(spacing: 8) {
                Picker("Minutes", selection: $estimatedMinutes) {
                    ForEach(0..<60) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 120)

                Picker("Seconds", selection: $estimatedSeconds) {
                    ForEach(0..<60) { Text("\($0) sec").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 120)
            }
            .frame(height: 150)

            Button("Lock It In") {
                onSubmit()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}
```

### Curiosity-Framed Feedback

```swift
// FeedbackGenerator.swift -- pure Swift, no framework imports
struct FeedbackGenerator {
    /// Returns a curiosity-framed message based on estimation accuracy.
    /// NEVER returns judgmental language. Large gaps are "discoveries."
    static func message(for result: EstimationResult, isCalibrationPhase: Bool) -> FeedbackMessage {
        let diffFormatted = formatDuration(result.absDifferenceSeconds)
        let direction = result.differenceSeconds > 0 ? "over" : "under"

        if isCalibrationPhase {
            return calibrationMessage(result: result, diffFormatted: diffFormatted, direction: direction)
        }

        switch result.rating {
        case .spot_on:
            return FeedbackMessage(
                headline: "Nailed it!",
                body: "Your time sense was right on.",
                emoji: "bullseye"  // SF Symbol name
            )
        case .close:
            return FeedbackMessage(
                headline: "\(diffFormatted) \(direction)",
                body: "Getting dialed in.",
                emoji: "scope"
            )
        case .off:
            return FeedbackMessage(
                headline: "\(diffFormatted) \(direction)",
                body: "Interesting -- that one felt different than it was.",
                emoji: "magnifyingglass"
            )
        case .way_off:
            return FeedbackMessage(
                headline: "\(diffFormatted) \(direction)!",
                body: "Big discovery! This one's tricky to feel.",
                emoji: "sparkles"
            )
        }
    }

    private static func calibrationMessage(result: EstimationResult, diffFormatted: String, direction: String) -> FeedbackMessage {
        FeedbackMessage(
            headline: "\(diffFormatted) \(direction)",
            body: "Just learning your patterns. Every guess teaches something.",
            emoji: "chart.line.uptrend.xyaxis"
        )
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}

struct FeedbackMessage {
    let headline: String
    let body: String
    let emoji: String  // SF Symbol name
}
```

### Session Data Model

```swift
@Model
final class GameSession {
    var routine: Routine?
    var startedAt: Date
    var completedAt: Date?
    var isCalibration: Bool             // True for first 3-5 sessions

    @Relationship(deleteRule: .cascade, inverse: \TaskEstimation.session)
    var estimations: [TaskEstimation] = []

    var orderedEstimations: [TaskEstimation] {
        estimations.sorted { $0.orderIndex < $1.orderIndex }
    }

    init(routine: Routine, isCalibration: Bool) {
        self.startedAt = Date.now
        self.isCalibration = isCalibration
    }
}

@Model
final class TaskEstimation {
    var taskDisplayName: String          // Snapshot of task name at time of play
    var estimatedSeconds: Double
    var actualSeconds: Double
    var differenceSeconds: Double        // Signed: positive = overestimate
    var accuracyPercent: Double
    var ratingRawValue: String           // AccuracyRating.rawValue
    var orderIndex: Int                  // Order within session
    var recordedAt: Date
    var session: GameSession?

    var rating: AccuracyRating {
        AccuracyRating(rawValue: ratingRawValue) ?? .way_off
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject` + `@Published` | `@Observable` macro | iOS 17 (WWDC 2023) | Less boilerplate, fine-grained observation, better performance |
| Core Data (`NSManagedObject`, `.xcdatamodeld`) | SwiftData (`@Model` macro) | iOS 17 (WWDC 2023) | Declarative models, SwiftUI integration, but with stability caveats |
| `NavigationView` | `NavigationStack` with path | iOS 16 (WWDC 2022) | Programmatic navigation, type-safe routing, deep link support |
| Xcode 16 / Swift 6.0 | Xcode 26 / Swift 6.2 | June 2025 (WWDC 2025) | Version numbering change; Swift 6.2 has easier concurrency defaults |
| SwiftData iOS 17 relationship bugs | Improved in iOS 18+ / Xcode 26 | 2024-2025 | Many relationship bugs fixed; Codable properties usable in predicates (Xcode 26) |

**Deprecated/outdated:**
- `NavigationView`: Use `NavigationStack` instead
- `ObservableObject` + `@StateObject` + `@Published`: Use `@Observable` + `@State` for new code
- `@EnvironmentObject`: Use `.environment()` with `@Observable` types

## Open Questions

1. **SpriteKit extent in Phase 1**
   - What we know: SpriteKit is part of the tech stack for game feel. SpriteView embeds cleanly in SwiftUI.
   - What's unclear: How much of the player UI should be SpriteKit vs pure SwiftUI in Phase 1? The accuracy reveal and celebration effects clearly benefit from SpriteKit. But the estimation input, task-active screen, and quest selection are form-like and better as SwiftUI.
   - Recommendation: Use SpriteKit only for the AccuracyRevealScene (post-task feedback animation). Everything else in Phase 1 is pure SwiftUI. Expand SpriteKit use in Phase 2 when adding particle celebrations and polish.

2. **Calibration session count detection**
   - What we know: First 3-5 sessions should be flagged as calibration (PROG-07). Need to count completed sessions per routine or globally.
   - What's unclear: Is calibration per-routine or global? A new routine added later should probably have its own calibration phase.
   - Recommendation: Track calibration per-routine. Count completed GameSessions for each routine. First 3 sessions for a given routine are marked `isCalibration = true`. This naturally handles routines added later.

3. **SwiftData stability on iOS 17.0-17.3**
   - What we know: SwiftData had significant bugs in early iOS 17 releases. Most are fixed by iOS 17.4+.
   - What's unclear: Should we target iOS 17.0 or iOS 17.4 minimum?
   - Recommendation: Target iOS 17.0 in the deployment target but test on iOS 17.4+ simulators. The app's simple schema (no CloudKit, no complex predicates, no @ModelActor concurrency) avoids most early-iOS-17 bugs. If issues arise, bump to iOS 17.4 minimum.

4. **First-launch onboarding flow**
   - What we know: FEEL-05 requires onboarding that explains the game, not the problem. FEEL-06 requires progressive disclosure.
   - What's unclear: Exact onboarding flow steps and content.
   - Recommendation: Design a 3-screen onboarding: (1) "This is your time game" (2) "Guess how long, then do it" (3) "See how close you were." Track onboarding completion in UserDefaults. Progressive disclosure handled by calibration phase messaging.

## Sources

### Primary (HIGH confidence)
- [Apple Developer Documentation: SwiftData updates](https://developer.apple.com/documentation/updates/swiftdata) -- framework evolution and current state
- [Apple Developer Documentation: NavigationStack](https://developer.apple.com/documentation/SwiftUI/NavigationStack) -- navigation patterns
- [Apple Developer Documentation: Migrating to @Observable](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro) -- @Observable migration guide
- [Hacking with Swift: SwiftData by Example](https://www.hackingwithswift.com/quick-start/swiftdata) -- SwiftData patterns and testing
- [Hacking with Swift: SpriteView integration](https://www.hackingwithswift.com/quick-start/swiftui/how-to-integrate-spritekit-using-spriteview) -- SpriteKit + SwiftUI
- [xcodereleases.com](https://xcodereleases.com/) -- confirmed Xcode 26.2 (Dec 2025) with Swift 6.2.3

### Secondary (MEDIUM confidence)
- [Fatbobman: Relationships in SwiftData](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/) -- relationship bugs, performance (700x slower append), workarounds
- [Fatbobman: Key Considerations Before Using SwiftData](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) -- stability concerns, iOS 18 regressions, concurrency caveats
- [Fatbobman: Swift Weekly #116](https://fatbobman.com/en/weekly/issue-116/) -- WWDC 2025 SwiftData assessment ("I wish it had been in this state when first released")
- [Wade Tregaskis: SwiftData Pitfalls](https://wadetregaskis.com/swiftdata-pitfalls/) -- auto-save unreliability, array ordering, relationship crashes
- [AzamSharp: SwiftData Architecture Patterns](https://azamsharp.com/2025/03/28/swiftdata-architecture-patterns-and-practices.html) -- @Query vs repository debate
- [Geoff Pado: @Query Considered Harmful](https://pado.name/blog/2025/02/swiftdata-query/) -- argues for FetchDescriptor over @Query
- [SwiftData ordered arrays workaround](https://medium.com/@jc_builds/swiftdata-how-to-preserve-array-order-in-a-swiftdata-model-6ea1b895ed50) -- orderIndex pattern

### Tertiary (LOW confidence)
- [Jesse Squires: ScenePhase bugs](https://www.jessesquires.com/blog/2024/06/29/swiftui-scene-phase/) -- ScenePhase limitations (single source, needs validation for iOS 18+)
- [Jesse Squires: @Observable not drop-in replacement](https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/) -- edge cases in @Observable migration

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all first-party Apple frameworks, well-established since iOS 17 (2+ years)
- Architecture (MVVM, repository, role router): HIGH -- standard SwiftUI patterns with extensive community validation
- SwiftData specifics (relationships, ordering, auto-save): MEDIUM-HIGH -- confirmed by multiple independent sources, but edge cases may exist on specific iOS versions
- SpriteKit integration: MEDIUM -- SpriteView is stable but Phase 1 usage is minimal; less researched for this specific use case
- Pitfalls: HIGH -- all pitfalls verified across 2+ independent sources
- Feedback/calibration design: MEDIUM -- game design choices based on domain research, not code verification

**Research date:** 2026-02-12
**Valid until:** 2026-03-15 (30 days -- stack is stable; SwiftData bugs may get fixes in point releases)
