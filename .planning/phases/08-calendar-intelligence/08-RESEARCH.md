# Phase 8: Calendar Intelligence - Research

**Researched:** 2026-02-15
**Domain:** EventKit / Calendar-aware routine filtering / Privacy-first calendar access
**Confidence:** HIGH

## Summary

Phase 8 adds calendar awareness to TimeQuest so routines auto-surface based on whether today is a school day, holiday, or free day. The core technology is Apple's EventKit framework (`EKEventStore`), which provides read-only access to the device calendar. The critical design challenge is NOT the EventKit API (which is straightforward) but rather the **heuristic logic** for determining what constitutes a "school day" versus a "holiday/free day" given that iOS calendars have no standardized concept of "school."

The recommended approach is a **two-layer system**: (1) a parent-configurable "calendar context" where the parent selects which calendar(s) represent the school schedule and optionally configures keywords that signal "no school" days, and (2) a pure domain engine (`CalendarContextEngine`) that reads fresh calendar data, applies the heuristic, and produces a simple `DayContext` value type consumed by the existing routine filtering in `RoutineRepository.fetchActiveForToday()`. Calendar data is never persisted -- it is read each time from EventKit and used only for the immediate filtering decision.

The app already has a well-established pattern for optional permissions (see `NotificationManager.requestAuthorization()`), so the calendar permission flow should follow the same `@MainActor` async/await pattern. The existing `activeDays: [Int]` field on Routine (weekday-based filtering) continues to work as-is. Calendar intelligence adds an additional overlay: even if today is a weekday in `activeDays`, a "No School - Holiday" event in the calendar can suppress school-linked routines.

**Primary recommendation:** Build a pure `CalendarContextEngine` (no SwiftData, no persistence) that reads EventKit data, applies keyword heuristics, and returns a `DayContext` enum. Wire it into `PlayerHomeView.loadTodayQuests()` to filter routines. Add a `calendarMode` field to `Routine` (via SchemaV5) so parents can tag routines as "school-day only", "always", or "free-day only".

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| EventKit | System (iOS 17+) | Read calendar events, check authorization | Apple's only API for calendar access. No third-party alternative exists. |
| EventKitUI | System (iOS 17+) | `EKCalendarChooser` for parent calendar selection | Apple-provided UI for calendar picker; avoids hand-rolling calendar list UI |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftData | System (iOS 17+) | Store `calendarMode` on Routine model | Schema migration for new field |
| UserDefaults | System | Persist selected calendar identifier(s) | Lightweight storage for parent's calendar selection (not event data) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| EventKit direct | Third-party calendar SDK | No viable alternative exists for iOS calendar access |
| EKCalendarChooser | Custom calendar list UI | EKCalendarChooser handles edge cases (Exchange, CalDAV, subscriptions) -- use it |
| UserDefaults for calendar IDs | SwiftData/CloudKit | Calendar identifiers are device-local (different per device), so CloudKit sync is wrong; UserDefaults is correct |

**No package installation needed** -- EventKit and EventKitUI are system frameworks.

## Architecture Patterns

### Recommended Project Structure
```
TimeQuest/
├── Domain/
│   ├── CalendarContextEngine.swift     # Pure logic: events -> DayContext
│   └── DayContext.swift                # Value type: .schoolDay, .freeDay, .unknown
├── Services/
│   └── CalendarService.swift           # EventKit wrapper: permissions + event fetching
├── Features/
│   ├── Parent/
│   │   └── Views/
│   │       └── CalendarSettingsView.swift  # Parent configures calendar selection
│   └── Player/
│       └── Views/
│           └── PlayerHomeView.swift    # Modified: uses CalendarService for filtering
├── Models/
│   ├── Schemas/
│   │   └── TimeQuestSchemaV5.swift     # Adds calendarMode to Routine
│   └── Migration/
│       └── TimeQuestMigrationPlan.swift  # V4 -> V5 lightweight migration
└── App/
    └── AppDependencies.swift           # Registers CalendarService
```

