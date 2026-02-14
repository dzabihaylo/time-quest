# Architecture Patterns: v3.0 Integration

**Domain:** v3.0 feature integration into existing TimeQuest iOS app (adaptive difficulty, Spotify integration, calendar intelligence, UI/brand refresh)
**Researched:** 2026-02-14
**Overall Confidence:** MEDIUM (training data only -- web tools unavailable; Spotify SDK and EventKit patterns based on training data through May 2025; adaptive difficulty and theming recommendations based on codebase analysis + established iOS patterns)

---

## Existing Architecture Snapshot (Post-v2.0)

66 Swift files, 6,211 LOC. The codebase has clean architectural boundaries that the v3.0 features must respect.

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
|                           - SessionSummaryView      - InsightCardView  |
|                           - PlayerStatsView         - TimeFormatting   |
|                           - AccuracyTrendChartView                     |
|                           - OnboardingView                             |
|                           - NotificationSettingsView                   |
|                           - MyPatternsView                             |
|                           - WeeklyReflectionCardView                   |
|                           - PlayerRoutineCreationView                  |
+-----------------------------------------------------------------------+
| ViewModel Layer (@Observable, @MainActor)                              |
|  - RoutineEditorViewModel  (value-type RoutineEditState pattern)       |
|  - GameSessionViewModel    (QuestPhase state machine)                  |
|  - ProgressionViewModel    (chart data, personal bests)                |
|  - MyPatternsViewModel     (insight data from InsightEngine)           |
|  - WeeklyReflectionViewModel (reflection data + history)               |
|  - PlayerRoutineCreationViewModel (template-guided creation)           |
+-----------------------------------------------------------------------+
| Domain Layer (pure Foundation only, zero UI/SwiftData imports)         |
|  - TimeEstimationScorer    - XPEngine + XPConfiguration                |
|  - FeedbackGenerator       - LevelCalculator                           |
|  - CalibrationTracker      - StreakTracker                             |
|  - PersonalBestTracker     - InsightEngine                             |
|  - WeeklyReflectionEngine  - RoutineTemplateProvider                   |
+-----------------------------------------------------------------------+
| Data Layer (SwiftData + Repository Protocols)                          |
|  Models:       Routine, RoutineTask, GameSession, TaskEstimation,      |
|                PlayerProfile, WeeklyReflection (value type)            |
|  Bridge:       EstimationSnapshot (value type decoupling SwiftData)    |
|  Schemas:      SchemaV1 -> V2 -> V3 (lightweight migrations)          |
|  Repositories: RoutineRepositoryProtocol                               |
|                SessionRepositoryProtocol                                |
|                PlayerProfileRepositoryProtocol                          |
+-----------------------------------------------------------------------+
| App Layer                                                              |
|  - TimeQuestApp (ModelContainer + CloudKit with graceful fallback)     |
|  - ContentView (ModelContext -> AppDependencies bridge)                 |
|  - AppDependencies (@Observable composition root)                      |
|  - RoleRouter (AppRole enum, RoleState, PIN gate)                      |
+-----------------------------------------------------------------------+
| Services                                                               |
|  - SoundManager (AVAudioSession .ambient)                              |
|  - NotificationManager (UserNotifications)                             |
|  - CloudKitSyncMonitor                                                 |
+-----------------------------------------------------------------------+
```

### Key Architectural Patterns (Established, Must Continue)

1. **Pure domain engines**: All business logic in `Domain/` imports only Foundation. No SwiftData, no SwiftUI. Static methods on structs. Inputs and outputs are value types.
2. **EstimationSnapshot bridge**: SwiftData @Model objects are mapped to `EstimationSnapshot` value types before passing to domain engines. This decouples domain from persistence.
3. **Repository protocols**: `@MainActor` protocols with SwiftData implementations. AppDependencies holds concrete instances.
4. **QuestPhase state machine**: `.selecting -> .estimating -> .active -> .revealing -> .summary` in GameSessionViewModel.
5. **Composition root**: AppDependencies created in ContentView, injected via `.environment()`.
6. **XPConfiguration pattern**: Tunable constants centralized in a Sendable struct with static default.
7. **Schema versioned migrations**: V1->V2->V3 lightweight migrations via TimeQuestMigrationPlan.

---

## v3.0 Feature Integration Plan

### Overview: Four Pillars

| Pillar | Category | External Dependencies | Schema Changes | Existing Code Impact |
|--------|----------|----------------------|----------------|---------------------|
| Adaptive Difficulty | Pure domain engine | None | SchemaV4 (2 new fields on GameSession) | Modifies GameSessionViewModel |
| Spotify Integration | External service | Spotify iOS SDK (SpotifyiOS) | SchemaV4 (optional fields on Routine) | New feature area + SoundManager coordination |
| Calendar Intelligence | System framework | EventKit | None (reads only) | New service + integration into routine suggestions |
| UI/Brand Refresh | Visual layer | None | None | Touches all views (but additive, not structural) |

### Dependency Graph Between Pillars

```
Adaptive Difficulty -----> standalone (consumes EstimationSnapshot)
                    \
                     +---> both modify GameSessionViewModel
                    /
Spotify Integration -----> SoundManager coordination (audio ducking)

Calendar Intelligence ---> standalone (new CalendarService)
                      \--> routine suggestion UI (integrates with RoutineRepository)

UI/Brand Refresh ---------> touches all views (parallel-safe, no logic changes)
```

No pillar blocks another. They can be built in any order. The recommended order is based on risk and dependency density, not hard requirements.

---

## Pillar 1: AdaptiveDifficultyEngine

### Concept

Dynamically adjust task estimation difficulty based on the player's historical accuracy. When the player consistently nails estimates for a task, increase challenge (shorter reference windows, remove contextual hints, introduce distractor tasks). When struggling, ease parameters (provide hints, allow wider accuracy bands for XP).

### New Components

| Component | Layer | Type | File Path |
|-----------|-------|------|-----------|
| `AdaptiveDifficultyEngine` | Domain | Pure struct (static methods) | `Domain/AdaptiveDifficultyEngine.swift` |
| `DifficultyConfiguration` | Domain | Value type (struct) | `Domain/AdaptiveDifficultyEngine.swift` |
| `DifficultyLevel` | Domain | Enum | `Domain/AdaptiveDifficultyEngine.swift` |
| `DifficultySnapshot` | Domain | Value type (bridge output) | `Domain/AdaptiveDifficultyEngine.swift` |

### AdaptiveDifficultyEngine Design (Pure Domain)

```swift
// Domain/AdaptiveDifficultyEngine.swift
import Foundation

enum DifficultyLevel: String, Codable, Sendable {
    case learning       // New task or struggling: generous accuracy bands, always show hints
    case practicing     // Getting the hang of it: standard accuracy bands, show hints
    case confident      // Consistent accuracy: tighter bands, hints optional
    case mastering      // High accuracy streak: tightest bands, no hints, bonus XP
}

struct DifficultyParameters: Sendable {
    let level: DifficultyLevel
    let showContextualHint: Bool
    let accuracyBandMultiplier: Double  // 1.0 = standard, 1.5 = generous, 0.75 = tight
    let xpMultiplier: Double            // 1.0 = standard, 1.5 = mastering bonus
    let suggestTimerVisibility: Bool    // At "learning" level, offer optional timer
}

struct AdaptiveDifficultyEngine {

    // MARK: - Thresholds (follow XPConfiguration pattern)

