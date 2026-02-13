# Architecture Patterns

**Domain:** iOS time-perception training game with gamification, local persistence, and parent/player role separation
**Researched:** 2026-02-12

## Recommended Architecture

**Pattern: Feature-sliced MVVM with a shared domain core**

TimeQuest is two apps in one shell: a parent setup tool and a player game. They share a data layer and domain logic but have completely separate UI flows. MVVM (Model-View-ViewModel) is the right fit because SwiftUI's reactive data binding maps directly to it, it is the de facto standard for SwiftUI apps, and it keeps game logic testable without UI dependencies.

The architecture has four layers stacked bottom-to-top:

```
+----------------------------------------------------------+
|                      UI Layer                            |
|  +------------------+    +----------------------------+  |
|  |  Parent Flow     |    |  Player Flow               |  |
|  |  - Routine Setup |    |  - Challenge Screen        |  |
|  |  - Task Editor   |    |  - Results/Feedback        |  |
|  |  - Progress View |    |  - Progression Dashboard   |  |
|  +------------------+    |  - Reward Showcase          |  |
|                          +----------------------------+  |
+----------------------------------------------------------+
|                   ViewModel Layer                         |
|  +------------------+    +----------------------------+  |
|  | ParentViewModel  |    | GameViewModel              |  |
|  | RoutineViewModel |    | ChallengeViewModel         |  |
|  |                  |    | ProgressionViewModel       |  |
|  +------------------+    +----------------------------+  |
+----------------------------------------------------------+
|                   Domain Layer (shared)                   |
|  +--------------------------------------------------+   |
|  | GameEngine          | ProgressionEngine           |   |
|  | - Challenge logic   | - XP / level calculation    |   |
|  | - Accuracy scoring  | - Streak tracking           |   |
|  | - Difficulty curves  | - Unlock rules             |   |
|  +--------------------------------------------------+   |
|  | RoutineManager      | TimeEstimationScorer        |   |
|  | - Routine CRUD      | - Accuracy algorithms       |   |
|  | - Task ordering     | - Trend analysis            |   |
|  +--------------------------------------------------+   |
+----------------------------------------------------------+
|                   Data Layer                              |
|  +--------------------------------------------------+   |
|  | SwiftData Models    | Repository Protocol          |   |
|  | - Routine           | - RoutineRepository         |   |
|  | - Task              | - SessionRepository         |   |
|  | - GameSession       | - ProgressRepository        |   |
|  | - EstimationResult  |                             |   |
|  | - PlayerProgress    |                             |   |
|  +--------------------------------------------------+   |
+----------------------------------------------------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With | Owns |
|-----------|---------------|-------------------|------|
| **RoleRouter** | Determines which UI flow to show (parent vs player) | AppEntry, both UI flows | Current role state |
| **Parent UI Flow** | Routine creation, task editing, viewing player progress | ParentViewModel, RoutineViewModel | Nothing (stateless views) |
| **Player UI Flow** | Game challenges, feedback screens, progression display | GameViewModel, ChallengeViewModel, ProgressionViewModel | Nothing (stateless views) |
| **ParentViewModel** | Mediates parent UI to domain logic | RoutineManager, ProgressRepository | Parent-side presentation state |
| **GameViewModel** | Orchestrates a game session from start to results | GameEngine, RoutineRepository, SessionRepository | Active session state |
| **ChallengeViewModel** | Manages a single time-estimation challenge | TimeEstimationScorer | Timer state, current challenge |
| **ProgressionViewModel** | Calculates and presents progression data | ProgressionEngine, ProgressRepository | Derived stats, level info |
| **GameEngine** | Core game loop: pick challenge, evaluate, advance | RoutineRepository (reads), TimeEstimationScorer | Difficulty state, challenge selection |
| **ProgressionEngine** | XP calculation, level thresholds, streak logic, unlocks | ProgressRepository | Progression rules (pure logic) |
| **TimeEstimationScorer** | Scores accuracy of a time estimate vs actual duration | None (pure function) | Scoring algorithms |
| **RoutineManager** | CRUD for routines and tasks | RoutineRepository | Validation rules |
| **SwiftData Models** | Persistent data definitions | SwiftData framework | Schema, migrations |
| **Repositories** | Abstract data access behind protocol | SwiftData ModelContext | Query logic, save logic |

### Data Flow

**Parent setup flow (write path):**

```
Parent taps "Add Routine"
  -> ParentView captures input
    -> ParentViewModel validates via RoutineManager
      -> RoutineManager calls RoutineRepository.save()
        -> SwiftData persists to local SQLite store