### Pattern 1: Pure Domain Engine (CalendarContextEngine)
**What:** A struct with no dependencies on EventKit, SwiftData, or any framework. Takes an array of "event summaries" (value types) and returns a `DayContext`.
**When to use:** Always. This is the core intelligence that decides "is today a school day?"
**Why:** Testable without mocking EventKit. Can be unit tested with fabricated event data.
**Example:**
```swift
// Domain/DayContext.swift
enum DayContext: Sendable {
    case schoolDay          // School events present, no "no school" markers
    case freeDay(reason: String?)  // Holiday, break, summer, or no school events
    case unknown            // Calendar access denied or no data
}

// Domain/CalendarContextEngine.swift
struct CalendarEvent: Sendable {
    let title: String
    let isAllDay: Bool
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
}

struct CalendarContextEngine: Sendable {
    // Keywords that signal "no school today" in event titles
    static let noSchoolKeywords: [String] = [
        "no school", "school closed", "holiday", "break",
        "vacation", "teacher workday", "professional day",
        "snow day", "day off", "inservice", "in-service"
    ]

    func determineContext(
        events: [CalendarEvent],
        date: Date
    ) -> DayContext {
        // If no events at all, fall back to weekday heuristic
        guard !events.isEmpty else {
            let weekday = Calendar.current.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            return isWeekend ? .freeDay(reason: nil) : .unknown
        }

        // Check for "no school" markers
        let lowercasedTitles = events.map { $0.title.lowercased() }
        for title in lowercasedTitles {
            for keyword in Self.noSchoolKeywords {
                if title.contains(keyword) {
                    return .freeDay(reason: title)
                }
            }
        }

        // Events exist but none are "no school" markers -> school day
        return .schoolDay
    }
}
```

### Pattern 2: CalendarService (EventKit Wrapper)
**What:** `@MainActor` service that owns the `EKEventStore`, handles permissions, and fetches events. Converts `EKEvent` to `CalendarEvent` value types at the boundary.
**When to use:** Any time the app needs calendar data.
**Why:** Isolates EventKit (non-Sendable) to one place. Matches existing `NotificationManager` pattern.
**Example:**
```swift
// Services/CalendarService.swift
@preconcurrency import EventKit

@MainActor
final class CalendarService {
    private let eventStore = EKEventStore()

    // MARK: - Authorization

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var hasAccess: Bool {
        authorizationStatus == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    // MARK: - Fetching

    func fetchTodayEvents(
        from calendarIdentifiers: [String]? = nil
    ) -> [CalendarEvent] {
        guard hasAccess else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        // Filter to selected calendars if configured
        let calendars: [EKCalendar]?
        if let identifiers = calendarIdentifiers {
            calendars = identifiers.compactMap {
                eventStore.calendar(withIdentifier: $0)
            }
        } else {
            calendars = nil  // all calendars
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: calendars
        )
        let ekEvents = eventStore.events(matching: predicate)

        // Convert to Sendable value types at the boundary
        return ekEvents.map { event in
            CalendarEvent(
                title: event.title ?? "",
                isAllDay: event.isAllDay,
                startDate: event.startDate,
                endDate: event.endDate,
                calendarTitle: event.calendar?.title ?? ""
            )
        }
    }
}
```

### Pattern 3: Routine CalendarMode (Schema Extension)
**What:** A new field on Routine that tells the system how calendar context affects this routine's visibility.
**When to use:** All routines get a default of `.always` (backward compatible). Parent sets `.schoolDayOnly` for school routines.
**Example:**
```swift
// In SchemaV5 Routine model:
var calendarModeRaw: String = "always"
// "always" = show on activeDays regardless of calendar
// "schoolDayOnly" = show on activeDays BUT hide if calendar says "free day"
// "freeDayOnly" = show on activeDays BUT hide if calendar says "school day"
```