    static let minimumSessionsForAdaptation = 5  // Same as InsightEngine.minimumSessions
    static let learningAccuracyThreshold = 40.0   // Below 40% avg -> learning
    static let practicingAccuracyThreshold = 60.0  // 40-60% -> practicing
    static let confidentAccuracyThreshold = 80.0   // 60-80% -> confident
    // Above 80% -> mastering

    /// Determine difficulty parameters for a specific task based on estimation history.
    /// Pure function: snapshots in, parameters out.
    static func computeDifficulty(
        taskName: String,
        snapshots: [EstimationSnapshot]
    ) -> DifficultyParameters {
        let taskSnapshots = snapshots
            .filter { $0.taskDisplayName == taskName && !$0.isCalibration }
            .sorted { $0.recordedAt < $1.recordedAt }

        guard taskSnapshots.count >= minimumSessionsForAdaptation else {
            return DifficultyParameters(
                level: .learning,
                showContextualHint: true,
                accuracyBandMultiplier: 1.5,
                xpMultiplier: 1.0,
                suggestTimerVisibility: true
            )
        }

        // Use recent window (last 5-10 sessions) for responsiveness
        let recentWindow = Array(taskSnapshots.suffix(10))
        let avgAccuracy = recentWindow.map(\.accuracyPercent).reduce(0, +)
            / Double(recentWindow.count)

        let level: DifficultyLevel
        if avgAccuracy < learningAccuracyThreshold {
            level = .learning
        } else if avgAccuracy < practicingAccuracyThreshold {
            level = .practicing
        } else if avgAccuracy < confidentAccuracyThreshold {
            level = .confident
        } else {
            level = .mastering
        }

        return parameters(for: level)
    }

    /// Map difficulty level to concrete parameters.
    static func parameters(for level: DifficultyLevel) -> DifficultyParameters {
        switch level {
        case .learning:
            return DifficultyParameters(
                level: .learning,
                showContextualHint: true,
                accuracyBandMultiplier: 1.5,
                xpMultiplier: 1.0,
                suggestTimerVisibility: true
            )
        case .practicing:
            return DifficultyParameters(
                level: .practicing,
                showContextualHint: true,
                accuracyBandMultiplier: 1.2,
                xpMultiplier: 1.0,
                suggestTimerVisibility: false
            )
        case .confident:
            return DifficultyParameters(
                level: .confident,
                showContextualHint: false,
                accuracyBandMultiplier: 1.0,
                xpMultiplier: 1.2,
                suggestTimerVisibility: false
            )
        case .mastering:
            return DifficultyParameters(
                level: .mastering,
                showContextualHint: false,
                accuracyBandMultiplier: 0.75,
                xpMultiplier: 1.5,
                suggestTimerVisibility: false
            )
        }
    }
}
```

### Integration with Existing Code

**GameSessionViewModel is the primary integration point.** It already loads contextual hints during `startQuest()` and scores estimations in `completeActiveTask()`.

| Existing Component | Change | Impact |
|-------------------|--------|--------|
| `GameSessionViewModel.startQuest()` | After loading contextual hints, also compute `DifficultyParameters` for each task via `AdaptiveDifficultyEngine.computeDifficulty()` | MODERATE -- adds a new stored dictionary `taskDifficulty: [String: DifficultyParameters]` |
| `GameSessionViewModel.contextualHints` | Already exists. Difficulty engine's `showContextualHint` flag now controls whether to populate it. | MINOR -- adds conditional check |
| `XPEngine.xpForEstimation()` | Must accept `xpMultiplier` from difficulty parameters. Or: XPEngine stays pure, ViewModel applies multiplier after calling it. | **Recommendation: ViewModel applies multiplier** -- keeps XPEngine unchanged |
| `TimeEstimationScorer.score()` | `accuracyBandMultiplier` adjusts what counts as "spot_on", "close", etc. Two options: (a) scorer accepts multiplier parameter, or (b) scorer stays pure, ViewModel remaps rating post-scoring. | **Recommendation: Scorer accepts optional multiplier** -- cleaner than post-hoc remapping |
| `EstimationInputView` | Show/hide contextual hint based on difficulty. At `.learning` level, optionally show a "need help?" timer toggle. | MINOR UI addition |
| `AccuracyRevealView` | At `.mastering` level, show bonus XP indicator. At `.learning` level, show encouragement. | MINOR UI addition |
| `InsightEngine` | No changes -- difficulty engine consumes the same `[EstimationSnapshot]` input. | None |

### Data Flow

```
GameSessionViewModel.startQuest()
  -> fetch all estimations (already done for contextual hints)
  -> map to [EstimationSnapshot] (already done)
  -> for each task in routine:
       AdaptiveDifficultyEngine.computeDifficulty(taskName:, snapshots:)
       -> store in taskDifficulty[taskName]
  -> when showing EstimationInputView:
       if taskDifficulty[currentTask].showContextualHint -> show hint
       else -> hide hint
  -> when scoring in completeActiveTask():
       let baseResult = TimeEstimationScorer.score(estimated:, actual:,
           accuracyBandMultiplier: difficulty.accuracyBandMultiplier)
       let adjustedXP = Int(Double(XPEngine.xpForEstimation(rating: result.rating))
           * difficulty.xpMultiplier)
```

### Schema Changes

**SchemaV4 additions to GameSession:**

```swift
// Track which difficulty level was active for this session
// This enables analyzing whether difficulty adaptation is working
var difficultyLevelRawValue: String = "learning"  // DifficultyLevel.rawValue
```

**SchemaV4 additions to TaskEstimation:**

```swift
// Track the accuracy band multiplier used when scoring this estimation
// Enables fair historical comparisons (a "spot_on" at 0.75x is harder than at 1.5x)
var accuracyBandMultiplier: Double = 1.0
```

Both are additive with defaults -- lightweight migration. Existing records get default values that match their actual scoring conditions (standard bands, learning level).

---

## Pillar 2: Spotify Integration (SpotifyService)

### Concept

The player can attach a "quest playlist" to a routine. When a quest starts, Spotify plays the playlist. Music provides a temporal anchor -- "this song usually plays during teeth-brushing" helps build time intuition through auditory cues. The parent dashboard allows connecting/disconnecting the Spotify account.

### Architecture Decision: Spotify iOS SDK vs. Web API

**Use the Spotify iOS SDK (SpotifyiOS framework) for playback control, and the Spotify Web API for playlist management.**

Rationale:
- The iOS SDK handles OAuth (via `SPTSessionManager`), playback control (via `SPTAppRemote`), and deep-links to the Spotify app. It requires the Spotify app to be installed.
- The Web API handles playlist creation and reading playlist contents. It uses standard REST with the OAuth token obtained from the iOS SDK.
- The iOS SDK cannot create playlists -- that is a Web API operation.
- Playback requires the Spotify app on device. The iOS SDK controls the Spotify app's player remotely via `SPTAppRemote`.

**Confidence: MEDIUM** -- Spotify iOS SDK APIs are based on training data through May 2025. The SDK has been stable since 2019 but may have received updates. Verify current SDK version and API surface before implementation.

### New Components

| Component | Layer | Type | File Path |
|-----------|-------|------|-----------|
| `SpotifyService` | Services | @Observable class | `Services/SpotifyService.swift` |
| `SpotifyAuthManager` | Services | Class (handles OAuth + token storage) | `Services/SpotifyAuthManager.swift` |
| `SpotifyConfiguration` | Domain | Struct (client ID, redirect URI, scopes) | `Domain/SpotifyConfiguration.swift` |
| `SpotifyPlaylistViewModel` | ViewModel | @Observable @MainActor | `Features/Parent/ViewModels/SpotifyPlaylistViewModel.swift` |
| `SpotifyConnectView` | View | SwiftUI | `Features/Parent/Views/SpotifyConnectView.swift` |
| `SpotifyPlaylistPickerView` | View | SwiftUI | `Features/Parent/Views/SpotifyPlaylistPickerView.swift` |
| `QuestMusicBannerView` | View | SwiftUI | `Features/Player/Views/QuestMusicBannerView.swift` |

### SpotifyService Design

```swift
// Services/SpotifyService.swift
import Foundation