```

**Player game flow (read-play-write path):**

```
Player starts a session
  -> GameViewModel asks GameEngine to select challenges
    -> GameEngine reads from RoutineRepository (routines parent created)
    -> GameEngine builds challenge set based on difficulty curve

Player estimates time for a task
  -> ChallengeViewModel captures estimate + starts real timer
  -> Player taps "done" when they think time is up
  -> ChallengeViewModel sends (estimate, actual) to TimeEstimationScorer
    -> Scorer returns accuracy result
  -> GameViewModel records result via SessionRepository

Session ends
  -> GameViewModel sends session results to ProgressionEngine
    -> ProgressionEngine calculates XP, checks level-ups, streaks
    -> ProgressionEngine returns progression delta
  -> GameViewModel saves via ProgressRepository
  -> ProgressionViewModel updates dashboard
```

**Cross-role data bridge (how parent content becomes player challenges):**

```
Parent creates Routine("School Morning") with Tasks:
  ["Shower", "Get dressed", "Eat breakfast", "Brush teeth", "Pack bag"]

GameEngine reads Routines -> selects subset -> wraps as Challenges:
  Challenge("How long does 'Shower' take?", routine: "School Morning")

Player never sees "Routine" or "Task" language. They see:
  "School Morning Quest" with challenge steps.
```

This is the critical architectural insight: parent-created data is the source, but the player UI completely re-skins it as game content. The domain layer transforms structured routines into game challenges. The player should never encounter setup-oriented language.

## Patterns to Follow

### Pattern 1: Role Router with Simple PIN Gate

**What:** A lightweight entry point that routes to parent or player UI. Parent mode is protected by a simple PIN (not full auth -- this is a single-device, single-family app).

**When:** At app launch, always. Default to player mode so the game feels like hers.

**Why:** Keeps the two UIs completely separate. The player never accidentally sees setup screens. The parent can access setup without the player feeling surveilled.

```swift
// RoleRouter.swift
enum AppRole {
    case player
    case parent
}

struct RoleRouter: View {
    @State private var currentRole: AppRole = .player
    @State private var showingPINEntry = false

    var body: some View {
        switch currentRole {
        case .player:
            PlayerTabView(onRequestParentMode: {
                showingPINEntry = true
            })
            .sheet(isPresented: $showingPINEntry) {
                PINEntryView(onSuccess: {
                    currentRole = .parent
                    showingPINEntry = false
                })
            }
        case .parent:
            ParentTabView(onExitParentMode: {
                currentRole = .player
            })
        }
    }
}
```

**Key decisions:**
- Default to player mode. The app is hers first.
- PIN, not biometrics. Parent enters PIN on the player's phone. Biometrics would be the player's face/fingerprint.
- Switching back to player mode requires no authentication. Parent exits freely.
- No "parent mode" visible in player UI beyond a discrete settings icon. A long-press or hidden gesture to access it is even better.

### Pattern 2: Repository Protocol for Testability

**What:** Abstract data access behind a protocol so domain logic can be tested with in-memory fakes.

**When:** All data access from domain layer and ViewModels.

**Why:** SwiftData's ModelContext is tied to the main actor and view lifecycle. Wrapping it in a protocol means GameEngine and ProgressionEngine can be unit tested with mock data, no SwiftData container needed.

```swift
// RoutineRepository.swift
protocol RoutineRepositoryProtocol {
    func fetchAll() -> [Routine]
    func fetchActive() -> [Routine]
    func save(_ routine: Routine) throws
    func delete(_ routine: Routine) throws
}

