# Stack Research: v3.0 Additions

**Project:** TimeQuest v3.0 -- Adaptive & Connected
**Researched:** 2026-02-14
**Confidence:** MEDIUM (WebSearch/WebFetch unavailable; recommendations based on training data through mid-2025 plus thorough codebase analysis; Spotify SDK version and EventKit iOS 18 changes should be validated against current docs)

**Scope:** This document covers ONLY additions and changes needed for v3.0. The existing stack (SwiftUI + SwiftData + SpriteKit + Swift Charts + CloudKit + AVFoundation, iOS 17.0+, Swift 6.0, Xcode 16.2) is validated and unchanged.

---

## Executive Assessment

v3.0 introduces TimeQuest's first external API dependency (Spotify) and first system framework that requires privacy permissions beyond what the app already has (EventKit). The adaptive difficulty engine requires zero new dependencies -- it extends the existing pure domain engine pattern. The UI refresh is entirely SwiftUI built-in capabilities.

**New framework additions: 2**
1. **EventKit.framework** -- calendar read access for schedule intelligence
2. **SpotifyiOS.framework** (SPM) -- Spotify iOS SDK for authentication + playback handoff

**New external dependency: 1**
- Spotify iOS SDK via Swift Package Manager -- the only third-party dependency in the entire project

**New pure domain engines: 2**
- `AdaptiveDifficultyEngine` -- dynamic difficulty calibration (pure Swift, no dependencies)
- `CalendarIntelligenceEngine` -- schedule-aware routine adaptation (consumes EventKit data, but engine itself is pure)

---

## New Framework Additions

### 1. EventKit.framework (Apple First-Party)

| Property | Value |
|----------|-------|
| **Framework** | EventKit.framework (ships with iOS SDK) |
| **Version** | Available since iOS 4.0; stable, no breaking changes in iOS 17-18 |
| **Purpose** | Read-only calendar access to detect school days, holidays, activity schedules |
| **Integration point** | New `CalendarService` in Services layer, consumed by `CalendarIntelligenceEngine` |
| **Why** | First-party Apple framework. No alternative exists for calendar data. The app needs to know "is today a school day?" and "does she have roller derby at 5pm?" to surface the right routines at the right times. |

**What it provides for TimeQuest:**
- Read calendar events to detect: school days vs. weekends vs. holidays vs. summer break
- Detect activity-specific events (roller derby, art class) by title matching
- Determine time-of-day context (morning routine window vs. after-school window)
- No write access needed -- TimeQuest only reads, never creates calendar events

**Privacy requirements:**
```swift
// Info.plist
NSCalendarsUsageDescription = "TimeQuest reads your calendar to know which routines fit today -- school mornings, activity days, or days off. We never modify your calendar."
```

**Permission flow:**
```swift
import EventKit

let eventStore = EKEventStore()
// iOS 17+ uses the new requestFullAccessToEvents API
try await eventStore.requestFullAccessToEvents()
```

**Key API surface needed:**
```swift
// Fetch events for a date range
let predicate = eventStore.predicateForEvents(
    withStart: startOfDay,
    end: endOfDay,
    calendars: nil  // all calendars
)
let events = eventStore.events(matching: predicate)

// Each EKEvent gives us:
// - event.title (match against known patterns: "School", "Roller Derby", etc.)
// - event.startDate / event.endDate
// - event.isAllDay (holidays, breaks)
// - event.calendar.title (e.g., "School Calendar", "Activities")
```

**Confidence:** HIGH for the API surface -- EventKit is one of Apple's oldest and most stable frameworks. The `requestFullAccessToEvents()` API was introduced in iOS 17 (replacing the older `requestAccess(to:)`). Since TimeQuest targets iOS 17.0+, use the new API directly.

**Confidence:** LOW for iOS 18 changes -- Apple may have introduced further EventKit privacy changes in iOS 18. Verify against current Apple documentation before implementation.

**Integration with existing architecture:**