enum SpotifyConnectionState: Sendable {
    case disconnected
    case connecting
    case connected(userName: String)
    case error(String)
}

@MainActor
@Observable
final class SpotifyService {
    var connectionState: SpotifyConnectionState = .disconnected
    var isPlaying: Bool = false
    var currentTrackName: String?

    // MARK: - Auth

    /// Initiate OAuth flow. Opens Spotify app or web auth.
    func connect() { /* SPTSessionManager.initiateSession() */ }

    /// Disconnect and clear stored tokens.
    func disconnect() { /* Clear Keychain tokens */ }

    /// Handle redirect URL from Spotify OAuth callback.
    func handleAuthCallback(url: URL) -> Bool { /* Parse token */ }

    // MARK: - Playback Control

    /// Start playing a playlist by Spotify URI.
    func play(playlistURI: String) { /* SPTAppRemote.playerAPI.play() */ }

    /// Pause playback.
    func pause() { /* SPTAppRemote.playerAPI.pause() */ }

    /// Resume playback.
    func resume() { /* SPTAppRemote.playerAPI.resume() */ }

    // MARK: - Playlist Discovery

    /// Fetch user's playlists from Spotify Web API.
    func fetchUserPlaylists() async throws -> [SpotifyPlaylist] { /* Web API call */ }

    // MARK: - Token Storage

    /// Store/retrieve OAuth token from Keychain (not UserDefaults -- tokens are sensitive).
    private func storeToken(_ token: String) { /* Keychain */ }
    private func retrieveToken() -> String? { /* Keychain */ }
}

struct SpotifyPlaylist: Identifiable, Sendable {
    let id: String          // Spotify playlist ID
    let name: String
    let uri: String         // spotify:playlist:xxxxx
    let imageURL: URL?
    let trackCount: Int
}
```

### Audio Coordination with SoundManager

**Critical design consideration:** The existing SoundManager uses `AVAudioSession.sharedInstance().setCategory(.ambient)`. This means game sounds mix with other audio. Spotify playback uses its own audio session (in the Spotify app). The coordination works naturally:

- **SoundManager** plays short SFX (0.2-2.0s) in `.ambient` mode -- these overlay on top of Spotify music.
- **SpotifyService** controls the Spotify app's playback -- Spotify manages its own audio session.
- **No audio session conflict** because SoundManager uses `.ambient` (never steals audio focus) and Spotify runs in a separate process.

**The only coordination needed:** When showing the accuracy reveal (a dramatic moment), optionally duck the Spotify volume briefly. `SPTAppRemote.playerAPI` does not support volume control directly, but we can pause/resume around the reveal animation.

```
AccuracyRevealView appears:
  -> SpotifyService.pause()  // Brief pause for dramatic reveal
  -> SoundManager.play("reveal")
  -> 2-second delay
  -> SpotifyService.resume()
```

### Integration with Existing Code

| Existing Component | Change | Impact |
|-------------------|--------|--------|
| `AppDependencies` | Add `spotifyService: SpotifyService` property | MINOR -- new service added to composition root |
| `TimeQuestApp` | Handle Spotify OAuth redirect URL via `onOpenURL` modifier | MINOR addition |
| `Routine` model | Add optional `spotifyPlaylistURI: String?` field (SchemaV4) | MINOR schema addition |
| `GameSessionViewModel.startQuest()` | If routine has spotifyPlaylistURI, call `spotifyService.play()` | MINOR addition |
| `GameSessionViewModel.finishQuest()` | Call `spotifyService.pause()` | MINOR addition |
| `ParentDashboardView` | Add "Connect Spotify" section and playlist picker per routine | MODERATE UI addition |
| `QuestView` | Show small "Now Playing" banner during active quest | MINOR UI addition |
| `SoundManager` | No changes -- `.ambient` audio session already allows overlay | None |

### Data Flow: Connecting Spotify (Parent Flow)

```
ParentDashboardView
  -> "Connect Spotify" button
    -> SpotifyService.connect()
      -> Opens Spotify app for OAuth
      -> User authorizes
      -> Redirect back to TimeQuest
    -> TimeQuestApp.onOpenURL
      -> SpotifyService.handleAuthCallback(url:)
      -> connectionState = .connected

ParentDashboardView (per routine)
  -> "Set Quest Playlist" button
    -> SpotifyPlaylistPickerView
      -> SpotifyService.fetchUserPlaylists()
      -> User selects playlist
      -> routine.spotifyPlaylistURI = playlist.uri
      -> Save via RoutineRepository
```

### Data Flow: Playing Music (Player Flow)

```
QuestView.onAppear
  -> GameSessionViewModel.startQuest()
    -> if let uri = routine.spotifyPlaylistURI:
         spotifyService.play(playlistURI: uri)
    -> QuestMusicBannerView appears showing "Now Playing: [playlist name]"

AccuracyRevealView.onAppear
  -> spotifyService.pause()
  -> soundManager.play("reveal")
  -> after 2s: spotifyService.resume()

SessionSummaryView (quest complete)
  -> GameSessionViewModel.finishQuest()
    -> spotifyService.pause()
```

### Schema Changes

**SchemaV4 additions to Routine:**

```swift
var spotifyPlaylistURI: String?   // Optional: "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M"
var spotifyPlaylistName: String?  // Cached display name to avoid API call for UI
```

### OAuth and Security

- **Token storage:** Use Keychain, not UserDefaults. OAuth tokens are credentials.
- **Scopes needed:** `user-read-playback-state`, `user-modify-playback-state`, `playlist-read-private`, `playlist-read-collaborative`.
- **No playlist creation scope needed** for v3.0 -- we only read existing playlists. Creating playlists from within TimeQuest can be deferred to a later version.
- **Redirect URI:** Register `timequest://spotify-callback` as a URL scheme in Info.plist and in the Spotify Developer Dashboard.
- **Client ID:** Store in a configuration file or environment variable, NOT hardcoded. Use `SpotifyConfiguration.swift` with a placeholder that gets replaced at build time.
- **Spotify app requirement:** The iOS SDK requires the Spotify app to be installed for playback. If not installed, show a graceful message: "Install Spotify to add music to your quests." No crash, no broken state.

### Spotify-Not-Installed Fallback

```swift
// SpotifyService.swift
var isSpotifyInstalled: Bool {
    UIApplication.shared.canOpenURL(URL(string: "spotify:")!)
}

func connect() {
    guard isSpotifyInstalled else {
        connectionState = .error("Spotify app not installed")
        return
    }
    // ... proceed with OAuth
}
```

---

## Pillar 3: Calendar Intelligence (CalendarService)

### Concept

Read the player's (or family's) calendar to detect upcoming events and suggest time-relevant routines. "You have soccer practice at 4 PM -- want to start your 'Activity Prep' quest at 3:15?" This builds real-world time awareness by connecting estimation practice to actual scheduled events.

### Architecture Decision: EventKit Directly, No Wrapper

**Use EventKit (EKEventStore) directly.** EventKit is Apple's framework for reading calendar data. It is mature, well-documented, and the API surface needed is small (read events for a date range). No third-party wrapper adds value.

**Confidence: HIGH** -- EventKit API has been stable since iOS 6. The permission model changed slightly in iOS 17 (added write-only vs full access distinction), but read access request patterns are well-established.