// SwiftDataRoutineRepository.swift
@MainActor
final class SwiftDataRoutineRepository: RoutineRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() -> [Routine] {
        let descriptor = FetchDescriptor<Routine>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func save(_ routine: Routine) throws {
        modelContext.insert(routine)
        try modelContext.save()
    }
    // ...
}
```

### Pattern 3: Pure Domain Engines (No Framework Dependencies)

**What:** GameEngine, ProgressionEngine, and TimeEstimationScorer are plain Swift classes/structs with zero SwiftUI or SwiftData imports. They take data in, return results out.

**When:** All game logic, scoring, and progression calculation.

**Why:** Testability, reusability, and cognitive simplicity. A solo developer can reason about game balance in isolation from UI and persistence concerns.

```swift
// TimeEstimationScorer.swift — pure function, no dependencies
struct EstimationResult {
    let estimatedSeconds: TimeInterval
    let actualSeconds: TimeInterval
    let accuracyPercent: Double      // 100 = perfect
    let rating: AccuracyRating       // .perfect, .close, .off, .wayOff
}

enum AccuracyRating: String, Codable {
    case perfect    // within 5%
    case close      // within 15%
    case off        // within 30%
    case wayOff     // beyond 30%
}

struct TimeEstimationScorer {
    static func score(estimated: TimeInterval, actual: TimeInterval) -> EstimationResult {
        let difference = abs(estimated - actual)
        let accuracy = max(0, 100 - (difference / actual * 100))
        let rating: AccuracyRating = switch accuracy {
            case 95...100: .perfect
            case 85..<95:  .close
            case 70..<85:  .off
            default:       .wayOff
        }
        return EstimationResult(
            estimatedSeconds: estimated,
            actualSeconds: actual,
            accuracyPercent: accuracy,
            rating: rating
        )
    }
}
```

### Pattern 4: Observable ViewModel with SwiftUI's @Observable Macro

**What:** Use the `@Observable` macro (iOS 17+) for ViewModels instead of older `ObservableObject` + `@Published` pattern.

**When:** Every ViewModel.

**Why:** `@Observable` has finer-grained change tracking (only re-renders views that read changed properties), simpler syntax, and is Apple's current recommended approach. It replaced ObservableObject as the standard pattern starting with iOS 17 / WWDC 2023.

```swift
@Observable
final class GameViewModel {
    var currentChallenge: Challenge?
    var sessionResults: [EstimationResult] = []
    var isSessionActive = false

    private let gameEngine: GameEngine
    private let sessionRepository: SessionRepositoryProtocol

    init(gameEngine: GameEngine, sessionRepository: SessionRepositoryProtocol) {
        self.gameEngine = gameEngine
        self.sessionRepository = sessionRepository
    }

    func startSession(routine: Routine) {
        currentChallenge = gameEngine.nextChallenge(for: routine)
        isSessionActive = true
    }

    func submitEstimate(_ estimated: TimeInterval, actual: TimeInterval) {
        let result = TimeEstimationScorer.score(estimated: estimated, actual: actual)
        sessionResults.append(result)
        currentChallenge = gameEngine.nextChallenge()
    }
}
```

### Pattern 5: Navigation via Enums (Type-Safe Routing)

**What:** Model navigation state as enums, use `NavigationStack` with path-based navigation.

**When:** All navigation within both parent and player flows.

**Why:** Prevents invalid navigation states. Makes deep linking possible later. Keeps navigation logic in ViewModels, not scattered across views.

```swift
enum PlayerRoute: Hashable {
    case home
    case routineSelection
    case challenge(routine: Routine)
    case results(session: GameSession)
    case progression
    case rewards
}

struct PlayerTabView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            PlayerHomeView()
                .navigationDestination(for: PlayerRoute.self) { route in
                    switch route {
                    case .home: PlayerHomeView()
                    case .routineSelection: RoutineSelectionView()
                    case .challenge(let routine): ChallengeView(routine: routine)
                    case .results(let session): ResultsView(session: session)
                    case .progression: ProgressionView()
                    case .rewards: RewardsView()
                    }
                }
        }
    }
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: God ViewModel

**What:** Putting all game logic, scoring, persistence, and UI state into a single massive ViewModel.

**Why bad:** For a solo developer this seems faster initially but becomes impossible to debug when game balance, persistence, and UI state interact unpredictably. A bug in scoring logic requires mentally parsing UI transition code.

**Instead:** Separate concerns into domain engines (GameEngine, ProgressionEngine, TimeEstimationScorer) that the ViewModel orchestrates. Each piece is small enough to hold in your head.

### Anti-Pattern 2: SwiftData Models as ViewModels

**What:** Passing `@Model` objects directly into views and mutating them from UI code.

