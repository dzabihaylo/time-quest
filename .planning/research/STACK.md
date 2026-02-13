# Technology Stack

**Project:** TimeQuest -- iOS Time-Perception Training Game
**Researched:** 2026-02-12
**Overall Confidence:** MEDIUM (unable to verify versions via web/Context7 -- versions based on training data through mid-2025 plus reasonable extrapolation; flag all versions for validation before project init)

---

## Recommended Stack

### Platform Target

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Deployment target | iOS 17.0+ | SwiftData requires iOS 17. Dropping iOS 16 is acceptable -- 13-year-olds overwhelmingly run recent iOS versions. By Feb 2026, iOS 17 adoption is near-universal. |
| Xcode | 16.x (latest stable) | Ships with Swift 6.x and iOS 18 SDK. Use whatever is current when you create the project. |
| Swift | 6.x | Strict concurrency checking, typed throws, better macros. If Swift 6 strict mode causes friction with SpriteKit callbacks, keep `swift-settings: [.enableUpcomingFeature("StrictConcurrency")]` but set module-level `@preconcurrency` on SpriteKit imports. |

**Confidence:** MEDIUM -- Swift 6 was released mid-2024; Xcode 16 shipped fall 2024. By Feb 2026 there may be a Swift 6.1 or Xcode 16.3+. Verify exact latest stable versions before `xcode-select`.

---

### Core Framework: SwiftUI + SpriteKit Hybrid

| Technology | Purpose | Why This |
|------------|---------|----------|
| **SwiftUI** | All non-game UI: menus, settings, parent dashboard, progress screens, onboarding | Declarative, fast iteration, native animations, accessibility built-in. Solo dev productivity multiplier. |
| **SpriteKit** (via `SpriteView`) | Game scenes: timer challenges, visual feedback, animated rewards | Apple's first-party 2D engine. Zero dependency risk. `SpriteView` embeds SpriteKit scenes directly in SwiftUI with two lines of code. |

**Architecture pattern:** SwiftUI owns navigation and state; SpriteKit owns real-time rendering. Communication flows through `@Observable` view models that SpriteKit scenes read/write.

**Why NOT alternatives:**

| Rejected | Why |
|----------|-----|
| Unity | Massive overkill for 2D timer games. Adds 200MB+ to binary. C# foreign to Swift ecosystem. Destroys solo-dev velocity for this scope. |
| Unreal | Even more overkill. Not suitable for casual 2D. |
| Godot | Growing iOS support but still requires bridging, export quirks, and a separate editor. Not worth the friction for what is fundamentally a UI-heavy app with light game elements. |
| Metal directly | Too low-level. SpriteKit abstracts Metal for you. |
| SceneKit | 3D engine. This game is 2D. |
| UIKit | SwiftUI is strictly better for new projects in 2025+. UIKit only if you need UICollectionView-level complexity, which this project does not. |
| Cocos2d-x | Effectively dead. Last meaningful update years ago. |
| RealityKit | AR/3D focused. Wrong tool. |

**Confidence:** HIGH -- SpriteKit + SwiftUI via `SpriteView` is well-established since iOS 15. This is not a controversial choice.

---

### Data Persistence: SwiftData

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **SwiftData** | Ships with iOS 17 SDK | Player progress, estimation history, routine definitions, calibration data, reward state | Apple's modern persistence layer built on Swift macros. `@Model` macro, `@Query` in SwiftUI, automatic CloudKit sync option. Replaces Core Data for new projects. |

**Why SwiftData over alternatives:**

| Rejected | Why |
|----------|-----|
| Core Data | SwiftData is Apple's replacement. Core Data still works but requires more boilerplate (`NSManagedObject` subclasses, `.xcdatamodeld` files). For a new project, SwiftData is the right call. |
| Realm | Third-party dependency. SwiftData covers this project's needs. Realm's future is uncertain after MongoDB's acquisition shifts. |
| SQLite (raw / GRDB) | Too low-level for this use case. SwiftData handles schema, migrations, and SwiftUI integration automatically. |
| UserDefaults | Only for tiny preferences (sound on/off). Not for structured game data. |
| Firebase/Firestore | Cloud-first adds complexity, latency, and a Google dependency. This game works offline. If cloud sync is needed later, SwiftData's CloudKit integration handles it with zero code changes. |

**Data model sketch:**