### New Components

| Component | Layer | Type | File Path |
|-----------|-------|------|-----------|
| `CalendarService` | Services | @Observable class | `Services/CalendarService.swift` |
| `CalendarEvent` | Domain | Value type (struct) | `Domain/CalendarEvent.swift` |
| `ScheduleSuggestionEngine` | Domain | Pure struct (static methods) | `Domain/ScheduleSuggestionEngine.swift` |
| `ScheduleSuggestion` | Domain | Value type (struct) | `Domain/ScheduleSuggestionEngine.swift` |
| `CalendarPermissionView` | View | SwiftUI | `Features/Shared/Views/CalendarPermissionView.swift` |
| `ScheduleSuggestionsView` | View | SwiftUI | `Features/Player/Views/ScheduleSuggestionsView.swift` |

### CalendarService Design

```swift
// Services/CalendarService.swift
import EventKit

enum CalendarPermissionState: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

@MainActor
@Observable
final class CalendarService {
    var permissionState: CalendarPermissionState = .notDetermined
    var todayEvents: [CalendarEvent] = []

    private let eventStore = EKEventStore()

    // MARK: - Permissions

    func requestAccess() async {
        // iOS 17+: requestFullAccessToEvents()
        // Fallback: requestAccess(to: .event)
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            permissionState = granted ? .authorized : .denied
        } catch {
            permissionState = .denied
        }
    }

    func checkCurrentPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            permissionState = .authorized
        case .denied:
            permissionState = .denied
        case .restricted:
            permissionState = .restricted
        case .notDetermined:
            permissionState = .notDetermined
        case .writeOnly:
            // We need read access, writeOnly is insufficient
            permissionState = .denied
        @unknown default:
            permissionState = .notDetermined
        }
    }

    // MARK: - Event Fetching

    func fetchTodayEvents() {
        guard permissionState == .authorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil  // All calendars
        )

        let ekEvents = eventStore.events(matching: predicate)
        todayEvents = ekEvents
            .filter { !$0.isAllDay }  // Only timed events are useful for scheduling
            .map { CalendarEvent(from: $0) }
            .sorted { $0.startDate < $1.startDate }
    }

    func fetchEvents(for dateRange: DateInterval) -> [CalendarEvent] {
        guard permissionState == .authorized else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: dateRange.start,
            end: dateRange.end,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .map { CalendarEvent(from: $0) }
            .sorted { $0.startDate < $1.startDate }
    }
}
```

### CalendarEvent Value Type (Domain Bridge)

```swift
// Domain/CalendarEvent.swift
import Foundation

/// Value type that bridges EventKit EKEvent to the pure domain layer.
/// Follows the EstimationSnapshot pattern: decouples domain engines from framework types.
struct CalendarEvent: Identifiable, Sendable {
    let id: String           // EKEvent.eventIdentifier
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarName: String

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    var minutesUntilStart: Int {
        Int(startDate.timeIntervalSince(.now) / 60)
    }
}

// Bridge extension (lives alongside CalendarService, not in Domain/)
import EventKit

extension CalendarEvent {
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Untitled"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.location = ekEvent.location
        self.calendarName = ekEvent.calendar?.title ?? "Unknown"
    }
}
```

### ScheduleSuggestionEngine Design (Pure Domain)

```swift
// Domain/ScheduleSuggestionEngine.swift
import Foundation

struct ScheduleSuggestion: Identifiable, Sendable {
    let id = UUID()
    let routineName: String
    let routineID: String  // Routine.cloudID for lookup
    let reason: String     // "Soccer practice starts in 45 minutes"
    let suggestedStartTime: Date
    let urgency: SuggestionUrgency
}

enum SuggestionUrgency: Sendable {
    case upcoming   // 30-60 minutes away
    case soon       // 15-30 minutes away
    case now        // Under 15 minutes away
}

struct ScheduleSuggestionEngine {

    /// Match calendar events to routines and generate timing suggestions.
    /// Pure function: events + routines in, suggestions out.
    static func generateSuggestions(
        events: [CalendarEvent],
        routines: [RoutineSummary],
        currentTime: Date = .now
    ) -> [ScheduleSuggestion] {
        var suggestions: [ScheduleSuggestion] = []

        for event in events {
            let minutesUntil = Int(event.startDate.timeIntervalSince(currentTime) / 60)

            // Only suggest for events 10-90 minutes in the future
            guard minutesUntil > 10 && minutesUntil < 90 else { continue }

            // Match event to a routine by keyword matching
            for routine in routines {
                if matchesEvent(routine: routine, event: event) {
                    let prepTime = estimatedPrepTime(for: routine)
                    let suggestedStart = event.startDate.addingTimeInterval(-prepTime)

                    let urgency: SuggestionUrgency
                    if minutesUntil < 15 { urgency = .now }
                    else if minutesUntil < 30 { urgency = .soon }
                    else { urgency = .upcoming }

                    suggestions.append(ScheduleSuggestion(
                        routineName: routine.displayName,
                        routineID: routine.cloudID,
                        reason: "\(event.title) starts in \(minutesUntil) minutes",
                        suggestedStartTime: suggestedStart,
                        urgency: urgency
                    ))
                }
            }
        }

        return suggestions.sorted { $0.suggestedStartTime < $1.suggestedStartTime }
    }

    // MARK: - Private Matching Logic

    /// Simple keyword matching between routine tasks and event titles.
    private static func matchesEvent(routine: RoutineSummary, event: CalendarEvent) -> Bool {
        let eventWords = Set(event.title.lowercased().split(separator: " ").map(String.init))
        let routineWords = Set(routine.taskNames.joined(separator: " ")
            .lowercased().split(separator: " ").map(String.init))

        // Match if routine name or task names share keywords with event
        let keywords = ["practice", "game", "class", "lesson", "school",
                        "soccer", "basketball", "piano", "dance", "swim",
                        "homework", "study", "friend", "party"]

        let eventKeywords = eventWords.intersection(keywords)
        let routineKeywords = routineWords.intersection(keywords)

        return !eventKeywords.intersection(routineKeywords).isEmpty
    }

    private static func estimatedPrepTime(for routine: RoutineSummary) -> TimeInterval {
        // Estimate total routine time based on task count
        // Default: 5 minutes per task + 5 minute buffer
        Double(routine.taskCount * 5 + 5) * 60
    }
}

/// Lightweight summary of a Routine for domain engine consumption.
/// Avoids passing SwiftData @Model to pure domain code.
struct RoutineSummary: Sendable {
    let cloudID: String
    let displayName: String
    let taskNames: [String]
    let taskCount: Int
}
```

### Integration with Existing Code

| Existing Component | Change | Impact |
|-------------------|--------|--------|
| `AppDependencies` | Add `calendarService: CalendarService` property | MINOR |
| `PlayerHomeView` | Add schedule suggestions section above quest list | MODERATE UI addition |
| `RoutineRepository` | Add method to create `[RoutineSummary]` from fetched routines | MINOR convenience method |
| `ParentDashboardView` or settings | Add calendar permission toggle/request UI | MINOR |
| `NotificationManager` | Optionally schedule reminders based on calendar event timing | Future enhancement |

### Data Flow

```
App launch / PlayerHomeView.onAppear:
  -> CalendarService.checkCurrentPermission()
  -> if .authorized:
       CalendarService.fetchTodayEvents()
       let routineSummaries = routines.map { RoutineSummary(from: $0) }
       let suggestions = ScheduleSuggestionEngine.generateSuggestions(
           events: calendarService.todayEvents,
           routines: routineSummaries
       )
       -> ScheduleSuggestionsView renders suggestions
       -> Tapping a suggestion navigates to QuestView for that routine
  -> if .notDetermined:
       Show CalendarPermissionView (explains value, requests permission)
  -> if .denied:
       Show nothing (graceful absence, no nagging)
```

