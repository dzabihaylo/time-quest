# Phase 6: Weekly Reflection Summaries - Research

**Researched:** 2026-02-14
**Domain:** Pure-Swift weekly aggregation engine, SwiftData temporal queries, SwiftUI dismissible card design, UserDefaults week-tracking
**Confidence:** HIGH

## Summary

Phase 6 adds a weekly reflection system to TimeQuest: on the first app open of a new week, the player sees a dismissible "sports score card" at the top of PlayerHomeView summarizing her past 7 days -- quests completed, average accuracy, accuracy change vs. the prior week, best estimate of the week, most improved task, streak context framed positively, and one pattern highlight from InsightEngine. The card must be absorbable in 15 seconds on a single screen with no scrolling. If dismissed or missed, the reflection is accessible from PlayerStatsView.

The technical core is a `WeeklyReflectionEngine` -- a pure-Swift domain engine (Foundation only, no SwiftData/SwiftUI imports) that consumes an array of `EstimationSnapshot` and a date range, then produces a `WeeklyReflection` value type containing all summary metrics. This follows the exact pattern established by `InsightEngine`, `TimeEstimationScorer`, `XPEngine`, and the other Phase 1-4 domain engines. The engine is purely computational; the ViewModel handles SwiftData fetching, snapshot conversion, and UserDefaults tracking for "last shown reflection week."

The architectural approach avoids a schema change. All data needed for the weekly summary already exists in the `GameSession` and `TaskEstimation` SwiftData models (completion dates, accuracy percentages, task names, session counts). Week-tracking state (which week was last shown, whether the card was dismissed) uses UserDefaults, which is the established pattern in this codebase (see `onboardingComplete` in PlayerHomeView and `activeTaskStartedAt` in GameSessionViewModel). No V4 schema migration is needed.

The key design challenge is not computation but presentation density: fitting quests completed, average accuracy, accuracy delta, best estimate, most improved task, streak context, and an insight highlight into a single non-scrolling card that a 13-year-old absorbs in 15 seconds. The "sports score card" metaphor is critical -- think ESPN game recap, not school report card.

**Primary recommendation:** Build `WeeklyReflectionEngine` as a pure struct with static functions consuming `[EstimationSnapshot]` and date ranges, producing a `WeeklyReflection` value type. Track "last shown week" via UserDefaults. Compute lazily on app open. Present as a dismissible card at the top of PlayerHomeView using the existing card styling (`.background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))`).

## Standard Stack

### Core
| Framework | Min iOS | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Swift Standard Library | -- | All weekly aggregation computations (counts, averages, deltas, sorting) | Pure arithmetic on small datasets; no external libraries needed |
| SwiftData | 17.0 | Query GameSession + TaskEstimation for weekly snapshot extraction | Established query patterns from Phases 1-4; no new query complexity |
| SwiftUI | 17.0 | WeeklyReflectionCardView, integration into PlayerHomeView + PlayerStatsView | Existing UI framework; card pattern matches InsightCardView |
| Foundation (Calendar) | -- | Week boundary computation (start-of-week, ISO week numbers) | Standard library; handles locale-aware week start (Sunday vs Monday) |
| UserDefaults | -- | Track "last reflection week shown" and "dismissed" state | Established pattern in codebase (onboardingComplete, activeTaskStartedAt) |

### Supporting
| Framework | Min iOS | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Swift Charts | 16.0 | NOT needed | The reflection card is text/icon-based, not chart-based. The 15-second absorption target rules out chart interpretation. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UserDefaults for week tracking | New `WeeklyReflection` SwiftData model | Overkill -- adds V4 schema migration for two boolean/date values. UserDefaults is simpler and sufficient since this is single-device display state, not synced data. |
| Lazy computation on app open | Background scheduler (BGTaskScheduler) | REQ-038 explicitly says no background scheduler. Lazy computation is a hard requirement. |
| Pure Foundation Calendar for week boundaries | Custom week logic | Calendar.current handles locale differences (week starts on Sunday in US, Monday in ISO 8601). Never hand-roll week boundary math. |
| Single WeeklyReflection value type | Multiple separate computed properties | A single value type is testable, cacheable, and matches the InsightEngine pattern of returning typed results. |

**Installation:** No new dependencies. All computation uses Swift Standard Library + Foundation Calendar.

## Architecture Patterns

### Recommended Project Structure (New/Modified Files)
```
TimeQuest/
+-- Domain/
|   +-- WeeklyReflectionEngine.swift     # NEW: pure weekly summary computation
+-- Models/
|   +-- WeeklyReflection.swift           # NEW: value type for weekly summary data
+-- Features/
|   +-- Player/
|   |   +-- ViewModels/
|   |   |   +-- WeeklyReflectionViewModel.swift  # NEW: drives reflection card + history
|   |   +-- Views/
|   |       +-- WeeklyReflectionCardView.swift   # NEW: dismissible card component
|   |       +-- PlayerHomeView.swift             # MODIFY: add reflection card at top
|   |       +-- PlayerStatsView.swift            # MODIFY: add "Past Reflections" section
+-- Tests/
    +-- WeeklyReflectionEngineTests.swift        # NEW: unit tests for engine
```