**Why bad:** Blurs the line between persistence and presentation. Changes auto-save (SwiftData auto-saves on context changes), making it hard to implement "cancel" or "undo" in the parent editor. Also couples views to the persistence framework.

**Instead:** ViewModels read from repositories, hold presentation state, and explicitly save through repositories when the user confirms. Use value types (structs) for in-flight editing state, converting to/from SwiftData models on load/save.

### Anti-Pattern 3: Shared Mutable State Between Roles

**What:** Parent and player ViewModels sharing the same observable objects or directly modifying each other's state.

**Why bad:** Creates subtle bugs where parent edits mid-session corrupt player state. Also makes the "invisible parent" design goal harder -- UI code starts needing to know which role is active.

**Instead:** The roles share a data layer (repositories) but never share ViewModel instances. When the player starts a session, the GameEngine snapshots the routine data it needs. Parent edits to routines take effect on the next session, not mid-game.

### Anti-Pattern 4: UserDefaults for Structured Data

**What:** Storing routines, sessions, or progress in UserDefaults as encoded JSON blobs.

**Why bad:** No querying, no relationships, no migration path, no concurrent access safety. Works for preferences (PIN, theme, app settings) but fails for structured domain data that grows over time.

**Instead:** SwiftData for all domain data (routines, tasks, sessions, results, progress). UserDefaults only for true preferences: parent PIN hash, theme selection, onboarding-completed flags.

### Anti-Pattern 5: Timer Logic in Views

**What:** Using `Timer.publish` or `Task.sleep` directly in SwiftUI views for the time estimation challenge.

**Why bad:** Timers in views are fragile -- they break on view redraws, background/foreground transitions, and sheet presentations. The most critical feature (accurate time measurement) would be the least reliable code.

**Instead:** Timer logic lives in the ChallengeViewModel or a dedicated `ChallengeTimer` service. The ViewModel publishes elapsed time; the view just displays it. The ViewModel handles background/foreground transitions via `ScenePhase` observation.

## SwiftData Model Design

The data model is the foundation everything else builds on. Here is the recommended schema.

```swift
// MARK: - Parent-Created Content

@Model
final class Routine {
    var name: String                    // "School Morning"
    var displayName: String             // "Morning Quest" (player-facing)
    var tasks: [RoutineTask]            // ordered list
    var isActive: Bool                  // parent can deactivate
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade)
    var sessions: [GameSession]
}

@Model
final class RoutineTask {
    var name: String                    // "Take a shower"
    var displayName: String             // "Shower Power" (player-facing)
    var estimatedDurationSeconds: Int?  // parent's reference (hidden from player)
    var orderIndex: Int
    var routine: Routine?               // back-reference
}

// MARK: - Player-Generated Data

@Model
final class GameSession {
    var routine: Routine?
    var startedAt: Date
    var completedAt: Date?
    var results: [EstimationEntry]
    var totalXPEarned: Int
    var sessionRating: String           // overall session performance
}

@Model
final class EstimationEntry {
    var task: RoutineTask?
    var estimatedSeconds: Double
    var actualSeconds: Double
    var accuracyPercent: Double
    var rating: String                  // AccuracyRating raw value
    var session: GameSession?
    var recordedAt: Date
}

// MARK: - Progression State

@Model
final class PlayerProgress {
    var currentLevel: Int
    var totalXP: Int
    var currentStreak: Int              // consecutive days played
    var longestStreak: Int
    var lastPlayedDate: Date?
    var unlockedRewards: [String]       // reward IDs
    var averageAccuracy: Double         // rolling average
    var totalSessions: Int
}
```

**Why this schema:**
- Routine and RoutineTask are parent-owned. They have both internal names and player-facing display names to maintain the game illusion.
- GameSession and EstimationEntry are player-owned. They reference routines/tasks but are created during gameplay.
- PlayerProgress is a singleton (one row). It is the denormalized "fast read" for the player dashboard. Updated at session end.
- Cascade deletes: deleting a routine cascades to its sessions. This is safe because the parent controls routine lifecycle.

## Dependency Injection Strategy

For a solo developer project, avoid DI frameworks. Use simple initializer injection with a composition root.