### Pattern 4: Graceful Denial (No Calendar = No Change)
**What:** When calendar access is denied or not requested, the app behaves exactly as it does now -- `activeDays` weekday filtering only.
**When to use:** Default state for all users.
**Why:** CAL-03 requires identical experience without calendar permission.
**Example:**
```swift
// In PlayerHomeView.loadTodayQuests() modified flow:
func loadTodayQuests() {
    let repo = SwiftDataRoutineRepository(modelContext: modelContext)
    var quests = repo.fetchActiveForToday()  // existing weekday filter

    // Calendar overlay (only if access granted)
    if dependencies.calendarService.hasAccess {
        let calendarIDs = UserDefaults.standard.stringArray(forKey: "selectedCalendarIDs")
        let events = dependencies.calendarService.fetchTodayEvents(from: calendarIDs)
        let context = CalendarContextEngine().determineContext(events: events, date: .now)

        quests = quests.filter { routine in
            switch routine.calendarModeRaw {
            case "schoolDayOnly":
                return context == .schoolDay || context == .unknown
            case "freeDayOnly":
                if case .freeDay = context { return true }
                return context == .unknown
            default: // "always"
                return true
            }
        }
    }

    todayQuests = quests
}
```

### Anti-Patterns to Avoid
- **Storing calendar events in SwiftData/CloudKit:** CAL-04 explicitly forbids this. Calendar data must be read fresh each time.
- **Caching EKCalendar objects across actor boundaries:** EKCalendar is not Sendable. Convert to value types at the EventKit boundary.
- **Prompting for calendar access on first launch:** Calendar is optional. Only prompt when user explicitly enables it in parent settings.
- **Using `requestAccess(to: .event)` (deprecated):** Use `requestFullAccessToEvents()` on iOS 17+.
- **Creating a new EKEventStore per call:** Reuse a single instance for the app's lifetime.
- **Syncing calendar identifiers via CloudKit:** Calendar identifiers are device-local. A calendar ID on iPhone does not map to the same calendar on iPad. Store in UserDefaults, not SwiftData.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Calendar picker UI | Custom list of calendars with checkboxes | `EKCalendarChooser` via UIViewControllerRepresentable | Handles all calendar account types, colors, subscription status, immutable calendars |
| Calendar permission flow | Custom alert + Settings redirect | `EKEventStore.requestFullAccessToEvents()` | System handles the permission dialog, Settings integration, and status tracking |
| Event date range queries | Manual date filtering after full fetch | `predicateForEvents(withStart:end:calendars:)` | EventKit's predicate is optimized; max span is 4 years |
| Calendar change monitoring | Polling timer | `NotificationCenter.default.publisher(for: .EKEventStoreChanged)` | System notification fires when any calendar data changes |

**Key insight:** EventKit is a mature, stable framework with well-defined APIs. The complexity is NOT in the EventKit integration -- it's in the heuristic logic for interpreting calendar events as "school day" vs "free day", which must be hand-built since no standard exists.

## Common Pitfalls

### Pitfall 1: Calendar Identifier Instability
**What goes wrong:** Storing `EKCalendar.calendarIdentifier` and expecting it to survive iCloud sign-out/sign-in or device migration.
**Why it happens:** Apple warns that "a full sync with the calendar will lose this identifier."
**How to avoid:** Store the identifier in UserDefaults (not CloudKit-synced SwiftData). Provide a fallback: if the stored identifier doesn't resolve via `eventStore.calendar(withIdentifier:)`, prompt parent to re-select. Also store the calendar title as a display fallback.
**Warning signs:** `calendar(withIdentifier:)` returns nil for a previously stored ID.

### Pitfall 2: EKEventStore Must Be Reused
**What goes wrong:** Creating a new `EKEventStore()` for each fetch. Each instance loads the full calendar database, consuming memory and time.
**Why it happens:** Treating EKEventStore like a lightweight query builder.
**How to avoid:** Create one `EKEventStore` in `CalendarService` and reuse it. Apple documentation explicitly states: "Create a single instance and reuse it."
**Warning signs:** Memory spikes on calendar fetch, slow calendar queries.

### Pitfall 3: Four-Year Maximum Predicate Span
**What goes wrong:** Creating a predicate with a time span > 4 years. EventKit silently returns incomplete results.
**Why it happens:** Not knowing about the limitation.
**How to avoid:** Only query today's events (1-day span). This phase has no need for historical calendar queries.
**Warning signs:** Missing events in query results.