### Pattern 1: WeeklyReflection Value Type (Engine Output)
**What:** A plain Swift struct containing all computed weekly metrics. This is the single return type from `WeeklyReflectionEngine.computeReflection()`. It carries everything the card needs to render.
**When to use:** Always -- the engine produces this, the ViewModel stores it, the View renders it.
**Example:**
```swift
// Source: Project architecture pattern (EstimationResult, BiasResult, TrendResult, etc.)
import Foundation

struct WeeklyReflection: Sendable {
    let weekStartDate: Date           // Monday (or locale-appropriate start)
    let weekEndDate: Date             // Sunday (or locale-appropriate end)

    // REQ-034: Core metrics
    let questsCompleted: Int          // Number of completed GameSessions
    let averageAccuracy: Double       // 0-100, mean of all estimations' accuracyPercent
    let accuracyChangeVsPriorWeek: Double?  // Signed delta; nil if no prior week data

    // REQ-035: Highlights
    let bestEstimateTaskName: String? // Task with highest single accuracyPercent this week
    let bestEstimateAccuracy: Double? // That accuracy value
    let mostImprovedTaskName: String? // Task with biggest accuracy gain vs prior week
    let mostImprovedDelta: Double?    // The improvement amount

    // REQ-036: Streak context (positive framing)
    let daysPlayedThisWeek: Int       // 0-7
    let totalDaysInWeek: Int          // Always 7 (but explicit for clarity)

    // REQ-037: Insight highlight from InsightEngine
    let patternHighlight: String?     // One-liner from InsightEngine, e.g. "Your Brush Teeth estimates are getting closer over time"

    // REQ-042: Metadata
    let hasGaps: Bool                 // True if daysPlayed < 7
    let totalEstimations: Int         // How many individual task estimations this week

    /// Positively-framed streak string: "5 of 7 days" not "missed 2"
    var streakContextString: String {
        "\(daysPlayedThisWeek) of \(totalDaysInWeek) days"
    }

    /// Whether this reflection has enough data to be meaningful
    var isMeaningful: Bool {
        questsCompleted > 0
    }
}
```

### Pattern 2: WeeklyReflectionEngine as Pure Domain Engine
**What:** A struct with static functions that consume `[EstimationSnapshot]`, a target week date range, and optionally prior week snapshots. Produces a `WeeklyReflection`. Zero SwiftData, zero SwiftUI. Follows the exact pattern of `InsightEngine` and `TimeEstimationScorer`.
**When to use:** All weekly summary computation.
**Example:**
```swift
// Source: Project architecture pattern (InsightEngine.swift)
import Foundation

struct WeeklyReflectionEngine {

    /// Compute a weekly reflection from snapshots within the given date range.
    /// priorWeekSnapshots is optional -- if nil, accuracy change will be nil.
    static func computeReflection(
        snapshots: [EstimationSnapshot],
        weekStart: Date,
        weekEnd: Date,
        priorWeekSnapshots: [EstimationSnapshot]? = nil
    ) -> WeeklyReflection {
        let weekSnapshots = snapshots.filter { snap in
            !snap.isCalibration &&
            snap.recordedAt >= weekStart &&
            snap.recordedAt < weekEnd
        }

        // Quest count: unique session dates (proxy via grouping snapshots by day)
        // NOTE: Since EstimationSnapshot doesn't carry sessionID, we count
        // completed sessions at the ViewModel level and pass the count in.
        // Alternatively, we group by (routineName + date) as a session proxy.

        let questsCompleted = countCompletedQuests(weekSnapshots)
        let avgAccuracy = weekSnapshots.isEmpty ? 0 :
            weekSnapshots.map(\.accuracyPercent).reduce(0, +) / Double(weekSnapshots.count)

        // Accuracy change vs prior week
        let priorAvg: Double? = priorWeekSnapshots.flatMap { priors in
            let eligible = priors.filter { !$0.isCalibration }
            guard !eligible.isEmpty else { return nil }
            return eligible.map(\.accuracyPercent).reduce(0, +) / Double(eligible.count)
        }
        let accuracyDelta = priorAvg.map { avgAccuracy - $0 }

        // Best estimate this week
        let bestEstimate = weekSnapshots.max(by: { $0.accuracyPercent < $1.accuracyPercent })

        // Most improved task (biggest accuracy gain vs prior week)
        let mostImproved = findMostImprovedTask(
            thisWeek: weekSnapshots,
            priorWeek: priorWeekSnapshots ?? []
        )

        // Days played
        let calendar = Calendar.current
        let daysPlayed = Set(weekSnapshots.map { calendar.startOfDay(for: $0.recordedAt) }).count

        // Pattern highlight from InsightEngine
        let patternHighlight = pickPatternHighlight(from: snapshots)

        return WeeklyReflection(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            questsCompleted: questsCompleted,
            averageAccuracy: avgAccuracy,
            accuracyChangeVsPriorWeek: accuracyDelta,
            bestEstimateTaskName: bestEstimate?.taskDisplayName,
            bestEstimateAccuracy: bestEstimate?.accuracyPercent,
            mostImprovedTaskName: mostImproved?.taskName,
            mostImprovedDelta: mostImproved?.delta,
            daysPlayedThisWeek: daysPlayed,
            totalDaysInWeek: 7,
            patternHighlight: patternHighlight,
            hasGaps: daysPlayed < 7,
            totalEstimations: weekSnapshots.count
        )
    }

    // MARK: - Week Boundary Helpers

    /// Returns (weekStart, weekEnd) for the most recent completed week
    /// relative to the given date. Uses Calendar.current for locale-aware
    /// week start day.
    static func previousWeekBounds(from date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        // Start of the current week
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        // Previous week is 7 days before current week start
        let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
        return (start: prevWeekStart, end: currentWeekStart)
    }

    /// Returns (weekStart, weekEnd) for an arbitrary number of weeks back.
    static func weekBounds(weeksBack: Int, from date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        let targetStart = calendar.date(byAdding: .day, value: -7 * weeksBack, to: currentWeekStart)!
        let targetEnd = calendar.date(byAdding: .day, value: 7, to: targetStart)!
        return (start: targetStart, end: targetEnd)
    }
}
```