```swift
// AppDependencies.swift — the composition root
@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer

    // Repositories
    lazy var routineRepository: RoutineRepositoryProtocol = {
        SwiftDataRoutineRepository(modelContext: modelContainer.mainContext)
    }()
    lazy var sessionRepository: SessionRepositoryProtocol = {
        SwiftDataSessionRepository(modelContext: modelContainer.mainContext)
    }()
    lazy var progressRepository: ProgressRepositoryProtocol = {
        SwiftDataProgressRepository(modelContext: modelContainer.mainContext)
    }()

    // Domain engines
    lazy var scorer = TimeEstimationScorer()
    lazy var gameEngine: GameEngine = {
        GameEngine(routineRepository: routineRepository, scorer: scorer)
    }()
    lazy var progressionEngine: ProgressionEngine = {
        ProgressionEngine(progressRepository: progressRepository)
    }()

    // ViewModels (created fresh per screen, not shared)
    func makeGameViewModel() -> GameViewModel {
        GameViewModel(gameEngine: gameEngine, sessionRepository: sessionRepository)
    }
    func makeParentViewModel() -> ParentViewModel {
        ParentViewModel(routineManager: RoutineManager(repository: routineRepository))
    }
    func makeProgressionViewModel() -> ProgressionViewModel {
        ProgressionViewModel(progressionEngine: progressionEngine)
    }

    init() {
        self.modelContainer = try! ModelContainer(for:
            Routine.self, RoutineTask.self,
            GameSession.self, EstimationEntry.self,
            PlayerProgress.self
        )
    }
}
```

Injected via SwiftUI environment at the app root:

```swift
@main
struct TimeQuestApp: App {
    let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RoleRouter()
                .environment(dependencies)
                .modelContainer(dependencies.modelContainer)
        }
    }
}
```

## Project File Structure

```
TimeQuest/
  App/
    TimeQuestApp.swift              # @main entry point
    AppDependencies.swift           # Composition root
    RoleRouter.swift                # Parent/player mode switching

  Models/                           # SwiftData models
    Routine.swift
    RoutineTask.swift
    GameSession.swift
    EstimationEntry.swift
    PlayerProgress.swift

  Repositories/                     # Data access layer
    Protocols/
      RoutineRepositoryProtocol.swift
      SessionRepositoryProtocol.swift
      ProgressRepositoryProtocol.swift
    SwiftDataRoutineRepository.swift
    SwiftDataSessionRepository.swift
    SwiftDataProgressRepository.swift

  Domain/                           # Pure game logic
    GameEngine.swift                # Challenge selection, session orchestration
    ProgressionEngine.swift         # XP, levels, streaks, unlocks
    TimeEstimationScorer.swift      # Accuracy scoring
    RoutineManager.swift            # Routine validation, CRUD orchestration
    DifficultyCalculator.swift      # Adjusts challenge difficulty over time

  Features/
    Parent/
      Views/
        ParentTabView.swift
        RoutineListView.swift
        RoutineEditorView.swift
        TaskEditorView.swift
        ParentProgressView.swift
      ViewModels/
        ParentViewModel.swift
        RoutineEditorViewModel.swift

    Player/
      Views/
        PlayerTabView.swift
        PlayerHomeView.swift
        RoutineSelectionView.swift  # "Choose your quest"
        ChallengeView.swift         # Core gameplay screen
        ResultsView.swift           # Post-challenge feedback
        ProgressionView.swift       # Level, XP, streaks
        RewardsView.swift           # Unlocked rewards showcase
      ViewModels/
        GameViewModel.swift
        ChallengeViewModel.swift
        ProgressionViewModel.swift

    Shared/
      Views/
        PINEntryView.swift
        AccuracyGaugeView.swift     # Reusable accuracy visualization
        StreakBadgeView.swift
      Components/
        TimerDisplay.swift
        ProgressRing.swift

  Utilities/
    DateFormatting.swift
    HapticManager.swift
    SoundManager.swift

  Resources/
    Assets.xcassets
    Sounds/
```

## Scalability Considerations