### Permission UX

**Critical: Calendar access is opt-in and clearly explained.** The player (or parent) must understand why TimeQuest wants calendar access. Use a pre-permission screen before the system dialog:

```
[Calendar icon]
"See What's Coming Up"

TimeQuest can check your calendar to suggest
the right quest at the right time.

"You have soccer at 4 PM -- want to start
your Activity Prep quest now?"

TimeQuest only reads your calendar.
It never changes or shares your events.

[Allow Calendar Access]  [Not Now]
```

**"Not Now" is always available.** Calendar intelligence is an enhancement, not a requirement. The app works perfectly without it.

### No Schema Changes

CalendarService is read-only. It reads EventKit data and produces suggestions. No calendar data is persisted in SwiftData. The `RoutineSummary` value type is computed on-the-fly from existing `Routine` models.

**Future consideration:** If we want to let the parent associate a routine with specific calendar event keywords (e.g., "Soccer" -> "Activity Prep"), that would add an optional `calendarKeywords: [String]?` field to Routine in a future schema version. For v3.0, the keyword matching is automatic and heuristic-based.

---

## Pillar 4: UI/Brand Refresh (Theme System)

### Concept

Replace the current ad-hoc colors (`.tint`, `Color(.systemGray6)`, `Color.orange`, `Color.teal`, `Color.purple`) with a cohesive design token system. Introduce consistent typography, spacing, and iconography. Make the app feel like a polished game, not a prototype.

### Architecture Decision: SwiftUI Environment-Based Theme

**Use a `Theme` struct injected via SwiftUI's `.environment()` modifier at the root level.** This is the same pattern used for `AppDependencies` and `RoleState` -- consistent with existing architecture.