### Pattern 3: UserDefaults Week Tracking (No Schema Change)
**What:** Track which ISO week was last shown and whether it was dismissed, using UserDefaults keys. This avoids a V4 schema migration for display-state data.
**When to use:** REQ-038 (lazy computation on app open) and REQ-039 (dismissible card, first open of new week).
**Example:**
```swift
// Source: Established codebase pattern (onboardingComplete, activeTaskStartedAt)
enum ReflectionDefaults {
    private static let lastShownWeekKey = "reflection_lastShownWeek"
    private static let dismissedWeekKey = "reflection_dismissedWeek"

    /// ISO year-week string for the given date, e.g. "2026-W07"
    static func weekIdentifier(for date: Date) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return "\(year)-W\(String(format: "%02d", week))"
    }

    /// The week identifier of the last reflection that was shown/generated.
    static var lastShownWeek: String? {
        get { UserDefaults.standard.string(forKey: lastShownWeekKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastShownWeekKey) }
    }

    /// The week identifier of the last dismissed reflection.
    static var dismissedWeek: String? {
        get { UserDefaults.standard.string(forKey: dismissedWeekKey) }
        set { UserDefaults.standard.set(newValue, forKey: dismissedWeekKey) }
    }

    /// Whether a new reflection should be shown for the current week.
    /// True if: we're in a new week AND the reflection for last week
    /// hasn't been shown or was shown but not yet dismissed.
    static func shouldShowReflection(now: Date = .now) -> Bool {
        let previousWeekID = weekIdentifier(
            for: Calendar.current.date(byAdding: .day, value: -7, to: now)!
        )
        // Show if we haven't shown this week's reflection yet
        if lastShownWeek != previousWeekID {
            return true
        }
        // Already shown but not dismissed -- show again
        return dismissedWeek != previousWeekID
    }
}
```

### Pattern 4: Dismissible Card Integration in PlayerHomeView
**What:** A card that appears at the top of PlayerHomeView when `shouldShowReflection()` returns true. The player can dismiss it with a tap or swipe, or it stays until dismissed. After dismissal, it remains accessible from PlayerStatsView.
**When to use:** REQ-039 (dismissible card at top of home screen) and REQ-040 (accessible from stats).
**Example:**
```swift
// Source: Existing PlayerHomeView card pattern (questCard, emptyState)
// In PlayerHomeView, add above quest list:
if let reflection = reflectionVM?.currentReflection, showReflectionCard {
    WeeklyReflectionCardView(reflection: reflection) {
        // Dismiss action
        withAnimation(.easeOut(duration: 0.3)) {
            showReflectionCard = false
        }
        reflectionVM?.dismissCurrentReflection()
    }
    .transition(.move(edge: .top).combined(with: .opacity))
}
```

