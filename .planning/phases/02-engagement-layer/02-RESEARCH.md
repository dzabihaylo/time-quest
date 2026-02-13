# Phase 2: Engagement Layer - Research

**Researched:** 2026-02-13
**Domain:** iOS progression systems, haptic/audio feedback, charting, local notifications
**Confidence:** HIGH

## Summary

Phase 2 adds four capabilities to the Phase 1 estimation-feedback loop: (1) an XP/leveling progression system tied to estimation accuracy, (2) streak tracking with graceful pause semantics, (3) sensory polish (haptics, sounds, particle celebrations, trend charts), and (4) game-framed local notifications with player-controlled preferences.

All four capabilities use first-party Apple frameworks already available at the project's iOS 17.0 minimum target. Swift Charts (iOS 16+) handles trend visualization, SwiftUI's `.sensoryFeedback()` modifier (iOS 17+) handles haptics declaratively, AVFoundation handles sound effects, SpriteKit (already in Phase 1 via `AccuracyRevealScene`) handles particle celebrations, and UserNotifications handles scheduled local notifications. No new third-party dependencies are needed.

The primary architectural concern is data model expansion. Phase 1's SwiftData models (`GameSession`, `TaskEstimation`, `Routine`, `RoutineTask`) need new properties and potentially a new `PlayerProfile` model for progression state. SwiftData supports lightweight migration automatically when adding new properties with default values or adding new models, so no `VersionedSchema` is strictly required -- but defining one is recommended for future-proofing.

**Primary recommendation:** Add a `PlayerProfile` singleton model for XP/level/streak state, extend `TaskEstimation` with a computed personal-best flag, create pure-Swift domain engines for XP calculation and streak tracking, and use first-party Apple frameworks for all sensory and notification features.

## Standard Stack

### Core
| Framework | Min iOS | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftData | 17.0 | Persistence for progression state (XP, streaks, personal bests) | Already used in Phase 1; lightweight migration handles new properties |
| Swift Charts | 16.0 | Accuracy trend line chart (PROG-05) | First-party, declarative, integrates with SwiftUI natively |
| UserNotifications | 10.0 | Scheduled local notifications (NOTF-01/02/03) | Only option for local notifications on iOS |
| AVFoundation | 2.0 | Sound effect playback (FEEL-02) | AVAudioPlayer is the standard approach for short bundled audio |
| SpriteKit | 7.0 | Celebratory particle effects (FEEL-03) | Already used in Phase 1 AccuracyRevealScene |
| SwiftUI sensoryFeedback | 17.0 | Haptic feedback (FEEL-01) | Declarative, no UIKit bridge needed, built for SwiftUI |

### Supporting
| Framework | Min iOS | Purpose | When to Use |
|-----------|---------|---------|-------------|
| UIKit UIFeedbackGenerator | 10.0 | Fallback haptics if needed outside SwiftUI view lifecycle | Only if `.sensoryFeedback()` doesn't cover a specific trigger point |
| AudioToolbox | 2.0 | System-level haptic (AudioServicesPlaySystemSound 1519) | Not needed -- `.sensoryFeedback()` is preferred |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Swift Charts | DGCharts (formerly Charts by Daniel Gindi) | Third-party; violates zero-dependency constraint; Swift Charts covers the line chart need |
| AVAudioPlayer | AudioServicesPlaySystemSound | No volume control, no custom sounds, limited to 30s; AVAudioPlayer is better for game SFX |
| SKEmitterNode (code) | .sks particle file in Xcode editor | .sks files require Xcode GUI interaction; code-based particles (already used in Phase 1) are more maintainable for CI/CLI workflows |
| SwiftUI .sensoryFeedback | UIImpactFeedbackGenerator direct | UIKit bridge required; .sensoryFeedback is cleaner in SwiftUI and available at iOS 17 target |

**Installation:** No new dependencies. All frameworks are first-party Apple and linked automatically.

## Architecture Patterns