```
EventKit (system)
  |
  v
CalendarService (Services layer -- new)
  - Wraps EKEventStore
  - Handles permission request/denial gracefully
  - Returns value types, not EKEvent objects
  |
  v
CalendarIntelligenceEngine (Domain layer -- new, pure Swift)
  - Receives [CalendarEvent] value types (no EventKit dependency)
  - Determines: isSchoolDay, isHoliday, isSummerBreak, activeActivities
  - Returns ScheduleContext value type
  |
  v
RoutineRepository / PlayerHomeView (existing)
  - Uses ScheduleContext to filter which routines to show
  - "It's a holiday -- skip school morning routine"
  - "Roller derby day -- show activity prep routine"
```

---

### 2. Spotify iOS SDK (Third-Party, via SPM)

| Property | Value |
|----------|-------|
| **Package** | SpotifyiOS (Swift Package Manager) |
| **Repository** | `https://github.com/spotify/ios-sdk` |
| **Version** | Latest stable (verify -- was ~2.x as of mid-2025) |
| **Purpose** | OAuth authentication + app-remote playback control |
| **Why** | The iOS SDK handles the OAuth flow natively (no web view) and provides app-remote control of the Spotify app. The Web API alone cannot control playback on the user's device without a premium account and would require a backend server for the auth token exchange. The iOS SDK handles both auth and playback handoff directly. |

**Why iOS SDK over Web API only:**

| Capability | Web API | iOS SDK | Winner for TimeQuest |
|------------|---------|---------|---------------------|
| Authentication | OAuth 2.0 (needs redirect URI, often a backend) | Native SSO with Spotify app | iOS SDK -- no backend needed |
| Search tracks/playlists | YES | NO (use Web API) | Web API |
| Create playlists | YES | NO (use Web API) | Web API |
| Control playback on device | YES (Premium only, complex) | YES (app-remote, works with free tier for 30s previews) | iOS SDK |
| Queue tracks | YES (Premium only) | YES (app-remote) | iOS SDK |
| No backend server needed | NO (token refresh needs server) | YES (SDK handles tokens) | iOS SDK |

**Recommendation: Use BOTH.**
- **iOS SDK** for authentication (SSO) and playback control (app-remote)
- **Web API** for search, playlist creation, and track metadata (called from device using access token from iOS SDK auth)

**SPM integration:**

```swift
// Package.swift dependency (added via Xcode > File > Add Package Dependencies)
// URL: https://github.com/spotify/ios-sdk
// Version: Up to next major from latest stable
```

**The generate-xcodeproj.js build system will need updating** to include the SPM dependency. This is the first SPM package in the project -- the pbxproj generator needs a new section for XCRemoteSwiftPackageReference and XCSwiftPackageProductDependency.

**Required Spotify Developer setup:**
1. Register app at developer.spotify.com/dashboard
2. Get Client ID (no Client Secret needed for iOS SDK PKCE flow)
3. Set redirect URI scheme (e.g., `timequest://spotify-callback`)
4. Add URL scheme to Info.plist

**Info.plist additions:**
```xml
<!-- URL scheme for Spotify callback -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>timequest</string>
        </array>
    </dict>
</array>

<!-- Allow opening Spotify app -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>spotify</string>
</array>
```

**Key API surface needed:**

```swift
import SpotifyiOS

// 1. Authentication
let configuration = SPTConfiguration(
    clientID: "YOUR_CLIENT_ID",
    redirectURL: URL(string: "timequest://spotify-callback")!
)
let sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
// Scopes needed:
// - user-read-playback-state (check what's playing)
// - user-modify-playback-state (play/pause/queue)
// - playlist-modify-public or playlist-modify-private (create routine playlists)
// - user-library-read (access saved tracks)

// 2. App Remote (playback control)
let appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
appRemote.connect()
// Then: appRemote.playerAPI?.play(uri, callback:)
//       appRemote.playerAPI?.enqueueTrackUri(uri, callback:)

// 3. Web API calls (search, playlist creation) using the access token
// These are plain URLSession calls to api.spotify.com
```

**Confidence:** MEDIUM -- The Spotify iOS SDK repository exists and was actively maintained as of mid-2025. However:
- Exact current version needs verification
- SPM support was added relatively recently; verify it is the recommended distribution method
- The app-remote API may have changed
- Spotify may have updated their OAuth flow (they were moving toward PKCE)
- Free tier vs. Premium playback limitations need current verification