### Pattern 5: "Sports Score Card" Layout
**What:** A compact, scannable card that delivers all weekly metrics in a visual hierarchy designed for 15-second absorption. Uses large numbers, SF Symbols, and color coding rather than text paragraphs.
**When to use:** REQ-041 (absorbable in 15 seconds, one screen, no scrolling).
**Example layout concept:**
```swift
// Source: REQ-041 + ESPN game recap metaphor
struct WeeklyReflectionCardView: View {
    let reflection: WeeklyReflection
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header with dismiss
            HStack {
                Label("Last Week", systemImage: "calendar")
                    .font(.subheadline.bold())
                    .foregroundStyle(.teal)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // Stat row: Quests | Accuracy | Change
            HStack(spacing: 0) {
                statPill(
                    value: "\(reflection.questsCompleted)",
                    label: "Quests"
                )
                statPill(
                    value: "\(Int(reflection.averageAccuracy))%",
                    label: "Accuracy"
                )
                if let delta = reflection.accuracyChangeVsPriorWeek {
                    statPill(
                        value: "\(delta >= 0 ? "+" : "")\(Int(delta))%",
                        label: "vs Last Week",
                        valueColor: delta >= 0 ? .green : .orange
                    )
                }
            }

            // Highlights row
            HStack(spacing: 12) {
                if let bestTask = reflection.bestEstimateTaskName,
                   let bestAcc = reflection.bestEstimateAccuracy {
                    highlightChip(
                        icon: "star.fill",
                        color: .orange,
                        text: "\(bestTask) \(Int(bestAcc))%"
                    )
                }
                if let improved = reflection.mostImprovedTaskName {
                    highlightChip(
                        icon: "arrow.up.right",
                        color: .green,
                        text: "\(improved)"
                    )
                }
            }

            // Streak + pattern row
            HStack(spacing: 12) {
                Label(reflection.streakContextString, systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let highlight = reflection.patternHighlight {
                    Text(highlight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

### Pattern 6: Accessing Past Reflections from Stats
**What:** A "Past Reflections" section in PlayerStatsView that shows recent weekly reflections. This handles REQ-040 (accessible after dismissal) and REQ-042 (missed weeks computed from historical data).
**When to use:** REQ-040 and REQ-042.
**Example:**
```swift
// Source: REQ-040 + PlayerStatsView pattern
// In PlayerStatsView, add a section:
if !reflectionHistory.isEmpty {
    VStack(alignment: .leading, spacing: 12) {
        Text("Weekly Recaps")
            .font(.headline)
            .padding(.leading, 4)

        ForEach(reflectionHistory, id: \.weekStartDate) { reflection in
            MiniReflectionRow(reflection: reflection)
        }
    }
}
```

### Pattern 7: Lazy Computation on App Open (No Background Scheduler)
**What:** The WeeklyReflectionViewModel checks `shouldShowReflection()` in its `refresh()` method, which is called from PlayerHomeView's `.onAppear`. If a new week has started, it fetches the past two weeks of snapshots and computes the reflection. This is fast (tens to low hundreds of records, pure arithmetic).
**When to use:** REQ-038 (lazy, not scheduled).
**Example:**
```swift
// Source: Established pattern (ProgressionViewModel.refresh(), MyPatternsViewModel.refresh())
@MainActor
@Observable
final class WeeklyReflectionViewModel {
    var currentReflection: WeeklyReflection?
    var shouldShowCard: Bool = false
    var reflectionHistory: [WeeklyReflection] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        let now = Date.now

        // Check if we should show a new reflection
        guard ReflectionDefaults.shouldShowReflection(now: now) else {
            shouldShowCard = false
            loadHistory()
            return
        }

        // Compute reflection for the previous week
        let (weekStart, weekEnd) = WeeklyReflectionEngine.previousWeekBounds(from: now)
        let (priorStart, priorEnd) = WeeklyReflectionEngine.weekBounds(weeksBack: 2, from: now)

        // Fetch all snapshots covering both weeks
        let allSnapshots = fetchSnapshots(from: priorStart, to: weekEnd)
        let weekSnapshots = allSnapshots.filter {
            $0.recordedAt >= weekStart && $0.recordedAt < weekEnd
        }
        let priorSnapshots = allSnapshots.filter {
            $0.recordedAt >= priorStart && $0.recordedAt < priorEnd
        }

        let reflection = WeeklyReflectionEngine.computeReflection(
            snapshots: allSnapshots,  // Full history for InsightEngine pattern highlight
            weekStart: weekStart,
            weekEnd: weekEnd,
            priorWeekSnapshots: priorSnapshots.isEmpty ? nil : priorSnapshots
        )

        if reflection.isMeaningful {
            currentReflection = reflection
            shouldShowCard = true
            ReflectionDefaults.lastShownWeek = ReflectionDefaults.weekIdentifier(
                for: weekStart
            )
        }