### Recommended Project Structure (New/Modified Files)
```
TimeQuest/
├── Models/
│   ├── PlayerProfile.swift        # NEW: @Model singleton for XP, level, streak
│   ├── GameSession.swift          # MODIFY: add xpEarned property
│   └── TaskEstimation.swift       # EXISTING: query for personal bests
├── Domain/
│   ├── XPEngine.swift             # NEW: pure XP calculation from AccuracyRating
│   ├── LevelCalculator.swift      # NEW: pure level-from-XP curve
│   ├── StreakTracker.swift         # NEW: pure streak logic with graceful pause
│   └── PersonalBestTracker.swift  # NEW: pure personal best detection
├── Repositories/
│   └── PlayerProfileRepository.swift  # NEW: CRUD for PlayerProfile
├── Features/
│   ├── Player/
│   │   ├── ViewModels/
│   │   │   ├── GameSessionViewModel.swift    # MODIFY: XP award, personal best check, haptic triggers
│   │   │   └── ProgressionViewModel.swift    # NEW: drives progression UI
│   │   └── Views/
│   │       ├── PlayerHomeView.swift          # MODIFY: show level, streak, XP bar
│   │       ├── SessionSummaryView.swift      # MODIFY: show XP earned, level progress
│   │       ├── AccuracyRevealView.swift      # MODIFY: haptics, sounds, enhanced celebration
│   │       ├── AccuracyTrendChartView.swift  # NEW: Swift Charts line chart
│   │       └── PlayerStatsView.swift         # NEW: personal bests, trend chart host
│   └── Shared/
│       └── Components/
│           ├── XPBarView.swift               # NEW: animated XP progress bar
│           ├── StreakBadgeView.swift          # NEW: streak display with flame icon
│           └── LevelBadgeView.swift          # NEW: "Time Sense Lv. X" display
├── Game/
│   ├── AccuracyRevealScene.swift             # MODIFY: more particle variants per rating
│   └── CelebrationScene.swift               # NEW: milestone celebration (level up, streak, PB)
├── Services/
│   ├── SoundManager.swift                    # NEW: AVAudioPlayer wrapper, mute toggle
│   ├── HapticManager.swift                   # NEW: centralized haptic triggers (or use .sensoryFeedback inline)
│   └── NotificationManager.swift             # NEW: schedule/cancel/manage local notifications
└── Resources/
    └── Sounds/                               # NEW: bundled .wav/.caf sound effect files
```

### Pattern 1: Pure Domain Engine (XP Calculation)
**What:** XP calculation as a pure function with no framework dependencies, matching the Phase 1 pattern of `TimeEstimationScorer`.
**When to use:** All game logic that converts data to decisions.
**Example:**
```swift
// Source: Phase 1 pattern (TimeEstimationScorer.swift)
struct XPEngine {
    /// XP earned from a single task estimation. Based on accuracy, not speed.
    /// Pure function -- no side effects.
    static func xpForEstimation(rating: AccuracyRating) -> Int {
        switch rating {
        case .spot_on: return 100
        case .close:   return 60
        case .off:     return 25
        case .way_off: return 10  // Always reward participation
        }
    }

    /// XP earned for an entire session (sum of task XP + completion bonus).
    static func xpForSession(estimations: [TaskEstimation]) -> Int {
        let taskXP = estimations.reduce(0) { $0 + xpForEstimation(rating: $1.rating) }
        let completionBonus = 20  // Reward finishing the whole routine
        return taskXP + completionBonus
    }
}
```

### Pattern 2: Concave Level Curve
**What:** XP thresholds that increase per level, but with diminishing growth so early levels come fast and later levels slow down. This keeps a 13-year-old engaged early.
**When to use:** Mapping cumulative XP to a "Time Sense" level.
**Example:**
```swift
// Source: Game design literature (davideaversa.it, gamedeveloper.com)
struct LevelCalculator {
    /// Base XP for level 1. Each subsequent level requires baseXP * level^exponent more.
    /// Exponent < 2 gives a concave curve (fast early, gradual slowdown).
    private static let baseXP: Double = 100
    private static let exponent: Double = 1.5

    /// Total XP required to reach a given level.
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 0 else { return 0 }
        return Int(baseXP * pow(Double(level), exponent))
    }

    /// Current level from total accumulated XP.
    static func level(fromTotalXP xp: Int) -> Int {
        guard xp > 0 else { return 0 }
        // Invert: level = (xp / baseXP) ^ (1/exponent)
        let level = pow(Double(xp) / baseXP, 1.0 / exponent)
        return max(1, Int(floor(level)))
    }

    /// Progress fraction (0.0-1.0) toward next level.
    static func progressToNextLevel(totalXP: Int) -> Double {
        let currentLevel = level(fromTotalXP: totalXP)
        let currentThreshold = xpRequired(forLevel: currentLevel)
        let nextThreshold = xpRequired(forLevel: currentLevel + 1)
        let range = nextThreshold - currentThreshold
        guard range > 0 else { return 0 }
        return Double(totalXP - currentThreshold) / Double(range)
    }
}
```