**Critical uncertainty: Does the iOS SDK support Swift 6 strict concurrency?** The SDK is Objective-C based with Swift wrappers. It may produce Sendable warnings under strict concurrency. Plan for `@preconcurrency import SpotifyiOS` if needed (same pattern used for SwiftData in the existing codebase).

---

## New Pure Domain Engines

These follow the established pattern: pure structs with static methods, zero framework dependencies, fully testable.

### AdaptiveDifficultyEngine

**Purpose:** Dynamically adjust task challenge level based on the player's accuracy trends, so the game stays in the "flow zone" -- not too easy, not too frustrating.

**No new dependencies.** This is pure Swift math consuming the same `EstimationSnapshot` bridge type that InsightEngine and WeeklyReflectionEngine already use.

**Algorithm approach -- Exponential Moving Average (EMA):**

```swift
// Domain/AdaptiveDifficultyEngine.swift
struct DifficultyLevel: Sendable {
    let label: String           // "Warming Up", "Getting It", "Time Master", etc.
    let hintVisibility: HintVisibility
    let toleranceBand: Double   // Widens/narrows accuracy thresholds
    let taskComplexity: TaskComplexity
}

enum HintVisibility: Sendable {
    case full        // Show reference times and contextual hints
    case partial     // Show contextual hints only
    case minimal     // Show hints only on request
    case hidden      // No hints -- pure estimation
}

enum TaskComplexity: Sendable {
    case single      // One task at a time (current behavior)
    case sequential  // Multiple tasks, estimate each
    case batch       // Estimate total time for a group of tasks
}

struct AdaptiveDifficultyEngine {
    /// EMA smoothing factor (0-1). Higher = more responsive to recent performance.
    /// 0.3 is a good default: responsive enough to feel adaptive,
    /// smooth enough to avoid whiplash from one bad session.
    static let alpha: Double = 0.3

    /// Compute EMA of accuracy from recent snapshots.
    static func computeEMA(snapshots: [EstimationSnapshot]) -> Double

    /// Determine difficulty level from EMA accuracy.
    static func difficultyLevel(emaAccuracy: Double, sessionCount: Int) -> DifficultyLevel

    /// Should we increase complexity? (e.g., move from single to batch estimation)
    static func shouldAdvanceComplexity(
        emaAccuracy: Double,
        sessionsAtCurrentLevel: Int
    ) -> Bool
}
```

**Why EMA over simple average:**
- Simple average is slow to respond (a great recent session is diluted by old data)
- EMA weights recent sessions more heavily, so the difficulty responds to the player's current skill level, not her historical average
- The smoothing factor `alpha` prevents whiplash from one outlier session
- This is the same approach used in game design for matchmaking ELO variants

**How it integrates with existing CalibrationTracker:**
- CalibrationTracker handles the first 3 sessions (learning the game)
- AdaptiveDifficultyEngine takes over after calibration completes
- They are complementary, not competing: calibration is "gather baseline data", adaptive is "adjust based on data"

**Integration point:** `GameSessionViewModel.startQuest()` already checks calibration status. After calibration, it will also check adaptive difficulty to determine hint visibility and tolerance bands.

**Confidence:** HIGH -- This is pure math on existing data types. No framework uncertainty.

### CalendarIntelligenceEngine

**Purpose:** Determine schedule context (school day, holiday, activity day, summer break) from calendar event data, so routines can auto-surface based on what the player's actual day looks like.

**No EventKit dependency in the engine.** It consumes value types:

```swift
// Domain/CalendarIntelligenceEngine.swift
struct CalendarEvent: Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String
}

struct ScheduleContext: Sendable {
    let isSchoolDay: Bool
    let isHoliday: Bool
    let isSummerBreak: Bool
    let activeActivities: [String]  // e.g., ["Roller Derby"]
    let morningWindowEnd: Date?     // When she needs to leave
    let date: Date
}

struct CalendarIntelligenceEngine {
    /// Configurable patterns for school, holidays, activities.
    /// Parent sets these up once; stored in UserDefaults or a simple plist.
    struct SchedulePatterns: Codable, Sendable {
        var schoolKeywords: [String] = ["school", "class"]
        var holidayKeywords: [String] = ["no school", "holiday", "break", "day off"]
        var activityKeywords: [String: String] = [
            "roller derby": "Roller Derby",
            "art class": "Art Class"
        ]
        var schoolCalendarName: String? = nil  // If parent has a specific school calendar
    }

    /// Analyze events for a given day and return schedule context.
    static func analyzeDay(
        events: [CalendarEvent],
        date: Date,
        patterns: SchedulePatterns
    ) -> ScheduleContext
}
```