### Pitfall 4: EKCalendar/EKEvent Are Not Sendable
**What goes wrong:** Passing `EKEvent` or `EKCalendar` across actor boundaries in Swift 6 strict concurrency.
**Why it happens:** EventKit predates Swift concurrency. These are Objective-C classes, not value types.
**How to avoid:** Convert to Sendable value types (`CalendarEvent` struct) immediately after fetching from EventKit. Never store EKEvent/EKCalendar in @Observable ViewModels.
**Warning signs:** Swift 6 compiler errors about non-Sendable types crossing actor boundaries.

### Pitfall 5: Forgetting the Info.plist Key
**What goes wrong:** Calling `requestFullAccessToEvents()` without `NSCalendarsFullAccessUsageDescription` in Info.plist. App crashes at runtime.
**Why it happens:** iOS 17 changed the key name from `NSCalendarsUsageDescription` (deprecated) to `NSCalendarsFullAccessUsageDescription`.
**How to avoid:** Add `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` to the build settings in `generate-xcodeproj.js`.
**Warning signs:** Runtime crash with "missing usage description" in console.

### Pitfall 6: Directive Language in Suggestions (CAL-05)
**What goes wrong:** Using proactive language like "Time for homework!" or "Start your morning routine!" based on calendar context.
**Why it happens:** Natural inclination to be "helpful."
**How to avoid:** Use passive context observations only: "Free afternoon today", "School day", "Holiday break". Never tell the player what to do.
**Warning signs:** Any suggestion text using imperative verbs ("Start", "Do", "Complete", "Time for").

### Pitfall 7: Broken App When Calendar Access Denied
**What goes wrong:** UI shows empty states, error messages, or nag screens when user denies calendar access.
**Why it happens:** Not designing the "no calendar" path as the primary path.
**How to avoid:** Design the app without calendar first (it already works this way). Calendar intelligence is a pure additive overlay. `calendarMode` defaults to "always", meaning routines show based on `activeDays` alone.
**Warning signs:** Any code path that requires `hasAccess == true` to show content.

## Code Examples

Verified patterns from official sources and community best practices:

### Requesting Calendar Access (iOS 17+)
```swift
// Source: Apple Developer Documentation - requestFullAccessToEvents()
// https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)

import EventKit

let eventStore = EKEventStore()

// Async/await pattern (iOS 17+)
do {
    let granted = try await eventStore.requestFullAccessToEvents()
    if granted {
        // Access granted - fetch events
    } else {
        // Access denied - continue without calendar features
    }
} catch {
    // Error - continue without calendar features
}
```

### Checking Authorization Status
```swift
// Source: Apple Developer Documentation - authorizationStatus(for:)
let status = EKEventStore.authorizationStatus(for: .event)
switch status {
case .fullAccess:
    // Can read and write events
case .writeOnly:
    // Can write but not read -- not useful for this phase
case .denied:
    // User explicitly denied
case .notDetermined:
    // Haven't asked yet
case .restricted:
    // Parental controls or MDM restriction
@unknown default:
    break
}
```

### Fetching Today's Events
```swift
// Source: Multiple verified sources
// https://www.createwithswift.com/fetching-events-from-the-users-calendar/
// https://nemecek.be/blog/24/ios-how-to-load-events-from-users-calendar

let calendar = Calendar.current
let startOfDay = calendar.startOfDay(for: .now)
let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

let predicate = eventStore.predicateForEvents(
    withStart: startOfDay,
    end: endOfDay,
    calendars: nil  // nil = all calendars, or pass [EKCalendar] for specific ones
)
let events = eventStore.events(matching: predicate)

for event in events {
    print("Title: \(event.title ?? "none")")
    print("All-day: \(event.isAllDay)")
    print("Calendar: \(event.calendar?.title ?? "unknown")")
}
```