### Pattern 3: Graceful Streak with Pause Semantics
**What:** Track daily participation streaks that pause (not reset) on skipped days. Store last-played date and streak count. A skipped day freezes the streak; returning resumes it.
**When to use:** PROG-03 and PROG-04 requirements.
**Example:**
```swift
// Source: Streak design patterns (yukaichou.com, medium.com streak articles)
struct StreakTracker {
    struct StreakState {
        let currentStreak: Int
        let lastPlayedDate: Date?
        let isActive: Bool  // Did they play today?
    }

    /// Calculate streak after completing a session today.
    /// Rules:
    /// - Same day as last played: streak unchanged (already counted today)
    /// - Day after last played: streak increments (consecutive day)
    /// - 2+ days gap: streak PAUSES at current value (no reset, no punishment)
    static func updatedStreak(
        currentStreak: Int,
        lastPlayedDate: Date?,
        today: Date = .now
    ) -> StreakState {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)

        guard let lastPlayed = lastPlayedDate else {
            // First ever session
            return StreakState(currentStreak: 1, lastPlayedDate: today, isActive: true)
        }

        let lastStart = calendar.startOfDay(for: lastPlayed)

        if calendar.isDate(todayStart, inSameDayAs: lastStart) {
            // Already played today
            return StreakState(currentStreak: currentStreak, lastPlayedDate: lastPlayed, isActive: true)
        }

        let daysBetween = calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0

        if daysBetween == 1 {
            // Consecutive day -- increment
            return StreakState(currentStreak: currentStreak + 1, lastPlayedDate: today, isActive: true)
        } else {
            // Gap of 2+ days -- PAUSE, don't reset. Resume at same streak.
            return StreakState(currentStreak: currentStreak, lastPlayedDate: today, isActive: true)
        }
    }
}
```

### Pattern 4: SwiftUI Sensory Feedback
**What:** iOS 17's `.sensoryFeedback()` modifier for declarative haptics.
**When to use:** FEEL-01 -- haptic on estimate submission, accuracy reveal, milestones.
**Example:**
```swift
// Source: Apple developer documentation, hackingwithswift.com
struct AccuracyRevealView: View {
    @State private var revealTrigger = false

    var body: some View {
        VStack { /* ... */ }
            .sensoryFeedback(.impact(weight: .medium), trigger: revealTrigger)
            .onChange(of: showActual) { _, newValue in
                if newValue { revealTrigger.toggle() }
            }
    }
}
```

### Pattern 5: UNCalendarNotificationTrigger for Weekly Routines
**What:** Schedule one notification per routine on its active days at a configured time.
**When to use:** NOTF-01 -- single game-framed notification per routine.
**Example:**
```swift
// Source: Apple UNUserNotificationCenter docs, hackingwithswift.com
func scheduleRoutineNotification(routine: Routine, hour: Int, minute: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Quest Available!"
    content.body = "Your \(routine.displayName) quest is ready to play"
    content.sound = .default

    // Schedule for each active day
    for weekday in routine.activeDays {
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "routine-\(routine.persistentModelID)-day\(weekday)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
```