**Confidence:** HIGH -- Pure Swift logic. The complexity is in the keyword matching heuristics, not framework integration.

---

## Spotify Integration Architecture

This is the most complex new addition. Here is the full integration design:

### Layer Breakdown

```
SpotifyiOS SDK (third-party)
  |
  v
SpotifyAuthService (Services layer -- new)
  - Manages SPTSessionManager + SPTAppRemote
  - Handles OAuth flow, token storage (Keychain)
  - Exposes: isConnected, accessToken, connect(), disconnect()
  |
  v
SpotifyMusicService (Services layer -- new)
  - Uses accessToken for Web API calls (URLSession)
  - Search tracks, get user library, create/update playlists
  - Uses SPTAppRemote for playback control
  - Exposes: searchTracks(), createPlaylist(), play(), pause(), queue()
  |
  v
RoutinePlaylistEngine (Domain layer -- new, pure Swift)
  - Given: routine tasks with durations, available tracks with durations
  - Computes: optimal playlist that matches total routine duration
  - Pure algorithm: bin-packing / greedy duration matching
  - No Spotify dependency -- works on [TrackInfo] value types
  |
  v
SpotifyViewModel (ViewModel layer -- new)
  - Bridges SpotifyMusicService to SwiftUI views
  - Manages connect/disconnect state
  - Triggers playlist creation when quest starts
```

### Token Storage

Use **Keychain** for Spotify access/refresh tokens. Do NOT use UserDefaults (tokens are sensitive).

```swift
// Services/KeychainHelper.swift -- small utility, no third-party needed
// Security.framework is already available (ships with iOS SDK)
```

**No third-party Keychain wrapper needed.** The Keychain API for simple string storage is ~30 lines of Swift. Adding a dependency like KeychainAccess for two key-value pairs is unnecessary.

### Playlist Duration Matching Algorithm

The core value proposition: "a playlist that's exactly as long as your morning routine." This is a variant of the subset-sum / bin-packing problem, but with a user-friendly twist -- we do not need exact matches, just close enough.

```swift
struct RoutinePlaylistEngine {
    /// Given target duration and available tracks, select tracks
    /// that sum to approximately the target duration.
    /// Greedy approach: sort tracks, fill until within tolerance.
    static func buildPlaylist(
        targetDurationSeconds: Int,
        availableTracks: [TrackInfo],
        toleranceSeconds: Int = 30
    ) -> [TrackInfo]
}
```

**Confidence:** HIGH for the algorithm. MEDIUM for Spotify API integration details.

---

## UI/Brand Refresh Technologies

### What is Already Available (No New Dependencies)

The UI refresh uses exclusively SwiftUI built-in capabilities. Every pattern listed below works on iOS 17.0+:

| Technique | SwiftUI API | iOS Version | Purpose |
|-----------|-------------|-------------|---------|
| Custom color scheme | `Color(hex:)` extension + Asset Catalog named colors | iOS 13+ | Brand palette refresh |
| Gradient backgrounds | `LinearGradient`, `MeshGradient` | 17+ (MeshGradient 18+) | Modern depth/glow effects |
| SF Symbols 5 | `Image(systemName:)` with variable rendering | 17+ | Updated iconography |
| Custom fonts | `.font(.custom("FontName", size:))` | 13+ | Brand typography |
| Shape styles | `.clipShape()`, `.containerShape()` | 17+ | Rounded corners, custom shapes |
| Scroll transitions | `.scrollTransition()` | 17+ | Parallax, scale effects on scroll |
| Spring animations | `.spring(duration:bounce:)` | 17+ | Bouncy, modern feel |
| Symbol effects | `.symbolEffect(.bounce)`, `.symbolEffect(.pulse)` | 17+ | Animated SF Symbols |
| Sensory feedback | `.sensoryFeedback(.impact, trigger:)` | 17+ | Haptic refinement |
| Phase animations | `PhaseAnimator` | 17+ | Multi-step animations |
| Keyframe animations | `KeyframeAnimator` | 17+ | Complex motion paths |