| Concern | At launch (1 user) | At 3 months (same user, lots of data) | If scope expands (siblings, cloud) |
|---------|--------------------|-----------------------------------------|-------------------------------------|
| **Data volume** | Tens of records. SwiftData is overkill but future-proof. | Hundreds of sessions. SwiftData handles this trivially. | SwiftData syncs to CloudKit with minor config changes. |
| **Performance** | No concerns. | Add FetchDescriptor predicates to limit date ranges for charts. | Lazy loading, pagination if needed. |
| **Multiple users** | Single PlayerProgress singleton. | Same. | Add a Player model. PlayerProgress becomes per-player. Routine gets a player relationship. Migration needed. |
| **Cloud sync** | Not needed. Local only. | Still not needed. | SwiftData + CloudKit. Requires iCloud entitlement and schema changes. Architecture supports this because repository protocol abstracts the storage. |
| **Routine complexity** | 2-3 routines, 5-7 tasks each. | 5-8 routines. No architectural change needed. | Routine templates, sharing between family members. Domain layer change only. |

## Build Order (Dependencies Between Components)

This build order respects technical dependencies and enables testing at each stage.

```
Phase 1: Foundation
  1. SwiftData Models (everything depends on these)
  2. Repository Protocols + SwiftData implementations
  3. AppDependencies composition root
  4. RoleRouter with PIN gate
  -- Testable: Data layer works, app launches, role switching works

Phase 2: Parent Flow
  5. RoutineManager (domain logic)
  6. ParentViewModel + RoutineEditorViewModel
  7. Parent UI views (RoutineListView, RoutineEditorView, TaskEditorView)
  -- Testable: Parent can create routines that persist

Phase 3: Core Gameplay
  8. TimeEstimationScorer (pure logic, test first)
  9. GameEngine (challenge selection, session flow)
  10. ChallengeViewModel (timer management, estimate capture)
  11. GameViewModel (session orchestration)
  12. Player gameplay views (ChallengeView, ResultsView)
  -- Testable: Player can play a session using parent-created routines

Phase 4: Progression System
  13. ProgressionEngine (XP, levels, streaks)
  14. ProgressionViewModel
  15. Player progression views (ProgressionView, RewardsView)
  16. ParentProgressView (parent can see how player is doing)
  -- Testable: Full game loop with persistence and progression

Phase 5: Polish
  17. HapticManager, SoundManager
  18. Visual polish, animations, theme
  19. Onboarding flow (first-time parent setup, player tutorial)
  20. Edge cases (background/foreground, interrupted sessions)
```

**Why this order:**
- Models and repositories first because every other component depends on data.
- Parent flow before player flow because the player needs routines to exist. Without parent-created content, there is nothing to play.
- Core gameplay before progression because progression wraps gameplay results. You cannot calculate XP without estimation results.
- Polish last because it touches everything and benefits from a working app to evaluate.

**Critical path dependency chain:**
```
Models -> Repositories -> RoutineManager -> Parent UI -> GameEngine -> ChallengeVM -> GameVM -> Player UI -> ProgressionEngine -> Progression UI
```

Each link in this chain depends on the previous one. Parallelization is limited: the parent and player UI code can be built concurrently only if the shared domain layer is done first.

## Sources

- SwiftData architecture patterns: Based on Apple's WWDC 2023 and 2024 SwiftData sessions and the `@Model` / `ModelContainer` / `ModelContext` API design. MEDIUM confidence (training knowledge verified against API design principles but official docs were inaccessible during research).
- `@Observable` macro: Introduced in iOS 17, WWDC 2023 "Discover Observation in SwiftUI." Replaces `ObservableObject` pattern. HIGH confidence (well-established pattern by 2025).
- NavigationStack path-based routing: Introduced in iOS 16, stable pattern. HIGH confidence.
- MVVM as SwiftUI standard: Community consensus and Apple sample code consistently use this pattern. HIGH confidence.
- Repository pattern for SwiftData: Common pattern in iOS community to abstract ModelContext. MEDIUM confidence (pattern is well-known; specific SwiftData API details may have evolved).
- Game architecture patterns: Based on general iOS game development patterns. Applied to non-SpriteKit context since TimeQuest is UI-driven, not frame-rendered. HIGH confidence for the pattern; game-specific tuning (difficulty curves, XP formulas) will need phase-specific research.

**Confidence note:** Web research tools were unavailable during this session. All recommendations are based on training data through May 2025. SwiftUI and SwiftData are mature frameworks unlikely to have had breaking architectural changes since then. The patterns recommended here (MVVM, repository, composition root, enum-based navigation) are foundational and stable. However, specific API signatures should be verified against Xcode's current SDK documentation during implementation.