        loadHistory()
    }

    func dismissCurrentReflection() {
        shouldShowCard = false
        if let reflection = currentReflection {
            ReflectionDefaults.dismissedWeek = ReflectionDefaults.weekIdentifier(
                for: reflection.weekStartDate
            )
        }
    }

    private func loadHistory() {
        // Compute reflections for past 4 weeks for stats view
        var history: [WeeklyReflection] = []
        let now = Date.now

        for weeksBack in 1...4 {
            let (start, end) = WeeklyReflectionEngine.weekBounds(weeksBack: weeksBack, from: now)
            let priorBounds = WeeklyReflectionEngine.weekBounds(weeksBack: weeksBack + 1, from: now)

            let allSnapshots = fetchSnapshots(from: priorBounds.start, to: end)
            let weekSnaps = allSnapshots.filter { $0.recordedAt >= start && $0.recordedAt < end }
            let priorSnaps = allSnapshots.filter {
                $0.recordedAt >= priorBounds.start && $0.recordedAt < priorBounds.end
            }

            let reflection = WeeklyReflectionEngine.computeReflection(
                snapshots: allSnapshots,
                weekStart: start,
                weekEnd: end,
                priorWeekSnapshots: priorSnaps.isEmpty ? nil : priorSnaps
            )

            if reflection.isMeaningful {
                history.append(reflection)
            }
        }

        reflectionHistory = history
    }

    private func fetchSnapshots(from start: Date, to end: Date) -> [EstimationSnapshot] {
        let descriptor = FetchDescriptor<TaskEstimation>(
            predicate: #Predicate { $0.recordedAt >= start && $0.recordedAt < end },
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        let estimations = (try? modelContext.fetch(descriptor)) ?? []
        return estimations.map { EstimationSnapshot(from: $0) }
    }
}
```

### Anti-Patterns to Avoid
- **Background schedulers for reflection computation:** REQ-038 explicitly prohibits this. Compute lazily on app open. The computation is trivially fast (< 10ms for typical data volumes).
- **Blocking gameplay for reflections:** REQ-039 says "dismissible." The player must be able to dismiss the card immediately and start playing. Never present the reflection as a modal, alert, or full-screen cover.
- **Negative streak framing:** REQ-036 says "5 of 7 days" not "missed 2 days." NEVER compute or display the negative. The `streakContextString` computed property ensures this.
- **Schema changes for display state:** UserDefaults is sufficient for "which week was shown" and "was it dismissed." Adding a `WeeklyReflection` SwiftData model would require a V4 migration for transient UI state. Avoid.
- **Over-computing history:** Don't compute reflections for all historical weeks on every app open. Limit to 4 weeks of history for the stats view. The computation is fast per week, but unbounded history adds up.
- **Scrolling in the reflection card:** REQ-041 says "one screen, no scrolling." If the card content doesn't fit, reduce content density rather than adding scrollability. The card should be a fixed-height component.
- **Coupling WeeklyReflectionEngine to SwiftData:** Follow InsightEngine's pattern exactly: pure Foundation import, static functions, `[EstimationSnapshot]` input. The ViewModel handles SwiftData queries.
- **Custom week boundary math:** Never compute week starts/ends with manual arithmetic like "subtract 7 * 86400 seconds." Use `Calendar.dateInterval(of: .weekOfYear, for:)` which handles DST transitions and locale-specific week start days correctly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Week boundary computation | Manual date arithmetic (seconds * 86400) | `Calendar.dateInterval(of: .weekOfYear, for:)` | DST transitions make 86400 * 7 wrong twice a year. Calendar handles this. Also handles locale-dependent week start (Sun vs Mon). |
| Week identification | Manual "year * 100 + weekNumber" | ISO 8601 year-week string via Calendar `.yearForWeekOfYear` + `.weekOfYear` | ISO 8601 handles year boundaries correctly (Week 1 of 2027 might start in December 2026). |
| "Most improved task" computation | Separate query per task | Filter/group in-memory from already-fetched snapshots | The dataset is small (tens to hundreds of estimations per week). In-memory grouping is clearer and faster than N separate SwiftData queries. |
| Pattern highlight selection | New analysis logic | Reuse `InsightEngine.generateInsights()` and pick the most interesting result | InsightEngine already computes bias, trend, and consistency. Pick the most notable one-liner from those results rather than duplicating analysis logic. |
| Positive streak framing | Conditional string building with edge cases | Computed property on WeeklyReflection: `"\(daysPlayed) of 7 days"` | This trivial string never needs to show negatives. The computed property ensures it. |
| Duration formatting in reflection | Custom formatting | Reuse `TimeFormatting.formatDuration()` | Already handles hours/minutes/seconds formatting throughout the app. |

**Key insight:** The reflection engine is an aggregator, not an analyzer. It groups and averages data that InsightEngine has already analyzed in depth. The novel work is: (1) temporal windowing by week, (2) cross-week comparison (accuracy delta), (3) "most improved" task detection, and (4) selecting one pattern highlight from InsightEngine's output. The math is simpler than InsightEngine -- mostly averages and deltas.

## Common Pitfalls

### Pitfall 1: Week Boundary Off-by-One with Locale
**What goes wrong:** Reflections show data from the wrong week because week start day differs by locale (Sunday in US, Monday in ISO 8601/most of Europe).
**Why it happens:** Using hardcoded "Monday is week start" or `Calendar.current.firstWeekday` inconsistently.
**How to avoid:** Always use `Calendar.current.dateInterval(of: .weekOfYear, for: date)` which returns the correct interval for the user's locale. For the ISO week identifier, use `Calendar(identifier: .iso8601)` explicitly. Test with both US and ISO calendars.
**Warning signs:** Reflections showing on Saturday instead of Monday, or data from the wrong days appearing in the summary.

### Pitfall 2: DST Transition Corrupting Week Ranges
**What goes wrong:** A week boundary computed as `startOfWeek + 7 * 86400` lands at 11pm or 1am instead of midnight because of DST spring-forward or fall-back.
**Why it happens:** Using `TimeInterval` arithmetic instead of `Calendar.date(byAdding: .day, value: 7, to:)`.
**How to avoid:** Always use Calendar date arithmetic for adding days/weeks. Never multiply by 86400.
**Warning signs:** Missing the last hour of estimations on DST transition days; duplicate day counts.

### Pitfall 3: Quest Count Overcounting from Snapshots
**What goes wrong:** Quest count shows 15 when the player completed 3 quests with 5 tasks each, because each estimation snapshot is counted as a quest.
**Why it happens:** `EstimationSnapshot` represents a single task estimation, not a session. Counting snapshots counts tasks, not quests.
**How to avoid:** Count completed quests (sessions) separately. Options: (a) pass completed session count from the ViewModel (which queries GameSession directly), or (b) in the engine, group snapshots by unique (routineName, calendar-day) pairs as a session proxy. Option (a) is cleaner -- add a `completedSessionCount: Int` parameter to the engine, or query GameSessions in the ViewModel and pass the count in.
**Warning signs:** Quest count much larger than expected for a week of play.

### Pitfall 4: Empty Week Producing Misleading Card
**What goes wrong:** A reflection card appears showing "0 quests, 0% accuracy" for a week the player didn't play at all.
**Why it happens:** `computeReflection()` runs for any week, even with zero data.
**How to avoid:** The `isMeaningful` check on `WeeklyReflection` (returns false if `questsCompleted == 0`). The ViewModel only sets `shouldShowCard = true` if the reflection is meaningful. For history view, skip weeks with no data.
**Warning signs:** Cards showing for weeks with no play.

### Pitfall 5: First Week Has No Prior Week for Comparison
**What goes wrong:** Accuracy change shows nil/0 on the player's very first weekly reflection.
**Why it happens:** No prior week data exists.
**How to avoid:** Make `accuracyChangeVsPriorWeek` optional (`Double?`). The card hides the "vs Last Week" stat pill when nil. The engine returns nil when `priorWeekSnapshots` is nil or empty.
**Warning signs:** "0%" accuracy change displayed instead of nothing, or a crash on force-unwrap.

### Pitfall 6: "Most Improved Task" Without Prior Week Data for That Task
**What goes wrong:** "Most improved" shows a task that was only played this week (no prior week data), making it technically "infinitely improved."
**Why it happens:** Computing improvement as `thisWeekAccuracy - 0` when there's no prior week data for a task.
**How to avoid:** Only compare tasks that have data in BOTH this week and the prior week. Tasks played only this week are candidates for "best estimate" but not "most improved."
**Warning signs:** New tasks always showing as "most improved."

### Pitfall 7: Pattern Highlight Showing Stale or Irrelevant Insight
**What goes wrong:** The pattern highlight references a task the player hasn't done in weeks, or shows a "balanced" insight that isn't interesting.
**Why it happens:** `InsightEngine.generateInsights()` returns all insights for all tasks historically; the reflection needs to pick the most relevant/interesting one for this week.
**How to avoid:** Filter InsightEngine insights to tasks that were actually played this week. Prefer insights with non-neutral status (improving trend, overestimate bias) over neutral ones (stable, balanced). If no interesting insight exists for this week's tasks, omit the highlight rather than showing a bland one.
**Warning signs:** Pattern highlight mentioning a task not in this week's data.

### Pitfall 8: UserDefaults Not Synced to Week Boundaries
**What goes wrong:** Reflection shows mid-week, or doesn't show at all, because the "last shown week" check uses inconsistent date formats.
**Why it happens:** Comparing formatted strings that use different calendars or formats.
**How to avoid:** Always use the same `weekIdentifier(for:)` function with ISO 8601 calendar for week identification. Test across year boundaries (December to January).
**Warning signs:** Reflection appearing on Wednesday for a Monday-start week.

## Code Examples

### Complete WeeklyReflection Value Type
```swift
// Source: Project architecture pattern (EstimationResult, BiasResult, etc.)
import Foundation