### Custom Font Recommendation

For a 13-year-old's game in 2026, the typography should feel modern and slightly playful without being childish.

**Recommendation: Use the system font (SF Pro) with varied weights and styles.** Rationale:
- Zero bundle size impact
- Automatically supports Dynamic Type accessibility
- SF Pro Rounded (via `.fontDesign(.rounded)`) gives a friendly feel without a custom font
- Custom fonts from Google Fonts (like "Nunito" or "Outfit") are an option but add complexity (bundle the .ttf files, register in Info.plist) for marginal benefit

```swift
// Modern teen-friendly typography using system font
.font(.system(.title, design: .rounded, weight: .bold))
.font(.system(.body, design: .rounded))
```

**If a custom font IS desired:** Use SF Pro Rounded (already on-device, no bundling needed) via `.fontDesign(.rounded)`, available in iOS 16.1+.

### MeshGradient Consideration

`MeshGradient` was introduced in iOS 18. Since TimeQuest targets iOS 17.0+, using it requires:

```swift
if #available(iOS 18.0, *) {
    MeshGradient(/* ... */)
} else {
    LinearGradient(/* fallback */)
}
```

**Recommendation:** Use `MeshGradient` with fallback. It creates striking, modern backgrounds that feel premium. The fallback to `LinearGradient` is graceful.

**Confidence:** HIGH -- All of these are documented SwiftUI APIs that have been stable since iOS 17.

### What NOT to Use for UI Refresh

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| UIKit `UIViewRepresentable` wrappers | Breaks SwiftUI-native feel, adds complexity | SwiftUI equivalents exist for everything needed |
| Lottie animations | Third-party dependency, 2MB+ binary impact, overkill for UI chrome | SwiftUI `PhaseAnimator` + `KeyframeAnimator` |
| Custom rendering with Canvas | Overkill for UI refresh; SpriteKit already handles game animations | SwiftUI shape + gradient + animation APIs |
| SwiftUI-Introspect | Reaches into UIKit internals, breaks across iOS versions | Design within SwiftUI's built-in capabilities |

---

## Schema Evolution: SchemaV4

v3.0 requires new persisted data. Continue the established lightweight migration pattern.

### New Model Types

```swift
// TimeQuestSchemaV4

@Model
final class DifficultySnapshot {
    var cloudID: String = UUID().uuidString
    var emaAccuracy: Double = 50.0
    var difficultyLabel: String = "Getting Started"
    var hintVisibility: String = "full"
    var recordedAt: Date = Date.now
    var routineCloudID: String = ""

    init(/* ... */) { /* ... */ }
}

@Model
final class SpotifyPlaylistLink {
    var cloudID: String = UUID().uuidString
    var routineCloudID: String = ""
    var spotifyPlaylistID: String = ""
    var targetDurationSeconds: Int = 0
    var lastUpdated: Date = Date.now

    init(/* ... */) { /* ... */ }
}
```

### Modified Existing Models

```swift
// Routine: add schedule intelligence fields
var scheduleMode: String = "manual"  // "manual" | "calendar"
var calendarKeywords: [String] = []  // Keywords to match in calendar events

// PlayerProfile: add Spotify connection state (token in Keychain, not SwiftData)
var spotifyConnected: Bool = false
var preferredDifficultyOverride: String? = nil
```

**Migration:** Lightweight (add properties with defaults). Extends `TimeQuestMigrationPlan` with `v3ToV4` stage.

**Confidence:** HIGH -- follows exact same pattern as V1->V2->V3 migrations already working in production.

---

## Recommended Stack (Complete v3.0 Additions)

### Core Additions

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| EventKit.framework | Ships with iOS 17 SDK | Calendar read access | First-party, stable, only option for calendar data |
| SpotifyiOS (SPM) | Latest stable (verify) | OAuth + playback control | No backend needed, native auth flow, app-remote playback |
| Security.framework | Ships with iOS SDK | Keychain for Spotify tokens | Already available, no added dependency |