### EKCalendarChooser in SwiftUI
```swift
// Source: https://nemecek.be/blog/39/how-to-use-ekcalendarchooser-with-swiftui

import SwiftUI
import EventKitUI

struct CalendarChooserView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCalendarIDs: [String]
    let eventStore: EKEventStore

    func makeUIViewController(context: Context) -> UINavigationController {
        let chooser = EKCalendarChooser(
            selectionStyle: .multiple,
            displayStyle: .allCalendars,
            entityType: .event,
            eventStore: eventStore
        )
        // Pre-select previously chosen calendars
        let existing = selectedCalendarIDs.compactMap {
            eventStore.calendar(withIdentifier: $0)
        }
        chooser.selectedCalendars = Set(existing)
        chooser.delegate = context.coordinator
        chooser.showsDoneButton = true
        chooser.showsCancelButton = true
        return UINavigationController(rootViewController: chooser)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, EKCalendarChooserDelegate {
        let parent: CalendarChooserView
        init(_ parent: CalendarChooserView) { self.parent = parent }

        func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
            parent.selectedCalendarIDs = calendarChooser.selectedCalendars
                .map(\.calendarIdentifier)
            parent.dismiss()
        }

        func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser) {
            parent.dismiss()
        }
    }
}
```

### Observing Calendar Changes
```swift
// Source: Apple Developer Documentation - EKEventStoreChanged
// https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/ekeventstorechanged

// Using Combine
import Combine

NotificationCenter.default
    .publisher(for: .EKEventStoreChanged)
    .receive(on: DispatchQueue.main)
    .sink { _ in
        // Calendar data changed externally -- re-fetch today's events
        self.refreshCalendarContext()
    }

// Using async/await
Task {
    for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
        await MainActor.run {
            self.refreshCalendarContext()
        }
    }
}
```