struct WeeklyReflection: Sendable {
    let weekStartDate: Date
    let weekEndDate: Date
    let questsCompleted: Int
    let averageAccuracy: Double
    let accuracyChangeVsPriorWeek: Double?
    let bestEstimateTaskName: String?
    let bestEstimateAccuracy: Double?
    let mostImprovedTaskName: String?
    let mostImprovedDelta: Double?
    let daysPlayedThisWeek: Int
    let totalDaysInWeek: Int
    let patternHighlight: String?
    let hasGaps: Bool
    let totalEstimations: Int

    var streakContextString: String {
        "\(daysPlayedThisWeek) of \(totalDaysInWeek) days"
    }

    var isMeaningful: Bool {
        questsCompleted > 0
    }

    /// Formatted accuracy change for display, e.g. "+5%" or "-3%"
    var formattedAccuracyChange: String? {
        guard let delta = accuracyChangeVsPriorWeek else { return nil }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(Int(delta))%"
    }
}
```

### Most Improved Task Finder
```swift
// Source: REQ-035
extension WeeklyReflectionEngine {
    struct ImprovementResult {
        let taskName: String
        let delta: Double  // Positive = improved
    }

    /// Find the task with the biggest accuracy improvement vs. prior week.
    /// Only considers tasks with data in both weeks.
    static func findMostImprovedTask(
        thisWeek: [EstimationSnapshot],
        priorWeek: [EstimationSnapshot]
    ) -> ImprovementResult? {
        let thisWeekByTask = Dictionary(grouping: thisWeek.filter { !$0.isCalibration }) {
            $0.taskDisplayName
        }
        let priorWeekByTask = Dictionary(grouping: priorWeek.filter { !$0.isCalibration }) {
            $0.taskDisplayName
        }

        var bestImprovement: ImprovementResult?

        for (taskName, thisWeekSnaps) in thisWeekByTask {
            guard let priorSnaps = priorWeekByTask[taskName],
                  !priorSnaps.isEmpty else { continue }

            let thisAvg = thisWeekSnaps.map(\.accuracyPercent).reduce(0, +) / Double(thisWeekSnaps.count)
            let priorAvg = priorSnaps.map(\.accuracyPercent).reduce(0, +) / Double(priorSnaps.count)
            let delta = thisAvg - priorAvg

            if delta > 0, delta > (bestImprovement?.delta ?? 0) {
                bestImprovement = ImprovementResult(taskName: taskName, delta: delta)
            }
        }

        return bestImprovement
    }
}
```

### Pattern Highlight Selection from InsightEngine
```swift
// Source: REQ-037 + InsightEngine reuse
extension WeeklyReflectionEngine {
    /// Pick the single most interesting pattern highlight for this week.
    /// Prioritizes: improving trend > notable bias > consistency.
    /// Only considers tasks played this week.
    static func pickPatternHighlight(from allSnapshots: [EstimationSnapshot]) -> String? {
        let insights = InsightEngine.generateInsights(snapshots: allSnapshots)

        // Prioritize non-neutral insights
        // 1. Improving trends (most positive/encouraging)
        if let improving = insights.first(where: { $0.trend?.direction == .improving }) {
            return "Your \(improving.taskDisplayName) estimates are getting closer over time"
        }

        // 2. Notable bias (interesting, not judgmental)
        if let biased = insights.first(where: {
            $0.bias?.direction == .overestimates || $0.bias?.direction == .underestimates
        }) {
            let direction = biased.bias!.direction == .overestimates ? "overestimate" : "underestimate"
            return "You tend to \(direction) \(biased.taskDisplayName)"
        }

        // 3. Very consistent (positive reinforcement)
        if let consistent = insights.first(where: { $0.consistency?.level == .veryConsistent }) {
            return "You read \(consistent.taskDisplayName) the same way each time"
        }

        return nil
    }
}
```

### Quest Count via GameSession Query (ViewModel Level)
```swift
// Source: SessionRepository established pattern
// In WeeklyReflectionViewModel, to get accurate quest count:
private func countCompletedSessions(from start: Date, to end: Date) -> Int {
    let allSessions = sessionRepository.fetchAllSessions()
    return allSessions.filter { session in
        guard let completedAt = session.completedAt else { return false }
        return completedAt >= start && completedAt < end && !session.isCalibration
    }.count
}
```

### Missed Week Backfill (REQ-042)
```swift
// Source: REQ-042
// In WeeklyReflectionViewModel.loadHistory():
// When computing history, iterate back through weeks and compute a reflection
// for each one. If a week has zero sessions, isMeaningful returns false and
// it's excluded from the history list. This naturally handles gaps.