### Anti-Patterns to Avoid
- **XP for speed:** NEVER reward fast task completion. XP is based solely on estimation accuracy (AccuracyRating). This is a core design principle.
- **Streak guilt:** NEVER show "streak lost" or "streak broken" messaging. The streak pauses silently. If a player returns after a gap, they resume at their previous streak value.
- **Notification spam:** ONE notification per routine per scheduled time. Never batch or repeat. The player must be able to disable entirely.
- **Heavy haptics:** Over-haptic-ing causes annoyance and confusion. Use haptics only at key moments: estimate lock-in, accuracy reveal, milestone achievement. Not on every tap.
- **Blocking sound:** Sound must be optional (mutable) and must not block the UI thread. Always use AVAudioPlayer with `prepareToPlay()` ahead of time.
- **SwiftData auto-save mutations:** Phase 1 learned this lesson. Never mutate @Model properties from computed properties or SwiftUI body. Always mutate in explicit ViewModel methods and call `modelContext.save()`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Line/trend charts | Custom Canvas drawing | Swift Charts `LineMark` | Handles axis formatting, date scales, animations, accessibility, dark mode automatically |
| Haptic patterns | Custom CoreHaptics engine sequences | `.sensoryFeedback()` modifier | 1-line declarative; CoreHaptics only needed for custom waveforms we don't need |
| Notification scheduling | Manual Timer/BackgroundTask | UNUserNotificationCenter + UNCalendarNotificationTrigger | System-managed, survives app kill, handles timezone/DST, respects Do Not Disturb |
| Particle effects | Manual CAEmitterLayer or custom animation | SpriteKit SKEmitterNode / SKScene code | Already established pattern in Phase 1; SpriteKit handles particle lifecycle automatically |
| Sound preloading | Manual AVAudioSession lifecycle | Single SoundManager class wrapping AVAudioPlayer | Encapsulates prepareToPlay(), volume, mute toggle; simple but needs centralization |
| XP/Level math | Ad-hoc calculations scattered through views | Pure `XPEngine` and `LevelCalculator` structs | Testable, single source of truth, no framework dependencies |

**Key insight:** Phase 2's features are individually straightforward but touch many existing views. The risk is not technical complexity but integration sprawl -- updating 5+ views and the view model while keeping the Phase 1 gameplay loop intact. Centralized domain engines and a single `PlayerProfile` model prevent state fragmentation.

## Common Pitfalls

### Pitfall 1: SwiftData Migration on Model Changes
**What goes wrong:** Adding new stored properties without default values, or changing property types, causes a crash on first launch after update because SwiftData can't auto-migrate.
**Why it happens:** SwiftData performs lightweight migration automatically ONLY for additive changes with defaults.
**How to avoid:** Every new property on existing models (`GameSession`, etc.) MUST have a default value in the initializer. New models (`PlayerProfile`) are safe -- adding new models is always a lightweight migration. If in doubt, define a `VersionedSchema` and `SchemaMigrationPlan`.
**Warning signs:** EXC_BAD_ACCESS or "Failed to find a currently active container" crash on launch after adding model properties.

### Pitfall 2: Notification Permission Denied Silently
**What goes wrong:** App schedules notifications but user never sees them because authorization was denied and the app doesn't check.
**Why it happens:** `requestAuthorization` is called once; if denied, subsequent `add(request)` calls silently fail.
**How to avoid:** Always check `UNUserNotificationCenter.current().getNotificationSettings()` before scheduling. Show an in-app explanation if authorization is `.denied`. Provide a deep link to Settings.
**Warning signs:** Notifications work in development (auto-authorized in simulator) but not on real devices.

### Pitfall 3: AVAudioPlayer Deallocation
**What goes wrong:** Sound doesn't play or plays partially.
**Why it happens:** AVAudioPlayer is created as a local variable, gets deallocated before playback completes.
**How to avoid:** Store the player as a strong property on a long-lived object (e.g., `SoundManager` singleton or `@Observable` class). Call `prepareToPlay()` in advance to reduce first-play latency.
**Warning signs:** Sound works intermittently; works in debug but not release (optimizer removes "unused" variable faster).

### Pitfall 4: Streak Timezone Issues
**What goes wrong:** Player completes a session at 11:55 PM, then at 12:05 AM -- app thinks it's a different calendar day and increments streak, even though the player perceives it as the same evening.
**Why it happens:** Using `Calendar.current.startOfDay(for:)` without considering the player's perception of "one play session."
**How to avoid:** Use `Calendar.current` (which respects device locale) and `startOfDay(for:)` consistently. For this app, the standard calendar-day boundary is acceptable since the target user (13-year-old) has regular sleep schedules. Document this decision.
**Warning signs:** Streak jumps unexpectedly for late-night usage.

### Pitfall 5: Chart Performance with Large Datasets
**What goes wrong:** Accuracy trend chart becomes sluggish with months of data.
**Why it happens:** Passing hundreds/thousands of `TaskEstimation` objects directly to Swift Charts.
**How to avoid:** Aggregate data before charting. Pre-compute daily or weekly average accuracy. Limit the chart to the most recent 30-90 days by default with optional "show all" expansion.
**Warning signs:** Chart view takes >0.5s to appear; scrolling stutters.