### New Pure Domain Engines (No Dependencies)

| Engine | Purpose | Pattern Follows |
|--------|---------|----------------|
| `AdaptiveDifficultyEngine` | EMA-based difficulty calibration | `InsightEngine`, `CalibrationTracker` |
| `CalendarIntelligenceEngine` | Schedule context from calendar data | `InsightEngine` (value-type bridge pattern) |
| `RoutinePlaylistEngine` | Duration-matched playlist assembly | `TimeEstimationScorer` (pure computation) |

### New Service Layer Components

| Service | Purpose | Dependencies |
|---------|---------|-------------|
| `CalendarService` | Wraps EventKit, handles permissions | EventKit.framework |
| `SpotifyAuthService` | OAuth flow, token management | SpotifyiOS SDK, Security.framework |
| `SpotifyMusicService` | Search, playlist CRUD, playback | SpotifyiOS SDK, URLSession (Web API) |
| `KeychainHelper` | Simple Keychain read/write | Security.framework |

### Development Tools (No Change)

| Tool | Purpose | Notes |
|------|---------|-------|
| generate-xcodeproj.js | pbxproj generation | Needs update for SPM dependency section |
| Xcode 16.2 | IDE + build | No change |
| Swift 6.0 | Language | No change |

---

## Installation

### EventKit (No Installation -- System Framework)

Already available in the iOS SDK. Add `import EventKit` where needed.

Update generate-xcodeproj.js to link EventKit.framework (same pattern as existing CloudKit.framework linkage).

### Spotify iOS SDK (SPM)

```
Xcode > File > Add Package Dependencies
URL: https://github.com/spotify/ios-sdk
Version Rule: Up to Next Major Version
```

**For generate-xcodeproj.js:**
The pbxproj needs new sections:
- `XCRemoteSwiftPackageReference` in the project objects
- `XCSwiftPackageProductDependency` in the target
- Package reference in the target's `packageProductDependencies`

This is the first SPM dependency, so the generate-xcodeproj.js template needs extension. This is a moderate-complexity change to the build script.

### Keychain (No Installation -- Security Framework)

Already available. `import Security` where needed.

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| **SpotifyiOS SDK** | Spotify Web API only | Web API requires a backend server for token refresh. iOS SDK handles everything on-device. For a solo-dev project, eliminating the backend is critical. |
| **SpotifyiOS SDK** | Apple MusicKit | MusicKit only works with Apple Music, not Spotify. The player uses Spotify. Supporting both is v4.0 scope. |
| **EMA for adaptive difficulty** | Simple moving average | EMA responds faster to recent performance changes. A 13-year-old who has a breakthrough session should feel the game respond immediately, not after 10 more sessions dilute the average. |
| **EMA for adaptive difficulty** | Core ML model | Massive overkill. The input is a single time series of accuracy percentages. Statistical methods handle this in 20 lines. ML adds binary size, complexity, and training data requirements for zero benefit. |
| **EventKit direct** | CalendarKit (third-party) | CalendarKit is a UI library for displaying calendars. We only need read access to event data, not calendar display. EventKit is the correct, simpler choice. |
| **Keychain (Security.framework)** | KeychainAccess (third-party) | We store exactly 2 values (access token, refresh token). The raw Keychain API is ~30 lines for this. Adding a dependency for 30 lines of code is not justified. |
| **System font with .rounded design** | Custom font (Nunito, Outfit, etc.) | Bundling custom fonts adds ~200KB-1MB, requires Info.plist registration, and breaks Dynamic Type unless extra work is done. SF Pro Rounded achieves the same "friendly modern" feel for free. |
| **SwiftUI built-in animations** | Lottie | Lottie adds ~2MB binary size and requires exported After Effects files. SwiftUI's PhaseAnimator + KeyframeAnimator + symbolEffect cover everything needed for a UI refresh without a dependency. |

---

## What NOT to Add