### Info.plist Configuration via Build Settings
```javascript
// In generate-xcodeproj.js, add to both Debug and Release build settings:
INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription = "TimeQuest uses your calendar to automatically show the right routines on school days and hide them on holidays.";
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `requestAccess(to: .event)` | `requestFullAccessToEvents()` | iOS 17 (2023) | Old API deprecated; must use new API for iOS 17+ targets |
| `NSCalendarsUsageDescription` | `NSCalendarsFullAccessUsageDescription` | iOS 17 (2023) | Old plist key no longer works; new key required |
| `.authorized` status | `.fullAccess` / `.writeOnly` status | iOS 17 (2023) | Authorization is now granular; check for `.fullAccess` specifically |
| Completion handler pattern | async/await pattern | iOS 17 (2023) | Both available; async/await is preferred for Swift 6 |

**Deprecated/outdated:**
- `requestAccess(to:completion:)` -- deprecated in iOS 17. Use `requestFullAccessToEvents()`.
- `NSCalendarsUsageDescription` Info.plist key -- replaced by `NSCalendarsFullAccessUsageDescription`.
- `.authorized` EKAuthorizationStatus case -- replaced by `.fullAccess` and `.writeOnly`.

## Open Questions

1. **Schema migration: V5 or extend V4?**
   - What we know: Phase 7 created SchemaV4. The constraint says "SchemaV4 lightweight migration only -- all new fields have defaults." Adding `calendarModeRaw: String = "always"` to Routine qualifies as a lightweight migration with a default value.
   - What's unclear: Should this be SchemaV5 (clean separation) or should we add the field to SchemaV4 (since we can still do lightweight migration with defaults)?
   - Recommendation: Create SchemaV5. Clean separation between phases is more maintainable. The migration is still lightweight (just adding a field with a default).

2. **Should the parent select specific calendars, or should the app scan all calendars?**
   - What we know: Parents often subscribe to school-specific calendars (e.g., "Lincoln Elementary Calendar"). Scanning all calendars might pick up irrelevant events.
   - What's unclear: How many parents will actually have a dedicated school calendar vs. mixing school events into their personal calendar?
   - Recommendation: Default to scanning ALL calendars (simplest). Allow parent to optionally select specific calendars in settings. This gives maximum out-of-the-box value while allowing fine-tuning.

3. **How should "passive context" messages (CAL-05) be surfaced?**
   - What we know: Success criterion #5 says passive language like "Free afternoon today." The player home screen currently shows quest cards.
   - What's unclear: Where exactly does the context message appear? Above the quest list? As a banner? As a subtle subtitle?
   - Recommendation: A small, non-interactive context chip above the quest list: "School day" with a backpack icon, or "Free day" with a sun icon. Phase 10 (UI refresh) will handle final styling.

4. **What happens on the first school day after calendar is enabled?**
   - What we know: The parent enables calendar access and selects the school calendar. If the school calendar has no events today (e.g., it only has "no school" days marked, not regular school days), the engine can't determine context.
   - What's unclear: Is the default assumption "school day" or "unknown"?
   - Recommendation: Default to `.unknown`, which means "show everything as before." The calendar only SUBTRACTS (hides school routines on free days), never ADDS requirements. This is safer and meets CAL-03.

5. **Custom keywords: should parents be able to add their own "no school" keywords?**
   - What we know: Different schools use different terminology ("PD Day", "Conference Day", "Early Release").
   - What's unclear: Is this over-engineering for the initial release?
   - Recommendation: Start with a hardcoded keyword list (the common ones). Add a parent-configurable keyword list in a future iteration if needed. The `CalendarContextEngine` is a pure function that can easily accept additional keywords later.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `requestFullAccessToEvents()` - iOS 17+ calendar access API
- Apple Developer Documentation: `EKEventStore` - Event store lifecycle and singleton pattern
- Apple Developer Documentation: TN3153 - EventKit API changes for iOS 17
- Apple Developer Documentation: `NSCalendarsFullAccessUsageDescription` - Required Info.plist key
- Apple Developer Documentation: `EKCalendarChooser` - Calendar selection UI
- Apple Developer Documentation: `EKEventStoreChanged` notification - Calendar change monitoring

### Secondary (MEDIUM confidence)
- [createwithswift.com - Getting access to the user's calendar](https://www.createwithswift.com/getting-access-to-the-users-calendar/) - iOS 17+ permission flow with async/await
- [createwithswift.com - Fetching events from the user's calendar](https://www.createwithswift.com/fetching-events-from-the-users-calendar/) - Event fetching patterns
- [nemecek.be - How to use EKCalendarChooser with SwiftUI](https://nemecek.be/blog/39/how-to-use-ekcalendarchooser-with-swiftui) - UIViewControllerRepresentable wrapper
- [nemecek.be - How to load events from user's calendar](https://nemecek.be/blog/24/ios-how-to-load-events-from-users-calendar) - Event loading, 4-year max span
- [calcopilot.app - My journey to Swift 6 and Strict Concurrency](https://calcopilot.app/blog/posts/swift-6-and-strict-concurrency/) - EKCalendar non-Sendable workarounds, @preconcurrency import
- [codersjungle.com - Swift and EventKit](https://www.codersjungle.com/2024/09/15/swift-and-eventkit/) - Comprehensive EventKit patterns

### Tertiary (LOW confidence)
- School day detection heuristic (keyword matching approach) - No existing standard or library found. This is custom logic based on common calendar naming patterns. Keyword list should be validated with real school calendars.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - EventKit is Apple's only API for calendar access, well-documented, stable since iOS 4
- Architecture: HIGH - Follows existing codebase patterns (pure engines, @MainActor services, value-type editing)
- Pitfalls: HIGH - Well-documented in Apple docs and community (non-Sendable types, deprecated APIs, plist keys)
- School day heuristic: MEDIUM - No standard exists; keyword matching is a reasonable approach but needs real-world validation
- Calendar identifier persistence: MEDIUM - Apple warns about identifier instability; UserDefaults + fallback is the pragmatic solution

**Codebase-specific findings:**
- `Routine.activeDays: [Int]` already provides weekday filtering -- calendar intelligence is an additive overlay
- `RoutineRepository.fetchActiveForToday()` is the single point where routine visibility is decided -- ideal injection point
- `AppDependencies` is the service registry -- `CalendarService` slots in alongside `NotificationManager`, `SoundManager`
- `NotificationManager` demonstrates the established pattern: `@MainActor`, async permission request, graceful denial
- `generate-xcodeproj.js` manages Info.plist keys via build settings (`INFOPLIST_KEY_*`)
- No `category` or `calendarType` field exists on Routine yet -- must be added via schema migration

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (EventKit is a stable, slow-moving framework)