### Pitfall 6: Notification Identifier Collisions
**What goes wrong:** Rescheduling a routine's notifications doesn't remove old ones, leading to duplicate or stale notifications.
**Why it happens:** Using random UUIDs as notification identifiers instead of deterministic IDs.
**How to avoid:** Use deterministic identifiers tied to the routine and weekday (e.g., `"routine-\(routineID)-day\(weekday)"`). Before scheduling, call `removePendingNotificationRequests(withIdentifiers:)` with the old IDs.
**Warning signs:** Player receives duplicate notifications or gets notified for deleted routines.

### Pitfall 7: PlayerProfile Singleton Race Condition
**What goes wrong:** Multiple views query/create `PlayerProfile` simultaneously, creating duplicates.
**Why it happens:** No uniqueness constraint; first access creates the profile, but concurrent access on app launch can race.
**How to avoid:** Create `PlayerProfile` exactly once in the app's init or first launch path (e.g., in `AppDependencies`). Use a fetch-or-create pattern with a single ModelContext on `@MainActor`.
**Warning signs:** Level/XP resets to zero intermittently; multiple profile records in the database.

## Code Examples

### Swift Charts Line Chart for Accuracy Trends
```swift
// Source: Apple Swift Charts documentation, appcoda.com
import Charts

struct AccuracyTrendChartView: View {
    let dataPoints: [AccuracyDataPoint]  // Pre-aggregated: (date, averageAccuracy)

    var body: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Accuracy", point.averageAccuracy)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.teal)

            PointMark(
                x: .value("Date", point.date),
                y: .value("Accuracy", point.averageAccuracy)
            )
            .foregroundStyle(Color.teal)
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 200)
    }
}
```

### Sound Effect Manager
```swift
// Source: hackingwithswift.com, advancedswift.com AVAudioPlayer patterns
import AVFoundation

@MainActor
@Observable
final class SoundManager {
    var isMuted: Bool = UserDefaults.standard.bool(forKey: "soundMuted")

    private var players: [String: AVAudioPlayer] = [:]

    func preload(_ soundName: String, ext: String = "wav") {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: ext) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[soundName] = player
        } catch {
            // Log but don't crash -- sound is optional
        }
    }

    func play(_ soundName: String) {
        guard !isMuted, let player = players[soundName] else { return }
        player.currentTime = 0
        player.play()
    }

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: "soundMuted")
    }
}
```

### Notification Manager
```swift
// Source: Apple UserNotifications docs, tanaschita.com, hackingwithswift.com
import UserNotifications

@MainActor
final class NotificationManager {
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleRoutineReminder(routine: Routine, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Quest Available!"
        content.body = "Your \(routine.displayName) quest is ready to play"
        content.sound = .default
        content.userInfo = ["routineID": routine.name]

        for weekday in routine.activeDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            let id = notificationID(routineName: routine.name, weekday: weekday)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelRoutineReminders(routineName: String, activeDays: [Int]) {
        let ids = activeDays.map { notificationID(routineName: routineName, weekday: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func notificationID(routineName: String, weekday: Int) -> String {
        "routine-\(routineName)-day\(weekday)"
    }
}
```