| Temptation | Why Not |
|------------|---------|
| **Apple MusicKit** | Player uses Spotify. MusicKit is Apple Music only. Don't build for two music services when only one is used. If Apple Music support is wanted later, that is a separate feature. |
| **Core ML / CreateML for adaptive difficulty** | Statistical EMA on a single numeric time series does not need machine learning. Adding Core ML would increase binary size by several MB and complexity by orders of magnitude for identical results. |
| **Lottie for animations** | SwiftUI's native animation system (PhaseAnimator, KeyframeAnimator, spring animations, symbol effects) handles everything needed for a UI refresh. Lottie is for complex vector animations designed in After Effects -- not needed here. |
| **WidgetKit** | Still out of scope. The UI refresh is in-app only. Widgets can be a v4.0 feature. |
| **App Intents / Shortcuts** | Deferred from v2.0, still out of scope. Calendar intelligence does not need Shortcuts -- it reads EventKit directly. |
| **Combine** | Still not needed. The app uses @Observable. Spotify SDK callbacks can be bridged with async/await continuations. |
| **Firebase / Amplitude analytics** | Still not appropriate. A 13-year-old's personal tool should not phone home. Analytics are player-facing (InsightEngine, WeeklyReflectionEngine). |
| **Backend server** | The Spotify iOS SDK + PKCE flow eliminates the need for a backend token exchange server. Keep the app fully client-side. |
| **SwiftUI-Introspect** | Reaches into UIKit internals. Fragile across iOS versions. The UI refresh should stay within SwiftUI's public API surface. |
| **Third-party HTTP client (Alamofire, etc.)** | URLSession handles Spotify Web API calls. The API surface is simple REST with JSON. No benefit to adding a dependency. |
| **Realm / GRDB** | SwiftData continues to serve well. No reason to change persistence layer for v3.0 features. |

---

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| EventKit | iOS 17.0+ | `requestFullAccessToEvents()` requires iOS 17.0+ (replaces deprecated `requestAccess(to:)`) |
| SpotifyiOS SDK | iOS 16.0+ (verify) | Should work fine with iOS 17.0+ target. Verify minimum deployment target in current SDK. |
| MeshGradient | iOS 18.0+ only | Use with `if #available(iOS 18.0, *)` check. Fallback to LinearGradient for iOS 17. |
| SF Symbols 5 | iOS 17.0+ | All new symbol effects (.bounce, .pulse, .variableColor) available. |
| PhaseAnimator | iOS 17.0+ | Core animation API for the refresh. |
| KeyframeAnimator | iOS 17.0+ | Complex animation paths for celebration moments. |
| .scrollTransition() | iOS 17.0+ | Scroll-driven animation modifier. |
| Swift 6.0 strict concurrency | SpotifyiOS SDK | May need `@preconcurrency import` -- verify. |

---

## Build System Impact

### generate-xcodeproj.js Changes Required

1. **Add EventKit.framework** to SDK dependencies (same pattern as CloudKit)
2. **Add SPM package reference** for SpotifyiOS -- NEW section type in pbxproj
3. **Register new source files** in the sourceFiles array
4. **Add Keychain-related entitlements** if needed (Keychain Sharing group)

The SPM addition is the most significant build system change. The pbxproj format for SPM packages includes:
- `XCRemoteSwiftPackageReference` object with repository URL and version rule
- `XCSwiftPackageProductDependency` object linking product to target
- References in the target's `packageProductDependencies` array

**Confidence:** MEDIUM -- The pbxproj format for SPM is well-documented but has not been implemented in the existing generate-xcodeproj.js. This will require careful implementation.

---

## Integration Points with Existing Architecture

### How new services integrate with AppDependencies

```swift
// AppDependencies.swift -- additions
@MainActor
@Observable
final class AppDependencies {
    // Existing
    let routineRepository: RoutineRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    let playerProfileRepository: PlayerProfileRepositoryProtocol
    let soundManager: SoundManager
    let notificationManager: NotificationManager
    let syncMonitor: CloudKitSyncMonitor

    // New for v3.0
    let calendarService: CalendarService      // NEW
    let spotifyAuthService: SpotifyAuthService // NEW
    let spotifyMusicService: SpotifyMusicService // NEW

    init(modelContext: ModelContext) {
        // ... existing init ...
        self.calendarService = CalendarService()
        self.spotifyAuthService = SpotifyAuthService()
        self.spotifyMusicService = SpotifyMusicService(authService: spotifyAuthService)
    }
}
```