```swift
@Model
class Player {
    var name: String
    var createdAt: Date
    var totalXP: Int
    @Relationship(deleteRule: .cascade) var estimations: [Estimation]
    @Relationship(deleteRule: .cascade) var routines: [Routine]
}

@Model
class Estimation {
    var taskDescription: String
    var estimatedSeconds: Int
    var actualSeconds: Int
    var accuracy: Double  // computed: 1.0 - abs(estimated - actual) / actual
    var completedAt: Date
    var routine: Routine?
}

@Model
class Routine {
    var name: String
    var steps: [RoutineStep]  // Codable struct array
    var isActive: Bool
    var createdBy: CreatorRole  // .parent or .player
}
```

**Confidence:** MEDIUM -- SwiftData was introduced at WWDC 2023 (iOS 17), with significant improvements at WWDC 2024. It had early-adopter bugs in iOS 17.0-17.2. By iOS 17.4+ / iOS 18, it is stable. Verify current state of any `#Index` or compound predicate features if needed.

---

### State Management: Swift Observation Framework

| Technology | Purpose | Why |
|------------|---------|-----|
| **@Observable macro** (Observation framework) | View models, game state, app-wide state | Replaces `ObservableObject` / `@Published`. Less boilerplate, better performance (fine-grained observation), works with SwiftUI and SpriteKit scenes. |
| **@Environment** | Dependency injection for shared services (audio manager, haptics, notification scheduler) | SwiftUI-native DI. No third-party container needed. |

**Pattern:**

```swift
@Observable
class GameViewModel {
    var currentChallenge: TimerChallenge?
    var isTimerRunning = false
    var elapsedSeconds: Int = 0
    var playerEstimate: Int = 0

    // SpriteKit scene reads this; SwiftUI views observe it
}
```

**Why NOT:**

| Rejected | Why |
|----------|-----|
| Combine | Observation framework replaces Combine for SwiftUI state. Combine is still fine for async streams (e.g., timer ticks), but do not use `@Published` + `ObservableObject` for view models. |
| TCA (The Composable Architecture) | Excellent architecture but heavy learning curve and overkill for a solo-dev game. Adds friction to rapid prototyping. Consider only if the app grows to 30+ screens with complex shared state. |
| Redux-style (ReSwift, etc.) | Same argument as TCA. Overhead exceeds benefit at this scale. |

**Confidence:** HIGH -- `@Observable` is the clear direction from Apple since WWDC 2023. Well-documented, stable.

---

### Audio: AVFoundation + SKAction

| Technology | Purpose | Why |
|------------|---------|-----|
| **AVFoundation** (`AVAudioPlayer`) | Background music, ambient sounds | Fine-grained control over volume, looping, fade. |
| **SKAction.playSoundFileNamed** | In-game SFX tied to SpriteKit actions | Zero-overhead sound effects within SpriteKit scenes. |

**Keep it simple.** Do NOT add a third-party audio engine. `AVAudioPlayer` handles everything this game needs. Create a small `AudioManager` singleton (or `@Observable` service) that SwiftUI and SpriteKit both reference.

**Confidence:** HIGH -- AVFoundation is bedrock iOS API. Unchanged in relevant ways for years.

---

### Haptics: Core Haptics

| Technology | Purpose | Why |
|------------|---------|-----|
| **UIImpactFeedbackGenerator** | Simple taps, button presses | One-line haptic feedback. |
| **Core Haptics** (`CHHapticEngine`) | Custom haptic patterns for timer beats, success/failure feedback | Lets you create rhythmic "tick" haptics that reinforce time perception. This is a **critical feature** -- haptic rhythm is a direct training mechanism for internal clock calibration. |

**Confidence:** HIGH -- Core Haptics has been stable since iOS 13.

---

### Notifications: UserNotifications

| Technology | Purpose | Why |
|------------|---------|-----|
| **UNUserNotificationCenter** | Routine reminders, "time to practice" nudges, streak maintenance | First-party. No server needed. Supports scheduled, repeating, and location-triggered notifications. |

**Key consideration:** For a 13-year-old, notifications must be thoughtful and non-spammy. Implement parent-controlled notification frequency in the parent dashboard.

**Confidence:** HIGH -- Stable API since iOS 10.

---

### Animation: SwiftUI Animations + SpriteKit