### PlayerProfile Model
```swift
// Source: Project architecture pattern (Phase 1 SwiftData models)
import Foundation
import SwiftData

@Model
final class PlayerProfile {
    var totalXP: Int = 0
    var currentStreak: Int = 0
    var lastPlayedDate: Date?
    var notificationsEnabled: Bool = true
    var notificationHour: Int = 7
    var notificationMinute: Int = 30
    var soundEnabled: Bool = true
    var createdAt: Date = Date.now

    init() {}
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIImpactFeedbackGenerator in UIKit bridge | `.sensoryFeedback()` SwiftUI modifier | iOS 17 (2023) | No UIKit import needed; declarative; trigger-based |
| Charts by Daniel Gindi (3rd party) | Swift Charts (first-party) | iOS 16 (2022) | Native, maintained by Apple, no dependency |
| Manual Core Data migration | SwiftData lightweight migration | iOS 17 (2023) | Adding models/properties with defaults is automatic |
| UNUserNotificationCenter sync callbacks | async/await notification APIs | iOS 15+ (2021) | Cleaner authorization flow |

**Deprecated/outdated:**
- `UILocalNotification`: Deprecated since iOS 10. Use `UNUserNotificationCenter` exclusively.
- `AudioServicesPlaySystemSound` for custom sounds: Limited, no volume control. Use AVAudioPlayer.
- CoreData `NSManagedObjectModel` migration: Not applicable; project uses SwiftData.

## Open Questions

1. **Sound asset format and source**
   - What we know: AVAudioPlayer supports .wav, .caf, .mp3, .m4a. Short sound effects (< 30s) work well as .caf or .wav for lowest latency.
   - What's unclear: Where to source age-appropriate game sound effects (chimes, level-up, streak, etc.) that are royalty-free.
   - Recommendation: Use .wav format for game SFX. Source from a royalty-free library or create programmatically. This is a content decision, not a code decision -- the planner should note it as a task with a "provide sound assets" step.

2. **XP values and level curve tuning**
   - What we know: The concave polynomial curve (baseXP * level^1.5) gives fast early levels. Exact XP per rating and curve exponent need playtesting.
   - What's unclear: Exactly how many sessions per level feels right for a 13-year-old.
   - Recommendation: Start with the values in the code example (100/60/25/10 XP per rating, 100 base, 1.5 exponent). Expose the curve constants as static properties so they can be tuned without architecture changes. Expect iteration.

3. **Notification time configuration UI**
   - What we know: NOTF-03 says player controls preferences. The routine already has `activeDays`. We need a time-of-day preference.
   - What's unclear: Should notification time be per-routine or global? Should the player or parent configure it?
   - Recommendation: Store notification time on `PlayerProfile` as a global default (simpler). The player toggles notifications on/off; the parent sets the time. This keeps the player UI simple.

4. **Personal best storage strategy**
   - What we know: PROG-06 requires "closest estimate ever for Shower: 0:08 off". TaskEstimation already stores `taskDisplayName` and `absDifferenceSeconds` (as `differenceSeconds`).
   - What's unclear: Should personal bests be pre-computed and cached, or queried on the fly?
   - Recommendation: Query on the fly using SwiftData predicates (fetch all estimations for a task name, find the one with minimum `abs(differenceSeconds)`). The dataset will be small enough (hundreds, not thousands) that this is performant. Cache only if profiling shows a problem.

5. **Chart data aggregation window**
   - What we know: PROG-05 requires viewing accuracy trends "over time." Raw per-task data could be noisy.
   - What's unclear: Daily average? Per-session average? Per-task? What time window?
   - Recommendation: Show per-session average accuracy by day. Default to last 30 days. This gives one data point per play session, which is a clean line chart.

## Sources

### Primary (HIGH confidence)
- Existing Phase 1 codebase -- all Swift files in `TimeQuest/` directory, directly read and analyzed
- Apple Swift Charts framework -- available iOS 16+, `LineMark` for time-series, verified via Apple documentation links and multiple tutorial sources
- Apple UserNotifications -- `UNCalendarNotificationTrigger` with `DateComponents` for weekly repeating, verified via Apple docs and Hacking with Swift
- Apple SwiftUI `.sensoryFeedback()` -- iOS 17+, trigger-based declarative haptics, verified via Hacking with Swift and Swift with Majid
- Apple AVFoundation `AVAudioPlayer` -- standard sound playback, verified via Hacking with Swift and Advanced Swift

### Secondary (MEDIUM confidence)
- SwiftData lightweight migration behavior (adding properties with defaults, adding new models) -- verified via Hacking with Swift tutorial and Apple Developer Forums
- Game progression curve math (concave polynomial) -- verified across multiple game design sources (davideaversa.it, gamedeveloper.com)
- Streak design patterns (graceful pause, no guilt) -- verified across yukaichou.com, UX Magazine, and Duolingo case studies

### Tertiary (LOW confidence)
- Exact XP values and level curve exponent -- design decision requiring playtesting, not verifiable from sources
- Optimal chart aggregation window (30 days) -- reasonable default but needs user feedback

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all first-party Apple frameworks, iOS 17 target confirmed, no new dependencies
- Architecture: HIGH -- follows Phase 1 patterns exactly (pure domain engines, @Observable ViewModels, SwiftData @Model)
- Pitfalls: HIGH -- SwiftData migration, notification auth, and AVAudioPlayer lifecycle are well-documented gotchas
- XP/Level tuning: LOW -- requires playtesting; research provides a starting formula only

**Research date:** 2026-02-13
**Valid until:** 2026-03-15 (stable; all frameworks are mature Apple releases)