### Data flow: Adaptive difficulty during gameplay

```
Player starts quest
  -> GameSessionViewModel.startQuest() [existing]
    -> Check CalibrationTracker [existing]
    -> IF post-calibration:
      -> Fetch recent EstimationSnapshots [existing pattern]
      -> AdaptiveDifficultyEngine.computeEMA(snapshots:) [NEW]
      -> AdaptiveDifficultyEngine.difficultyLevel(emaAccuracy:) [NEW]
      -> Apply: hint visibility, tolerance adjustments [NEW]
    -> Load contextual hints [existing]
    -> phase = .estimating [existing]
```

### Data flow: Calendar-aware routine filtering

```
App opens / PlayerHomeView.onAppear
  -> loadTodayQuests() [existing, modified]
    -> CalendarService.fetchEventsForToday() [NEW]
    -> CalendarIntelligenceEngine.analyzeDay(events:) [NEW]
    -> Returns ScheduleContext [NEW]
    -> RoutineRepository.fetchActiveForToday() [existing]
    -> Filter routines based on ScheduleContext [NEW logic]
      -> School day? Show school morning routine.
      -> Holiday? Hide school morning, show fun quests.
      -> Roller derby day? Show activity prep routine.
    -> Display filtered routine list [existing UI, refreshed]
```

### Data flow: Spotify playlist on quest start

```
Player taps quest card
  -> QuestView appears [existing]
    -> SpotifyViewModel checks connection [NEW]
    -> IF connected:
      -> Calculate total routine duration from tasks [existing data]
      -> RoutinePlaylistEngine.buildPlaylist(targetDuration:) [NEW]
      -> SpotifyMusicService.startPlayback(tracks:) [NEW]
      -> Music plays while player does quest
    -> IF not connected:
      -> Quest proceeds normally (music is optional, never blocking)
```

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Adaptive difficulty engine | HIGH | Pure Swift math on existing data types. No framework uncertainty. |
| EventKit integration | HIGH (API), LOW (iOS 18 changes) | Stable framework, but verify iOS 18 privacy changes. |
| Spotify iOS SDK | MEDIUM | SDK exists and is maintained, but exact version, Swift 6 compatibility, and current OAuth flow need verification against current docs. |
| Spotify Web API | MEDIUM | Well-documented REST API, but rate limits, free-tier limitations, and current endpoint availability need verification. |
| UI refresh (SwiftUI built-in) | HIGH | All APIs documented and available on iOS 17+. |
| Schema V4 migration | HIGH | Follows established V1->V2->V3 pattern exactly. |
| Build system (SPM addition) | MEDIUM | First SPM dependency -- pbxproj generation needs extension. |
| Keychain storage | HIGH | Standard Security.framework API. Well-documented. |
| Calendar intelligence engine | HIGH | Pure Swift domain logic. |
| Playlist duration matching | HIGH | Pure algorithm, well-understood problem space. |

---

## Sources

- Existing TimeQuest v2.0 codebase (66 Swift files analyzed)
- v2.0 STACK.md research (2026-02-13) -- established base stack decisions
- Apple Developer Documentation (training data): EventKit, Security (Keychain), SwiftUI animations
- Spotify Developer Documentation (training data): iOS SDK architecture, Web API endpoints, OAuth flows
- WWDC 2023: "Discover Observation in SwiftUI" (PhaseAnimator, KeyframeAnimator, symbolEffect)
- WWDC 2023: "What's new in SwiftUI" (scrollTransition, MeshGradient preview)
- WWDC 2024: "What's new in SwiftUI" (MeshGradient in iOS 18)
- Game design literature: EMA-based adaptive difficulty (common pattern in educational games)
- **NOTE:** WebSearch and WebFetch were unavailable during this session. The following should be verified against current documentation before implementation:
  1. Spotify iOS SDK current version and Swift 6 compatibility
  2. Spotify OAuth PKCE flow current implementation details
  3. EventKit iOS 18 privacy changes (if any)
  4. MeshGradient availability confirmation in iOS 18
  5. Spotify free-tier vs Premium playback limitations in current iOS SDK

---
*Stack research for: TimeQuest v3.0 -- Adaptive & Connected*
*Researched: 2026-02-14*