| Technology | Purpose | Why |
|------------|---------|-----|
| **SwiftUI `.animation()` / `withAnimation`** | UI transitions, progress bars, XP counters | Declarative, interruptible, spring-based. |
| **SpriteKit `SKAction`** | In-game sprite animations, particle effects for rewards | SpriteKit's native action system. Sequencing, grouping, easing built-in. |
| **SpriteKit `SKEmitterNode`** | Celebration particles (level up, streak milestones) | Xcode's built-in particle editor. Visual reward without code complexity. |

**Why NOT Lottie:** Adds a dependency for something SwiftUI animations and SpriteKit particles handle natively. Only consider Lottie if a designer provides After Effects animations. For a solo dev, native tools are faster.

**Confidence:** HIGH

---

### Charts: Swift Charts

| Technology | Purpose | Why |
|------------|---------|-----|
| **Swift Charts** (Charts framework) | Progress visualization: estimation accuracy over time, calibration curves, streaks | First-party, SwiftUI-native, declarative. Shows the player (and parent) whether time perception is improving. |

**Confidence:** HIGH -- Swift Charts shipped with iOS 16, mature by iOS 17+.

---

### Networking: None (initially)

This game is **offline-first by design**. No backend, no accounts, no server.

If multi-device sync is needed later, enable **SwiftData + CloudKit** (requires an Apple Developer account and iCloud entitlement). This is a configuration change, not an architecture change.

If parent-child device pairing is needed later, consider **MultipeerConnectivity** (local Bluetooth/WiFi) or a lightweight CloudKit shared database.

**Do NOT pre-build networking infrastructure.** YAGNI. Add it when there is a validated need.

**Confidence:** HIGH -- architectural decision, not technology uncertainty.

---

### Testing

| Technology | Purpose | Why |
|------------|---------|-----|
| **XCTest** | Unit tests for estimation logic, scoring algorithms, data model | First-party. Ships with Xcode. |
| **Swift Testing** (`@Test`, `#expect`) | Modern test syntax for new test files | Apple's new testing framework (WWDC 2024). Cleaner syntax than XCTest. Use for new tests; no need to migrate existing XCTest suites. |
| **XCUITest** | UI automation for critical flows (onboarding, parent setup) | First-party UI testing. |
| **Xcode Previews** | Rapid visual iteration on SwiftUI views | Not a "test" but critical for solo-dev velocity. Use `#Preview` macro liberally. |

**Why NOT third-party test frameworks:** Quick/Nimble added value when XCTest was verbose. Swift Testing makes them redundant.

**Confidence:** MEDIUM -- Swift Testing was introduced at WWDC 2024. By Feb 2026 it should be stable, but verify that `@Test` works reliably with async tests and SwiftData `ModelContainer` in-memory configurations.

---

### Accessibility

| Technology | Purpose | Why |
|------------|---------|-----|
| **SwiftUI Accessibility modifiers** | VoiceOver, Dynamic Type, reduce motion | Built into SwiftUI. Use `.accessibilityLabel()`, `.accessibilityHint()`, `.dynamicTypeSize()`. |
| **`AccessibilityNotification`** | Announce timer state changes to VoiceOver users | Critical for a time-based game to be accessible. |

**This is not optional.** A time-perception game must handle:
- VoiceOver users who cannot see visual timers
- Users with vestibular disorders (respect `accessibilityReduceMotion`)
- Dynamic Type for readability

**Confidence:** HIGH

---

### Package Management: Swift Package Manager

| Technology | Purpose | Why |
|------------|---------|-----|
| **Swift Package Manager** (built into Xcode) | Dependency management | First-party. Integrated into Xcode. CocoaPods is legacy; Carthage is effectively dead. SPM is the only modern choice. |

**Confidence:** HIGH

---

## Supporting Libraries (Third-Party)

The philosophy is **minimize dependencies**. Apple's first-party frameworks cover 95% of this project's needs. Only add third-party libraries when the alternative is writing 500+ lines of non-differentiating code.

| Library | Purpose | When to Add | Confidence |
|---------|---------|-------------|------------|
| **None initially** | -- | -- | -- |

**Libraries to consider adding ONLY if needed:**

| Library | Purpose | When to Add | Why Not Now |
|---------|---------|-------------|------------|
| Lottie (airbnb/lottie-ios) | Complex designer-provided animations | If you hire a designer who delivers After Effects files | SpriteKit particles + SwiftUI animations cover solo-dev needs |
| KeychainAccess or SwiftKeychainWrapper | Secure storage for parent PIN | If parent auth moves beyond simple passcode | A 4-digit parent PIN stored in UserDefaults (or basic Keychain API) is fine for v1 |
| SwiftLint | Code style enforcement | From day one (dev dependency only) | Actually, DO add this. See below. |