Do NOT use:
- `@AppStorage` for theme values (too fragile, no type safety)
- Global singletons (breaks SwiftUI's declarative model)
- UIKit appearance proxies (SwiftUI-only app, don't mix paradigms)

### New Components

| Component | Layer | Type | File Path |
|-----------|-------|------|-----------|
| `Theme` | Design | Struct | `Design/Theme.swift` |
| `ThemeColors` | Design | Struct | `Design/ThemeColors.swift` |
| `ThemeTypography` | Design | Struct | `Design/ThemeTypography.swift` |
| `ThemeSpacing` | Design | Struct | `Design/ThemeSpacing.swift` |
| `ThemeIcons` | Design | Struct | `Design/ThemeIcons.swift` |
| `View+Theme` | Design | Extension | `Design/View+Theme.swift` |
| `ThemedButton` | Design | SwiftUI View | `Design/Components/ThemedButton.swift` |
| `ThemedCard` | Design | SwiftUI View | `Design/Components/ThemedCard.swift` |

### Theme System Design

```swift
// Design/Theme.swift
import SwiftUI

struct Theme: Sendable {
    let colors: ThemeColors
    let typography: ThemeTypography
    let spacing: ThemeSpacing
    let icons: ThemeIcons
    let animation: ThemeAnimation

    static let `default` = Theme(
        colors: .quest,
        typography: .default,
        spacing: .default,
        icons: .default,
        animation: .default
    )
}

// MARK: - Environment Integration

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.default
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func themed(_ theme: Theme = .default) -> some View {
        environment(\.theme, theme)
    }
}
```

```swift
// Design/ThemeColors.swift
import SwiftUI

struct ThemeColors: Sendable {
    // MARK: - Semantic Colors (what the color means, not what it looks like)

    let accent: Color                 // Primary brand color
    let accentSecondary: Color        // Secondary brand color

    // Rating colors (used in AccuracyMeter, reveal, XP)
    let ratingSpotOn: Color           // Achievement gold
    let ratingClose: Color            // Positive
    let ratingOff: Color              // Neutral
    let ratingWayOff: Color           // Discovery (never "bad")

    // Surface colors
    let cardBackground: Color         // Quest cards, insight cards
    let cardBackgroundElevated: Color // Modal cards, sheets
    let surfacePrimary: Color         // Main background
    let surfaceSecondary: Color       // Secondary sections

    // Text colors
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // Feedback colors
    let success: Color
    let warning: Color
    let info: Color

    // Difficulty level colors
    let difficultyLearning: Color
    let difficultyPracticing: Color
    let difficultyConfident: Color
    let difficultyMastering: Color

    // MARK: - Default Theme: "Quest"

    static let quest = ThemeColors(
        accent: Color("AccentPrimary"),      // Asset catalog for light/dark
        accentSecondary: Color("AccentSecondary"),

        ratingSpotOn: .orange,               // Keep existing -- gold/achievement
        ratingClose: .teal,                  // Keep existing -- positive
        ratingOff: Color(.systemGray3),      // Keep existing -- neutral
        ratingWayOff: .purple,               // Keep existing -- discovery

        cardBackground: Color(.systemGray6),
        cardBackgroundElevated: Color(.systemBackground),
        surfacePrimary: Color(.systemBackground),
        surfaceSecondary: Color(.secondarySystemBackground),

        textPrimary: .primary,
        textSecondary: .secondary,
        textTertiary: Color(.tertiaryLabel),

        success: .green,
        warning: .orange,
        info: .blue,

        difficultyLearning: .blue,
        difficultyPracticing: .teal,
        difficultyConfident: .orange,
        difficultyMastering: .purple
    )
}
```

```swift
// Design/ThemeTypography.swift
import SwiftUI

struct ThemeTypography: Sendable {
    let heroTitle: Font        // App name, major headings
    let sectionTitle: Font     // Section headers
    let cardTitle: Font        // Quest card titles
    let body: Font             // Standard text
    let caption: Font          // Secondary info
    let metric: Font           // Numbers, stats, XP values
    let metricLarge: Font      // Big accuracy numbers in reveal

    static let `default` = ThemeTypography(
        heroTitle: .system(.largeTitle, design: .rounded, weight: .bold),
        sectionTitle: .system(.title3, design: .rounded, weight: .semibold),
        cardTitle: .system(.headline, design: .rounded, weight: .semibold),
        body: .system(.body, design: .rounded),
        caption: .system(.caption, design: .rounded),
        metric: .system(.title2, design: .rounded, weight: .bold).monospacedDigit(),
        metricLarge: .system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit()
    )
}
```

```swift
// Design/ThemeSpacing.swift
import SwiftUI

struct ThemeSpacing: Sendable {
    let xs: CGFloat    // 4
    let sm: CGFloat    // 8
    let md: CGFloat    // 12
    let lg: CGFloat    // 16
    let xl: CGFloat    // 24
    let xxl: CGFloat   // 32

    let cardPadding: CGFloat       // Internal card padding
    let cardCornerRadius: CGFloat  // Card corner radius
    let screenPadding: CGFloat     // Horizontal screen margins

    static let `default` = ThemeSpacing(
        xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32,
        cardPadding: 16,
        cardCornerRadius: 12,
        screenPadding: 24
    )
}
```

### Integration Strategy: Incremental, Not Big-Bang

**Do NOT rewrite all views at once.** Instead:

1. **Phase A:** Create the Design/ folder with Theme, ThemeColors, ThemeTypography, ThemeSpacing, ThemeIcons. Inject `.themed()` at the root level in ContentView.
2. **Phase B:** Create ThemedCard and ThemedButton reusable components that read `@Environment(\.theme)`.
3. **Phase C:** Migrate views one at a time. Start with PlayerHomeView (highest visibility), then QuestView, then remaining views. Each migration is a small, testable PR.

This approach avoids a "big bang" refactor that touches every file simultaneously and creates merge conflicts with other pillars being built in parallel.

### View Migration Pattern

Before (current):
```swift
// Current: ad-hoc colors and spacing
HStack {
    VStack(alignment: .leading, spacing: 4) {
        Text(routine.displayName)
            .font(.headline)
            .foregroundStyle(.primary)
        Text("\(routine.orderedTasks.count) steps")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    Spacer()
    Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
}
.padding(16)
.background(Color(.systemGray6))
.clipShape(RoundedRectangle(cornerRadius: 12))
```

After (themed):
```swift
// After: semantic tokens from theme
@Environment(\.theme) private var theme

HStack {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
        Text(routine.displayName)
            .font(theme.typography.cardTitle)
            .foregroundStyle(theme.colors.textPrimary)
        Text("\(routine.orderedTasks.count) steps")
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
    }
    Spacer()
    Image(systemName: theme.icons.chevronRight)
        .font(theme.typography.caption)
        .foregroundStyle(theme.colors.textTertiary)
}
.padding(theme.spacing.cardPadding)
.background(theme.colors.cardBackground)
.clipShape(RoundedRectangle(cornerRadius: theme.spacing.cardCornerRadius))
```

### Integration with Existing Code

| Existing Component | Change | Impact |
|-------------------|--------|--------|
| `ContentView` (in TimeQuestApp) | Add `.themed()` modifier | ONE LINE |
| `AccuracyMeter` | Replace hardcoded `ratingColor` switch with `theme.colors.ratingXxx` | MINOR -- same logic, different color source |
| `PlayerHomeView` | Replace hardcoded fonts, colors, spacing with theme tokens | MODERATE -- many small replacements |
| `QuestView` chain (Estimation, Active, Reveal, Summary) | Same treatment as PlayerHomeView | MODERATE |
| `ParentDashboardView` chain | Same treatment | MODERATE |
| `XPBarView`, `LevelBadgeView`, `StreakBadgeView` | Replace hardcoded styles | MINOR each |
| All other views | Incremental migration | MINOR each |

### No Schema Changes

The theme system is entirely a UI-layer concern. Zero model changes, zero migration.

### Asset Catalog Changes

Add to `Assets.xcassets`:
- `AccentPrimary` (Color Set, light + dark variants)
- `AccentSecondary` (Color Set, light + dark variants)
- App icon redesign (if part of brand refresh)
- Any custom icons or illustrations

---

## SchemaV4 Migration Plan

### All Schema Changes (Combined)

```swift
// Models/Schemas/TimeQuestSchemaV4.swift

// Changes from SchemaV3:

// GameSession -- 1 new property
var difficultyLevelRawValue: String = "learning"

// TaskEstimation -- 1 new property
var accuracyBandMultiplier: Double = 1.0

// Routine -- 2 new optional properties
var spotifyPlaylistURI: String?
var spotifyPlaylistName: String?
```

All additions are either optional or have defaults. This is a **lightweight migration** -- no custom migration logic needed.

```swift
// Models/Migration/TimeQuestMigrationPlan.swift -- MODIFIED
enum TimeQuestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TimeQuestSchemaV1.self, TimeQuestSchemaV2.self,
         TimeQuestSchemaV3.self, TimeQuestSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3, v3ToV4]
    }

    static let v3ToV4 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV3.self,
        toVersion: TimeQuestSchemaV4.self
    )
    // ... existing stages unchanged
}
```

### CloudKit Compatibility

All new fields have defaults or are optional, satisfying CloudKit's requirements. Existing CloudKit-synced records will gain default values for the new fields on next sync.

---

## Updated AppDependencies

```swift
// App/AppDependencies.swift -- v3.0
@MainActor
@Observable
final class AppDependencies {
    // Existing (unchanged)
    let routineRepository: RoutineRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    let playerProfileRepository: PlayerProfileRepositoryProtocol
    let soundManager: SoundManager
    let notificationManager: NotificationManager
    let syncMonitor: CloudKitSyncMonitor

    // NEW for v3.0
    let spotifyService: SpotifyService
    let calendarService: CalendarService

    init(modelContext: ModelContext) {
        // Existing
        self.routineRepository = SwiftDataRoutineRepository(modelContext: modelContext)
        self.sessionRepository = SwiftDataSessionRepository(modelContext: modelContext)
        self.playerProfileRepository = SwiftDataPlayerProfileRepository(modelContext: modelContext)
        self.soundManager = SoundManager()
        self.notificationManager = NotificationManager()
        self.syncMonitor = CloudKitSyncMonitor()
        syncMonitor.startMonitoring()

        // NEW
        self.spotifyService = SpotifyService()
        self.calendarService = CalendarService()
        calendarService.checkCurrentPermission()
    }
}
```

**Note:** `AdaptiveDifficultyEngine` is NOT added to AppDependencies. It follows the same pattern as `InsightEngine`, `WeeklyReflectionEngine`, and `TimeEstimationScorer` -- a stateless pure struct with static methods, called directly from ViewModels. Only stateful services (SpotifyService, CalendarService) go in AppDependencies.

---

## Updated File Structure

```
TimeQuest/
  App/
    TimeQuestApp.swift              # MODIFIED: onOpenURL for Spotify callback
    AppDependencies.swift           # MODIFIED: add SpotifyService, CalendarService
    RoleRouter.swift                # unchanged
    ContentView (inline)            # MODIFIED: add .themed() modifier

  Models/
    Routine.swift                   # MODIFIED: spotifyPlaylistURI/Name (SchemaV4)
    RoutineTask.swift               # unchanged
    GameSession.swift               # MODIFIED: difficultyLevelRawValue (SchemaV4)
    TaskEstimation.swift            # MODIFIED: accuracyBandMultiplier (SchemaV4)
    PlayerProfile.swift             # unchanged
    EstimationSnapshot.swift        # unchanged
    WeeklyReflection.swift          # unchanged
    Schemas/
      TimeQuestSchemaV1.swift       # unchanged
      TimeQuestSchemaV2.swift       # unchanged
      TimeQuestSchemaV3.swift       # unchanged
      TimeQuestSchemaV4.swift       # NEW: v3.0 schema additions
    Migration/
      TimeQuestMigrationPlan.swift  # MODIFIED: add v3ToV4 stage

  Repositories/
    RoutineRepository.swift         # MINOR: add fetchRoutineSummaries() method
    SessionRepository.swift         # unchanged
    PlayerProfileRepository.swift   # unchanged

  Domain/
    # Existing (unchanged)
    CalibrationTracker.swift
    FeedbackGenerator.swift
    LevelCalculator.swift
    PersonalBestTracker.swift
    StreakTracker.swift
    TimeEstimationScorer.swift      # MODIFIED: accept accuracyBandMultiplier param
    XPEngine.swift                  # unchanged (ViewModel applies xpMultiplier)
    XPConfiguration.swift           # unchanged
    InsightEngine.swift             # unchanged
    WeeklyReflectionEngine.swift    # unchanged
    RoutineTemplateProvider.swift   # unchanged

    # NEW for v3.0
    AdaptiveDifficultyEngine.swift  # Pure domain: difficulty computation
    CalendarEvent.swift             # Value type bridge for EventKit events
    ScheduleSuggestionEngine.swift  # Pure domain: calendar -> routine suggestions
    SpotifyConfiguration.swift      # Client ID, redirect URI, scopes

  Features/
    Parent/
      ViewModels/
        RoutineEditorViewModel.swift    # MINOR: add Spotify playlist selection
        SpotifyPlaylistViewModel.swift  # NEW: playlist browsing for parent
      Views/
        (existing views: minor theme migration)
        SpotifyConnectView.swift        # NEW: Spotify OAuth flow UI
        SpotifyPlaylistPickerView.swift # NEW: playlist selection UI

    Player/
      ViewModels/
        GameSessionViewModel.swift      # MODIFIED: add difficulty + Spotify playback
        ProgressionViewModel.swift      # unchanged
        MyPatternsViewModel.swift       # unchanged
        WeeklyReflectionViewModel.swift # unchanged
        PlayerRoutineCreationViewModel.swift # unchanged
      Views/
        PlayerHomeView.swift            # MODIFIED: schedule suggestions + theme
        QuestView.swift                 # MODIFIED: music banner + theme
        (all views: incremental theme migration)
        ScheduleSuggestionsView.swift   # NEW: calendar suggestion cards
        QuestMusicBannerView.swift      # NEW: now-playing indicator

    Shared/
      Components/
        (existing: theme migration)
        CalendarPermissionView.swift    # NEW: pre-permission explanation

  Design/                              # NEW folder for v3.0
    Theme.swift                        # Theme struct + environment key
    ThemeColors.swift                   # Semantic color tokens
    ThemeTypography.swift              # Typography scale
    ThemeSpacing.swift                 # Spacing scale
    ThemeIcons.swift                    # Icon name constants
    ThemeAnimation.swift               # Animation duration/curve constants
    View+Theme.swift                   # .themed() modifier
    Components/
      ThemedButton.swift               # Reusable themed button
      ThemedCard.swift                 # Reusable themed card

  Services/
    SoundManager.swift              # unchanged (no audio session conflict)
    NotificationManager.swift       # unchanged
    CloudKitSyncMonitor.swift       # unchanged
    SpotifyService.swift            # NEW: Spotify OAuth + playback control
    SpotifyAuthManager.swift        # NEW: token management (Keychain)
    CalendarService.swift           # NEW: EventKit wrapper

  Game/
    AccuracyRevealScene.swift       # MINOR: theme colors
    CelebrationScene.swift          # MINOR: theme colors

  Tests/
    AdaptiveDifficultyEngineTests.swift  # NEW
    ScheduleSuggestionEngineTests.swift  # NEW
```

**New file count:** ~22 new files.
**Modified file count:** ~12 files.
**Total codebase grows from 66 to ~88 Swift files.**

---

## Build Order (Dependency-Driven)

### Dependencies Between Pillars

```
Pillar 1: Adaptive Difficulty
  depends on: EstimationSnapshot (exists), InsightEngine thresholds (reference only)
  blocks: nothing

Pillar 2: Spotify Integration
  depends on: Spotify iOS SDK (external dependency)
  blocks: nothing
  coordination: SoundManager (minor, no blocking dependency)

Pillar 3: Calendar Intelligence
  depends on: EventKit (system framework), RoutineRepository (exists)
  blocks: nothing

Pillar 4: UI/Brand Refresh
  depends on: nothing
  blocks: nothing (but should go LAST so other pillars' new views use the theme)

SchemaV4 migration
  depends on: knowing all schema additions (from Pillars 1 + 2)
  blocks: Pillars 1 and 2 (they need the new fields)
```

### Recommended Build Phases

**Phase 7: Schema Evolution + Adaptive Difficulty**
1. Create TimeQuestSchemaV4 with all new fields (from all pillars)
2. Update TimeQuestMigrationPlan with v3ToV4 stage
3. Build AdaptiveDifficultyEngine (pure domain, test-first)
4. Modify TimeEstimationScorer to accept accuracyBandMultiplier
5. Modify GameSessionViewModel to compute and apply difficulty per task
6. Update EstimationInputView to conditionally show/hide hints
7. Update AccuracyRevealView to show difficulty-adjusted feedback
8. Test: verify difficulty adapts based on player history

**Rationale:** Schema changes must happen first because both Adaptive Difficulty and Spotify need new fields. Adaptive Difficulty is the most "pure" pillar -- no external dependencies, no permissions, just domain logic. It follows the exact same pattern as InsightEngine (pure engine consuming EstimationSnapshot). Low risk, high testability.

**Phase 8: Calendar Intelligence**
1. Build CalendarService (EventKit wrapper)
2. Build CalendarEvent value type + bridge
3. Build ScheduleSuggestionEngine (pure domain, test-first)
4. Build CalendarPermissionView
5. Build ScheduleSuggestionsView
6. Integrate into PlayerHomeView
7. Test: verify calendar events produce correct suggestions, permission flow works

**Rationale:** Calendar Intelligence is a system-framework integration (EventKit) with well-established patterns. No external third-party dependency. The permission flow is the main UX challenge but is a well-solved problem. Lower risk than Spotify.

**Phase 9: Spotify Integration**
1. Add SpotifyiOS SDK dependency (Swift Package Manager)
2. Build SpotifyConfiguration
3. Build SpotifyAuthManager (Keychain-backed token storage)
4. Build SpotifyService (OAuth + playback control)
5. Build SpotifyConnectView (parent dashboard)
6. Build SpotifyPlaylistPickerView (parent dashboard)
7. Build QuestMusicBannerView (player quest view)
8. Integrate into GameSessionViewModel (play on quest start, pause on finish)
9. Handle onOpenURL in TimeQuestApp for OAuth callback
10. Test: verify OAuth flow, playlist selection, playback during quest

**Rationale:** Spotify is the highest-risk pillar. It introduces the project's first external third-party dependency, requires OAuth configuration in the Spotify Developer Dashboard, requires the Spotify app to be installed, and has the most complex error states (not installed, not logged in, token expired, playback failed). Build it after the two simpler pillars to avoid blocking progress on external dependency issues.

**Phase 10: UI/Brand Refresh**
1. Create Design/ folder with Theme system
2. Build ThemeColors, ThemeTypography, ThemeSpacing, ThemeIcons, ThemeAnimation
3. Build ThemedCard and ThemedButton reusable components
4. Add `.themed()` to ContentView root
5. Migrate PlayerHomeView (highest visibility)
6. Migrate QuestView chain (Estimation, Active, Reveal, Summary)
7. Migrate ParentDashboardView chain
8. Migrate remaining views
9. Update AccuracyRevealScene and CelebrationScene colors
10. Test: visual regression check across all screens

**Rationale:** The theme system should be built LAST because (a) it has zero functional impact -- it is purely visual, (b) building it last means all new views from Phases 7-9 exist and can be themed in a single pass, and (c) doing theme migration while other pillars are being built would create constant merge conflicts. The incremental migration strategy (one view at a time) makes this safe to do in a focused sweep at the end.

---

## Anti-Patterns to Avoid (v3.0-Specific)

### Anti-Pattern: AdaptiveDifficultyEngine Importing SwiftData

**What:** Making the difficulty engine accept `[TaskEstimation]` or `[GameSession]` directly.

**Why bad:** Breaks the pure-domain-engine pattern established by InsightEngine and WeeklyReflectionEngine. Creates hidden MainActor requirements. Makes the engine untestable without ModelContainer.

**Instead:** Accept `[EstimationSnapshot]` -- the same bridge type every other domain engine uses.

### Anti-Pattern: Storing Spotify Tokens in UserDefaults

**What:** Saving the OAuth access token and refresh token in UserDefaults.

**Why bad:** UserDefaults is not encrypted. OAuth tokens are credentials. If the device is compromised or backed up to an unencrypted iTunes backup, tokens are exposed.

**Instead:** Use the iOS Keychain via `Security.framework`. The Keychain is encrypted at rest and protected by the device passcode.

### Anti-Pattern: Requesting Calendar Permission on First Launch

**What:** Showing the EventKit permission dialog immediately when the app opens for the first time.

**Why bad:** Users deny permissions they do not understand. The system dialog gives no context about why the app wants calendar access. Once denied, the user must go to Settings to re-enable.

**Instead:** Show a custom pre-permission screen that explains the value ("See what's coming up so you can start the right quest at the right time"). Only trigger the system dialog after the user taps "Allow" on the custom screen. If the user taps "Not Now", remember their choice and do not ask again for 7 days.

### Anti-Pattern: Global Theme Singleton

**What:** Creating a `ThemeManager.shared` singleton that views read from.

**Why bad:** Singletons break SwiftUI's declarative environment-based architecture. They make previews difficult (can't override the singleton per preview). They create hidden dependencies that are not visible in the view's init.

**Instead:** Use `@Environment(\.theme)` -- the same pattern as `@Environment(\.colorScheme)`, `@Environment(\.dynamicTypeSize)`, and every other SwiftUI environment value.

### Anti-Pattern: Big-Bang Theme Migration

**What:** Rewriting every view to use the new theme system in a single PR.

**Why bad:** Touches every file in the codebase. Creates massive merge conflicts if any other work is happening. Makes it impossible to review the PR meaningfully. One bug in the theme system breaks every view.

**Instead:** Incremental migration. Create the theme system first. Then migrate one view at a time. Each migration is a small, reviewable, revertible change.

### Anti-Pattern: Spotify Playback Without Fallback

**What:** Assuming Spotify is always available and crashing or showing errors when it is not.

**Why bad:** Spotify requires the app to be installed. Not every user has Spotify. The auth token can expire. The Spotify app can be backgrounded and killed by iOS.

**Instead:** Every Spotify integration point must have a graceful fallback. Quest works without music. Parent dashboard shows "Connect Spotify" only when the app is installed. Playback failures are silently logged, not shown to the 13-year-old player.

---

## Scalability Considerations

| Concern | At Current Scale (66 files) | After v3.0 (~88 files) | At 150+ files |
|---------|----------------------------|------------------------|---------------|
| AdaptiveDifficultyEngine | N/A | Processes same EstimationSnapshot data as InsightEngine. Trivial. | No concern -- bounded by per-task window (last 10 sessions). |
| SpotifyService | N/A | Singleton service, one active connection. | No concern -- Spotify handles all streaming complexity. |
| CalendarService | N/A | Reads today's events (typically 5-20). Trivial. | No concern -- bounded to single-day event count. |
| ScheduleSuggestionEngine | N/A | O(events x routines) matching. At 20 events x 10 routines = 200 comparisons. | No concern at any realistic scale. |
| Theme system | Ad-hoc colors (26 views) | Environment-based tokens (38 views). | Environment reads are O(1). Scales to any number of views. |
| SchemaV4 migration | V1->V2->V3 chain | V1->V2->V3->V4 chain. Lightweight. | At V8+ consider collapsing old schemas (remove V1/V2 support). |
| generate-xcodeproj.js | Registers 66 files | Registers ~88 files | File registration is O(n). No concern. |
| CloudKit sync | ~6K records | Same records + 4 new fields per record | CloudKit handles field additions gracefully. No concern. |

---

## Cross-Cutting Concerns

### Error Handling Strategy

Each new service has distinct failure modes:

| Service | Failure | User Impact | Handling |
|---------|---------|-------------|----------|
| SpotifyService | Not installed | No music in quests | Hide Spotify UI entirely |
| SpotifyService | Auth expired | Music stops mid-quest | Silent re-auth attempt, graceful silence |
| SpotifyService | Playback failed | No music | Log error, continue quest without music |
| CalendarService | Permission denied | No suggestions | Hide suggestion UI, never nag |
| CalendarService | No events today | No suggestions | Show nothing (not "no events found") |
| AdaptiveDifficultyEngine | Insufficient data | Default to "learning" | Built into engine (< 5 sessions = learning) |

**Principle: No error from a v3.0 feature should ever block the core quest gameplay.** All new features are enhancements layered on top of the existing game loop. If Spotify fails, the quest continues. If the calendar is unavailable, quests still work. If adaptive difficulty has insufficient data, it defaults to the generous "learning" parameters.

### Concurrency Model

- **SpotifyService:** `@MainActor` (UI state updates, SPTAppRemote callbacks)
- **CalendarService:** `@MainActor` (EKEventStore operations, UI state updates)
- **AdaptiveDifficultyEngine:** Sendable struct, static methods, no actor isolation needed (same as InsightEngine)
- **ScheduleSuggestionEngine:** Sendable struct, static methods, no actor isolation needed
- **Theme:** Sendable struct, injected via environment, read-only after creation

### Privacy Considerations

| Feature | Data Accessed | Stored? | Shared? |
|---------|--------------|---------|---------|
| Calendar | User's calendar events | NO -- read on-demand, never persisted | NO |
| Spotify | Playlist names, playback state | Playlist URI/name stored on Routine (CloudKit synced) | Within user's own iCloud only |
| Adaptive Difficulty | Estimation history (already stored) | Difficulty level on GameSession (CloudKit synced) | Within user's own iCloud only |

**Calendar data never leaves the device.** Event titles and times are read from EventKit, used to generate suggestions in memory, and discarded. No calendar data is written to SwiftData or synced to CloudKit.

**Spotify data is minimal.** Only the playlist URI and display name are stored (on the Routine model). No track history, listening habits, or Spotify profile data is persisted.

---

## Sources

- **Existing codebase analysis**: All 66 Swift files read and analyzed directly from `/Users/davezabihaylo/Desktop/Claude Cowork/GSD/TimeQuest/`
- **Spotify iOS SDK**: Training data knowledge of SpotifyiOS SDK (SPTSessionManager, SPTAppRemote, SPTPlayerAPI). MEDIUM confidence -- SDK has been stable since 2019 but may have received updates post-May 2025. Verify current SDK version and API surface before implementation.
- **EventKit**: Training data knowledge of EKEventStore, EKEvent, authorization model. HIGH confidence -- EventKit API has been stable since iOS 6. iOS 17 added `requestFullAccessToEvents()` (vs. legacy `requestAccess(to:)`) which is reflected above.
- **SwiftUI Environment pattern**: Training data knowledge of `EnvironmentKey`, `EnvironmentValues` extension pattern. HIGH confidence -- this is core SwiftUI, unchanged since iOS 13.
- **Adaptive difficulty algorithms**: Training data knowledge of game design patterns for difficulty adaptation (dynamic difficulty adjustment / DDA). HIGH confidence -- the implementation is custom domain logic, not dependent on any framework.
- **SwiftData migration**: Training data knowledge of lightweight migration for additive schema changes. MEDIUM confidence -- verified against existing TimeQuest V1->V2->V3 migration chain which uses the same pattern.
- **Architecture patterns**: Direct observation of existing codebase patterns (pure domain engines, EstimationSnapshot bridge, repository protocols, composition root, XPConfiguration). HIGH confidence -- these are the actual shipped patterns.

**Confidence note:** Web search and Context7 were unavailable during this session. The Spotify iOS SDK claims should be verified against current documentation at https://developer.spotify.com/documentation/ios before implementation. The EventKit API surface is mature and unlikely to have changed materially. The adaptive difficulty engine and theme system are custom implementations with no external dependency risk.