// For weeks with partial data (player played 2 of 7 days), the reflection
// still computes correctly from whatever data exists. The "hasGaps" flag
// on WeeklyReflection lets the UI optionally note this.
```

### Test Helper for WeeklyReflectionEngine
```swift
// Source: InsightEngineTests pattern (makeSnapshot helper)
private func makeWeekOfSnapshots(
    daysPlayed: Int = 5,
    tasksPerDay: Int = 3,
    baseAccuracy: Double = 75,
    weekStart: Date = Date.now.addingTimeInterval(-7 * 86400),
    isCalibration: Bool = false
) -> [EstimationSnapshot] {
    let calendar = Calendar.current
    var snapshots: [EstimationSnapshot] = []

    for day in 0..<daysPlayed {
        let date = calendar.date(byAdding: .day, value: day, to: weekStart)!
        for task in 0..<tasksPerDay {
            snapshots.append(EstimationSnapshot(
                taskDisplayName: "Task \(task)",
                estimatedSeconds: 120,
                actualSeconds: 120,
                differenceSeconds: 0,
                accuracyPercent: baseAccuracy + Double(day) * 2,  // Slight improvement
                recordedAt: date,
                routineName: "Morning",
                isCalibration: isCalibration
            ))
        }
    }
    return snapshots
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Core Data batch request for weekly aggregation | SwiftData `FetchDescriptor` with `#Predicate` date filtering | 2023 (SwiftData) | Simpler query syntax; in-memory aggregation is fine for small datasets |
| Background fetch for summary computation | Lazy on-demand computation on app open | App design decision | No background entitlements needed; computation is < 10ms; REQ-038 mandates this |
| Persisted summary models (store computed results) | Compute on-the-fly from raw session/estimation data | App design decision | Avoids schema changes; raw data is always fresh; computation cost is negligible |
| ISO 8601 manual parsing for week IDs | `Calendar(identifier: .iso8601)` components | Always available | Built into Foundation; handles year-boundary edge cases automatically |

**Deprecated/outdated:**
- Storing weekly summaries as SwiftData models: unnecessary for this app's data volume. The raw data is small enough to recompute on every view.
- `BGTaskScheduler` for reflection computation: explicitly prohibited by REQ-038 and unnecessary given the trivial computation cost.

## Open Questions

1. **Quest count source: EstimationSnapshot grouping vs. GameSession query**
   - What we know: `EstimationSnapshot` doesn't carry a session ID. Counting snapshots overcounts (one per task, not per quest). `GameSession` has `completedAt` for direct counting.
   - What's unclear: Whether to add a session-level query to the ViewModel (breaking the pure-snapshot-in pattern) or add a sessionID to EstimationSnapshot.
   - Recommendation: Query `GameSession.completedAt` in the ViewModel for accurate quest count and pass it to the engine as a parameter. This keeps the engine pure (it doesn't need to count quests itself) and adds minimal ViewModel complexity. Alternatively, count unique `(routineName, calendarDay)` pairs in snapshots as a proxy -- this works if the player doesn't do the same routine twice in one day, which is the typical pattern.

2. **"Most improved" minimum data threshold**
   - What we know: A task played once this week and once last week could show huge improvement from a single data point.
   - What's unclear: Should there be a minimum number of estimations per week per task before comparing?
   - Recommendation: Require at least 2 estimations per week per task for the "most improved" comparison. This filters out single-estimation noise while being achievable for active players. If no task meets this threshold, omit "most improved" from the card.

3. **How many weeks of history to show in stats**
   - What we know: REQ-040 says reflections should be "accessible from stats/history if dismissed or missed."
   - What's unclear: How far back? 4 weeks? All time?
   - Recommendation: Show the last 4 weeks. This keeps computation bounded and covers a meaningful time span. A "see more" button could be added later if needed, but start with 4.

4. **Card animation on dismiss**
   - What we know: Card should be dismissible (REQ-039). SwiftUI supports `.transition()` for enter/exit animations.
   - What's unclear: Swipe-to-dismiss vs. X button vs. both.
   - Recommendation: Use an X button in the card header (simple, discoverable) with a `.move(edge: .top).combined(with: .opacity)` exit transition. Avoid swipe-to-dismiss as it conflicts with navigation gestures and adds complexity. The X button follows the same simplicity principle as the rest of the UI.

5. **Week start: locale Calendar vs. ISO Monday**
   - What we know: US locale starts weeks on Sunday; ISO 8601 starts on Monday. The reflection says "last week" -- what's "last week"?
   - What's unclear: Whether to use `Calendar.current` (user's locale) or force ISO 8601 Monday start.
   - Recommendation: Use `Calendar.current` for week boundaries (respects user's locale preference) but `Calendar(identifier: .iso8601)` for the week identifier string (ensures consistent storage). This means a US user's "last week" runs Sunday-Saturday, which matches their mental model.

6. **Pattern highlight: task-filtered or global?**
   - What we know: REQ-037 says "one pattern highlight from InsightEngine." InsightEngine uses all historical data.
   - What's unclear: Should the highlight be filtered to tasks played this week, or can it reference any task?
   - Recommendation: Filter to tasks played this week. A highlight about a task the player hasn't done recently feels irrelevant in a "last week" context. If no interesting insight exists for this week's tasks, omit the highlight.

## Sources

### Primary (HIGH confidence)
- **Existing TimeQuest codebase** -- all 55+ Swift files read and analyzed directly; architecture patterns, model schemas, domain engines, view patterns, repository patterns, and UserDefaults usage fully documented
- **InsightEngine.swift** -- establishes the pure domain engine pattern (static functions, `[EstimationSnapshot]` input, typed result output) that WeeklyReflectionEngine must follow exactly
- **EstimationSnapshot.swift** -- the bridge value type reused by WeeklyReflectionEngine; all needed fields (accuracyPercent, recordedAt, taskDisplayName, routineName, isCalibration) are present
- **GameSession model (SchemaV3)** -- has `completedAt` (Date?), `isCalibration` (Bool), `xpEarned` (Int), `startedAt` (Date) needed for quest counting and date filtering
- **PlayerHomeView.swift** -- the integration point for the dismissible card; uses `@State` properties, `.onAppear`, and existing card styling patterns
- **PlayerStatsView.swift** -- the integration point for historical reflections; uses ScrollView + VStack + section headers
- **ProgressionViewModel.swift** -- establishes the `@MainActor @Observable` ViewModel pattern with `refresh()` method called from `.onAppear`
- **UserDefaults usage** -- established patterns: `onboardingComplete` (PlayerHomeView), `activeTaskStartedAt` (GameSessionViewModel); proves UserDefaults is the accepted approach for transient UI state
- **Foundation Calendar API** -- `Calendar.dateInterval(of:for:)` and `Calendar.date(byAdding:value:to:)` are documented Foundation APIs for locale-aware date arithmetic

### Secondary (MEDIUM confidence)
- **SwiftData `#Predicate` date filtering** -- verified from codebase patterns; `#Predicate` supports `>=` and `<` comparisons on Date properties as seen in existing FetchDescriptor usage
- **SwiftUI transition patterns** -- `.transition(.move(edge:).combined(with:))` is standard SwiftUI; verified from AccuracyRevealView animation patterns in codebase

### Tertiary (LOW confidence)
- **"Most improved" minimum threshold of 2** -- reasonable starting point but not validated against real user data
- **4-week history depth** -- design decision, not technically validated; may need adjustment based on user feedback
- **15-second absorption target** -- the layout described should achieve this but requires visual testing with actual content

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies; pure Swift arithmetic + Foundation Calendar for all computations; SwiftData queries follow established patterns exactly
- Architecture: HIGH -- follows Phase 4 InsightEngine pattern precisely (pure domain engine, @Observable ViewModel, shared UI component, EstimationSnapshot input)
- Data flow: HIGH -- all required data fields already exist in GameSession + TaskEstimation models; no schema changes needed
- Pitfalls: HIGH -- date handling, quest counting, empty states, and cross-week comparison edge cases are well-understood from codebase analysis
- UI density (sports score card): MEDIUM -- the layout concept is sound but requires visual iteration to confirm 15-second absorption within a non-scrolling card
- Threshold values (minimum estimations for "most improved"): LOW -- needs playtesting validation

**Research date:** 2026-02-14
**Valid until:** 2026-03-15 (stable; no external dependencies, all first-party frameworks)