### SwiftLint: Add This

```bash
brew install swiftlint
```

Add a `.swiftlint.yml` to the project root. SwiftLint is not a library dependency (not in your SPM manifest) -- it is a build tool. Run it as a build phase script. It catches bugs solo devs miss without code review.

**Confidence:** HIGH -- SwiftLint is the de facto Swift linter. Stable for years.

---

## Full Dependency List

```
# Package.swift / Xcode SPM dependencies
# (none -- all first-party frameworks)

# Build tools (installed via Homebrew, not SPM)
brew install swiftlint
```

**Frameworks used (all ship with iOS SDK, no dependency management needed):**
- SwiftUI
- SpriteKit
- SwiftData
- Observation
- AVFoundation
- CoreHaptics
- UserNotifications
- Charts
- XCTest / Swift Testing
- Accessibility

---

## Version Pinning Strategy

Since this project uses zero third-party SPM packages, version pinning is a non-issue. All frameworks are tied to the iOS SDK version, which is tied to the Xcode version.

**Rule:** Target the second-latest major iOS version (iOS 17) to balance reach vs. API availability. When iOS 19 ships (likely fall 2026), consider bumping to iOS 18 minimum.

---

## Development Environment

| Tool | Version | Purpose |
|------|---------|---------|
| Xcode | Latest stable (16.x as of early 2026) | IDE, simulator, instruments |
| Simulator | iPhone 15 / iPhone 16 sizes | Primary test devices |
| Physical device | Any iPhone running iOS 17+ | Haptics, real-world timer accuracy testing |
| SwiftLint | Latest stable | Code quality |
| SF Symbols | 6.x (ships with Xcode) | Icons throughout the UI -- thousands of free, scalable, accessible symbols |
| Xcode Instruments | Ships with Xcode | Performance profiling, memory leak detection |

---

## Alternatives Considered (Summary)

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| UI Framework | SwiftUI | UIKit | SwiftUI is faster for solo dev, better for this app's declarative UI needs |
| Game Engine | SpriteKit | Unity, Godot | Overkill; SpriteKit is first-party, zero-dependency, sufficient for 2D timer games |
| Persistence | SwiftData | Core Data, Realm, SQLite | SwiftData is Apple's modern replacement, less boilerplate, SwiftUI-native |
| State | @Observable | Combine, TCA | @Observable is Apple's current direction; simpler for this scale |
| Audio | AVFoundation | FMOD, third-party | AVFoundation covers all needs with zero dependencies |
| Charts | Swift Charts | Charts (danielgindi) | First-party, SwiftUI-native, no dependency |
| Package Manager | SPM | CocoaPods, Carthage | SPM is first-party and the only modern option |
| Networking | None (offline-first) | Firebase, Supabase | YAGNI; add CloudKit sync later if needed |
| Linter | SwiftLint | SwiftFormat | SwiftLint catches more bug-prone patterns; SwiftFormat is style-only |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| SwiftUI + SpriteKit hybrid | HIGH | Well-established pattern since `SpriteView` introduction (iOS 15) |
| SwiftData | MEDIUM | Stable since iOS 17.4+ but verify current macro syntax and migration APIs before starting |
| @Observable | HIGH | Clear Apple direction, well-documented |
| Swift 6 strict concurrency | MEDIUM | May cause friction with SpriteKit's `SKScene` (which is `@MainActor`-adjacent but not annotated). Test early. |
| Zero third-party dependencies | HIGH | Intentional architectural choice; all needs met by Apple frameworks |
| Version numbers | LOW | Training data cuts off mid-2025; exact Xcode/Swift/iOS versions should be verified at project start |

---

## Sources

- Apple Developer Documentation (developer.apple.com) -- primary authority for all framework recommendations
- WWDC 2023 sessions on SwiftData and SwiftUI
- WWDC 2024 sessions on Swift Testing and Observation framework
- SpriteKit + SpriteView documentation (iOS 15+)
- **NOTE:** Web verification was unavailable during this research session. All version numbers should be confirmed against current Apple documentation before project initialization. Confidence levels reflect this limitation.
