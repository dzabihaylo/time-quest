# Phase 4: Contextual Learning Insights - Research

**Researched:** 2026-02-13
**Domain:** Pure-Swift statistical analysis, SwiftData query patterns, SwiftUI insight card design
**Confidence:** HIGH

## Summary

Phase 4 adds a per-task insight system to TimeQuest: the player sees which specific tasks she chronically over/underestimates, whether her accuracy is improving or declining, and how consistent her estimates are. This manifests in two UI surfaces: (1) a "My Patterns" screen navigable from the home screen, showing per-task insights grouped by routine, and (2) contextual reference hints shown inline during gameplay before the estimation input for tasks with known patterns.

The technical core is an `InsightEngine` -- a pure-Swift domain engine (no SwiftData dependency) that consumes an array of `EstimationSnapshot` value types and produces per-task insight results. This follows the established Phase 1/2 pattern of pure domain engines (`TimeEstimationScorer`, `XPEngine`, `LevelCalculator`, `StreakTracker`, `PersonalBestTracker`). The `EstimationSnapshot` value type decouples the engine from SwiftData `@Model` classes, making it testable with plain Swift and reusable by Phase 6's `WeeklyReflectionEngine`. All statistical computations (bias detection, trend analysis via linear regression, consistency scoring via coefficient of variation) use standard Swift arithmetic -- no external math libraries are needed.

The architectural challenge is data flow, not math. The existing `TaskEstimation` SwiftData model already stores all required fields (`taskDisplayName`, `estimatedSeconds`, `actualSeconds`, `differenceSeconds`, `accuracyPercent`). The `GameSession` model stores `isCalibration` for filtering. The primary work is: (1) defining the `EstimationSnapshot` value type and a mapping from `TaskEstimation`, (2) building `InsightEngine` with three pure analysis functions, (3) enforcing the 5-session minimum threshold and calibration exclusion, (4) building the "My Patterns" screen with a shared `InsightCardView`, and (5) injecting contextual hints into the `EstimationInputView` gameplay flow.

**Primary recommendation:** Build `InsightEngine` as a pure struct with static functions consuming `[EstimationSnapshot]`, following the exact pattern of `TimeEstimationScorer`. Use simple linear regression slope sign for trend detection, mean signed difference for bias detection, and coefficient of variation of absolute differences for consistency. No external dependencies needed.

## Standard Stack

### Core
| Framework | Min iOS | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Swift Standard Library | -- | All statistical computations (mean, slope, CV) | Pure arithmetic; no external math library needed for this scope |
| SwiftData | 17.0 | Query TaskEstimation + GameSession for snapshot extraction | Already used throughout; query patterns established in Phase 1-3 |
| SwiftUI | 17.0 | InsightCardView, MyPatternsView, contextual hint overlay | Already the UI framework; no new dependencies |

### Supporting
| Framework | Min iOS | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Swift Charts | 16.0 | Optional mini sparkline in insight cards (accuracy trend) | Only if per-task trend visualization is desired on the card; not strictly required |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled linear regression | Accelerate framework vDSP | Overkill for 5-50 data points; Accelerate is for large vector ops. Plain Swift loop is clearer and sufficient. |
| EstimationSnapshot value type | Pass TaskEstimation @Model directly | Couples domain engine to SwiftData; breaks testability pattern; prevents reuse by Phase 6 WeeklyReflectionEngine |
| Coefficient of variation for consistency | Standard deviation alone | CV normalizes by mean, making consistency comparable across tasks with different durations. SD alone penalizes longer tasks unfairly. |

**Installation:** No new dependencies. All computation uses Swift Standard Library.

## Architecture Patterns

### Recommended Project Structure (New/Modified Files)
```
TimeQuest/
├── Domain/
│   └── InsightEngine.swift          # NEW: pure insight analysis (bias, trend, consistency)
├── Models/
│   └── EstimationSnapshot.swift     # NEW: plain Swift struct, no SwiftData
├── Features/
│   ├── Player/
│   │   ├── ViewModels/
│   │   │   └── MyPatternsViewModel.swift    # NEW: drives My Patterns screen
│   │   └── Views/
│   │       ├── MyPatternsView.swift         # NEW: per-task insights grouped by routine
│   │       ├── EstimationInputView.swift    # MODIFY: add contextual hint above estimation
│   │       └── PlayerHomeView.swift         # MODIFY: add navigation to My Patterns
│   └── Shared/
│       └── Components/
│           └── InsightCardView.swift        # NEW: shared insight display component
├── Features/
│   ├── Player/
│   │   └── ViewModels/
│   │       └── GameSessionViewModel.swift   # MODIFY: load hint data for current task
```

### Pattern 1: EstimationSnapshot Value Type (Decoupling Layer)
**What:** A plain Swift struct that extracts the minimum fields needed for insight analysis from SwiftData `TaskEstimation` + `GameSession`. This is the boundary between persistence and pure domain logic.
**When to use:** Any time a domain engine needs historical estimation data without importing SwiftData.
**Example:**
```swift
// Source: Project architecture pattern (pure domain engines)
struct EstimationSnapshot {
    let taskDisplayName: String
    let estimatedSeconds: Double
    let actualSeconds: Double
    let differenceSeconds: Double    // Signed: positive = overestimate
    let accuracyPercent: Double
    let recordedAt: Date
    let routineName: String          // For grouping in My Patterns
    let isCalibration: Bool          // For filtering
}

extension EstimationSnapshot {
    /// Create from SwiftData TaskEstimation + its parent session/routine.
    /// This is the ONLY place SwiftData touches the insight domain.
    init(from estimation: TaskEstimation) {
        self.taskDisplayName = estimation.taskDisplayName
        self.estimatedSeconds = estimation.estimatedSeconds
        self.actualSeconds = estimation.actualSeconds
        self.differenceSeconds = estimation.differenceSeconds
        self.accuracyPercent = estimation.accuracyPercent
        self.recordedAt = estimation.recordedAt
        self.routineName = estimation.session?.routine?.displayName ?? "Unknown"
        self.isCalibration = estimation.session?.isCalibration ?? false
    }
}
```

### Pattern 2: InsightEngine as Pure Domain Engine
**What:** A struct with static functions that consume `[EstimationSnapshot]` and produce typed insight results. Zero SwiftData, zero SwiftUI. Follows the exact pattern of `TimeEstimationScorer.score(estimated:actual:)`.
**When to use:** All insight computation -- bias, trend, consistency.
**Example:**
```swift
// Source: Project architecture pattern (TimeEstimationScorer, XPEngine, etc.)
struct InsightEngine {
    /// Minimum non-calibration sessions before insights are generated.
    static let minimumSessions = 5

    /// Detect chronic over/underestimation bias for a single task.
    /// Returns nil if insufficient data.
    static func detectBias(snapshots: [EstimationSnapshot]) -> BiasResult? {
        let eligible = snapshots.filter { !$0.isCalibration }
        guard eligible.count >= minimumSessions else { return nil }

        let meanDifference = eligible.map(\.differenceSeconds).reduce(0, +) / Double(eligible.count)
        // Positive mean = chronic overestimation; negative = chronic underestimation

        let direction: BiasDirection
        let threshold = 15.0  // Seconds: below this, bias is negligible
        if meanDifference > threshold {
            direction = .overestimates
        } else if meanDifference < -threshold {
            direction = .underestimates
        } else {
            direction = .balanced
        }

        return BiasResult(
            taskDisplayName: eligible[0].taskDisplayName,
            direction: direction,
            meanDifferenceSeconds: meanDifference,
            sampleCount: eligible.count
        )
    }
}
```

### Pattern 3: Linear Regression for Trend Detection
**What:** Simple linear regression on the sequence of accuracy percentages (ordered by date) to determine if accuracy is improving, declining, or stagnating. The slope sign and magnitude determine the trend.
**When to use:** REQ-013 -- per-task accuracy trend.
**Example:**
```swift
// Source: Standard statistical method (least squares linear regression)
extension InsightEngine {
    /// Detect accuracy trend over time for a single task.
    static func detectTrend(snapshots: [EstimationSnapshot]) -> TrendResult? {
        let eligible = snapshots.filter { !$0.isCalibration }
            .sorted { $0.recordedAt < $1.recordedAt }
        guard eligible.count >= minimumSessions else { return nil }

        // Simple linear regression: y = accuracy, x = index (0, 1, 2, ...)
        let n = Double(eligible.count)
        let xs = (0..<eligible.count).map { Double($0) }
        let ys = eligible.map(\.accuracyPercent)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map(*).reduce(0, +)
        let sumX2 = xs.map { $0 * $0 }.reduce(0, +)

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denominator

        // Slope interpretation thresholds
        let trend: TrendDirection
        let slopeThreshold = 0.5  // Accuracy points per session
        if slope > slopeThreshold {
            trend = .improving
        } else if slope < -slopeThreshold {
            trend = .declining
        } else {
            trend = .stable
        }

        return TrendResult(
            taskDisplayName: eligible[0].taskDisplayName,
            direction: trend,
            slopePerSession: slope,
            sampleCount: eligible.count
        )
    }
}
```

### Pattern 4: Coefficient of Variation for Consistency
**What:** Standard deviation of absolute differences divided by the mean absolute difference. Low CV = consistent estimator (even if biased). High CV = erratic estimator.
**When to use:** REQ-014 -- per-task consistency score.
**Example:**
```swift
extension InsightEngine {
    /// Compute consistency of estimates for a single task.
    static func computeConsistency(snapshots: [EstimationSnapshot]) -> ConsistencyResult? {
        let eligible = snapshots.filter { !$0.isCalibration }
        guard eligible.count >= minimumSessions else { return nil }

        let absDiffs = eligible.map { abs($0.differenceSeconds) }
        let mean = absDiffs.reduce(0, +) / Double(absDiffs.count)
        guard mean > 0 else {
            // Perfect estimates every time -- maximum consistency
            return ConsistencyResult(
                taskDisplayName: eligible[0].taskDisplayName,
                level: .veryConsistent,
                coefficientOfVariation: 0,
                sampleCount: eligible.count
            )
        }

        let variance = absDiffs.map { pow($0 - mean, 2) }.reduce(0, +) / Double(absDiffs.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean  // Coefficient of variation

        let level: ConsistencyLevel
        if cv < 0.3 { level = .veryConsistent }
        else if cv < 0.6 { level = .moderate }
        else { level = .variable }

        return ConsistencyResult(
            taskDisplayName: eligible[0].taskDisplayName,
            level: level,
            coefficientOfVariation: cv,
            sampleCount: eligible.count
        )
    }
}
```

### Pattern 5: Contextual Hint in Estimation Flow
**What:** Before the estimation picker, show a non-intrusive reference hint for tasks with known patterns. The hint shows factual reference data, not corrections.
**When to use:** REQ-019 and REQ-020 -- in-gameplay contextual hint.
**Example:**
```swift
// Source: Project architecture pattern (contextual info banners like calibrationBanner)
// In EstimationInputView, above the duration picker:
if let hint = viewModel.contextualHint {
    HStack(spacing: 6) {
        Image(systemName: "lightbulb")
            .font(.caption)
            .foregroundStyle(.orange)
        Text(hint)  // e.g. "Last 5 times: ~12 min"
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color(.systemGray6))
    .clipShape(Capsule())
}
```

### Pattern 6: Curiosity-Framed Insight Language
**What:** All insight text uses exploratory, non-judgmental language. This follows the established pattern in `FeedbackGenerator` where `.way_off` is described as "Big discovery!" not "Bad estimate."
**When to use:** REQ-017 -- all insight text rendering.
**Example phrases:**
```
Bias:
  "Interesting -- you tend to overestimate this one by about 2 minutes"
  "You've been underestimating Shower lately -- it usually takes longer than you think"
  "Your estimates for this task are well-balanced"

Trend:
  "Your estimates for Brush Teeth are getting closer over time"
  "This one's been harder to read lately -- your estimates have been drifting"
  "Steady -- your feel for this task hasn't changed much"

Consistency:
  "You read this task the same way each time -- very consistent"
  "This one's unpredictable -- your estimates vary quite a bit"
```

### Anti-Patterns to Avoid
- **Judgmental language:** NEVER use "bad", "wrong", "failed", "inaccurate" in insight text. Use curiosity framing: "Interesting", "Discovery", "Your feel for this". This is a core design principle established in FeedbackGenerator.
- **Insights from thin data:** NEVER show insights for tasks with fewer than 5 non-calibration sessions. A pattern from 3 data points is noise, not signal. The 5-session threshold is a hard requirement (REQ-015).
- **Including calibration in analysis:** NEVER include calibration sessions in pattern analysis (REQ-016). Calibration sessions are learning-the-system runs, not representative of the player's actual estimation ability.
- **Corrective hints:** NEVER tell the player what to estimate ("Try estimating 12 minutes"). Contextual hints show reference data only ("Last 5 times: ~12 min"). The player learns by noticing the pattern themselves (REQ-020).
- **Coupling InsightEngine to SwiftData:** NEVER import SwiftData in InsightEngine.swift. The engine consumes `[EstimationSnapshot]` (plain struct). The ViewModel handles the SwiftData fetch and mapping.
- **Blocking gameplay for insights:** Contextual hints must be lightweight and non-blocking. If insight data is not available (loading, insufficient history), show nothing -- never delay the estimation flow.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Trend detection | Custom moving average or exponential smoothing | Simple linear regression (slope of accuracy vs. time) | Linear regression is one formula, gives a single slope value, and handles sparse/irregular data cleanly. Moving averages require window-size tuning and lose end-of-series information. |
| Consistency measurement | Ad-hoc "how spread out are the values" logic | Coefficient of variation (stddev / mean) | CV is a single normalized number comparable across tasks with different durations. Ad-hoc approaches fragment and become hard to tune. |
| Bias detection | Manual threshold per task | Mean signed difference across sessions | Mean signed difference naturally captures chronic over/under bias. Positive mean = overestimates, negative = underestimates. One formula, not per-task config. |
| Reference hint formatting | Custom duration rounding logic | Reuse TimeFormatting.formatDuration with rounded actual-seconds average | TimeFormatting already handles "2m 30s" formatting. Just compute mean actual seconds and round. |
| Insight card UI across screens | Separate card implementations per screen | Single InsightCardView shared component | REQ-021 explicitly requires a shared component. Prevents visual drift between My Patterns and in-gameplay contexts. |

**Key insight:** The statistical computations here are trivially simple (mean, slope of a line, standard deviation). The complexity is not in the math but in the data pipeline: filtering calibration sessions, enforcing minimum thresholds, grouping by task name within routines, and presenting results with curiosity-framed language. The domain engine must be pure; the ViewModel handles the SwiftData query and mapping.

## Common Pitfalls

### Pitfall 1: Task Identity by Display Name is Fragile
**What goes wrong:** Task insights break when a parent renames a task. "Brush Teeth" becomes "Brush Your Teeth" and all historical data appears orphaned.
**Why it happens:** `TaskEstimation.taskDisplayName` is a snapshot of the display name at the time of the session. If the parent edits the task name, new estimations get the new name but old ones retain the old name.
**How to avoid:** This is an existing design decision from Phase 1 -- `taskDisplayName` is intentionally a snapshot, not a foreign key. For Phase 4, group by `taskDisplayName` as-is. If a rename happens, the old-name data and new-name data will appear as separate tasks in insights. This is acceptable because: (a) renames are rare, (b) the old insights remain valid for the old name, and (c) fixing this would require a `taskCloudID` foreign key on `TaskEstimation` which is a Phase 3-level schema change out of scope for Phase 4.
**Warning signs:** A task appearing twice in My Patterns with different names but similar patterns.

### Pitfall 2: Integer Division in Statistics
**What goes wrong:** Bias, trend, or consistency calculations produce 0 or wrong values.
**Why it happens:** Dividing `Int` count by `Int` count in Swift yields integer division. `5 / 10` is `0`, not `0.5`.
**How to avoid:** Always use `Double` for all statistical intermediate values. Cast counts with `Double(eligible.count)`. The code examples above all use `Double` throughout.
**Warning signs:** All bias values showing as exactly 0; all trends showing as stable.

### Pitfall 3: Showing Stale Insights After New Session
**What goes wrong:** Player completes a session, goes back to My Patterns, and sees pre-session insights that don't reflect the new data.
**Why it happens:** Insight computation was cached or loaded on view appear but not refreshed after gameplay.
**How to avoid:** Recompute insights in `MyPatternsViewModel.refresh()` on `.onAppear`. Since the ViewModel queries SwiftData each time, fresh data is always used. Do not cache insight results across view appearances.
**Warning signs:** Insight cards showing "5 sessions" when the player just completed their 6th.

### Pitfall 4: Contextual Hint Timing in Gameplay Flow
**What goes wrong:** The contextual hint for a task appears too late (after the player has already started thinking about their estimate) or not at all.
**Why it happens:** Hint data is loaded asynchronously and the view transitions before the data is ready.
**How to avoid:** Preload hint data for ALL tasks in the routine when the quest starts (in `GameSessionViewModel.startQuest()`). By the time the player reaches the estimation screen, data is already available. The hint computation is fast (filter + mean of 5-50 numbers) so preloading all tasks adds negligible overhead.
**Warning signs:** Hint flashes in briefly then disappears; hint shows on second visit to a task but not first.

### Pitfall 5: Threshold of 5 Sessions vs. 5 Non-Calibration Sessions
**What goes wrong:** Insights appear for a task that has 6 total sessions but only 3 non-calibration sessions. The insight is based on thin data.
**Why it happens:** Counting total sessions instead of filtering calibration sessions first.
**How to avoid:** REQ-015 says "5 non-calibration sessions." The InsightEngine must filter `isCalibration == false` BEFORE counting. The 3 calibration sessions (from CalibrationTracker.calibrationThreshold) do not count toward the minimum.
**Warning signs:** Insights appearing for a brand-new routine after only 3 play sessions (which are all calibration).

### Pitfall 6: Linear Regression With Uniform Y Values
**What goes wrong:** Division by zero or NaN in linear regression when all accuracy values are identical.
**Why it happens:** If a player gets exactly the same accuracy every time, the denominator in the slope formula can be zero (though technically it should not if x values vary).
**How to avoid:** Guard against denominator == 0 in the slope calculation. If the x values are sequential indices (0, 1, 2...), the denominator `n * sumX2 - sumX * sumX` will only be zero if n <= 1, which is already filtered by the 5-session minimum. Still, add the guard for safety.
**Warning signs:** Crash or NaN displayed in trend insight.

## Code Examples

### Complete InsightEngine Result Types
```swift
// Source: Project architecture pattern (pure value types for domain results)
enum BiasDirection: String {
    case overestimates
    case underestimates
    case balanced
}

struct BiasResult {
    let taskDisplayName: String
    let direction: BiasDirection
    let meanDifferenceSeconds: Double
    let sampleCount: Int
}

enum TrendDirection: String {
    case improving
    case declining
    case stable
}

struct TrendResult {
    let taskDisplayName: String
    let direction: TrendDirection
    let slopePerSession: Double
    let sampleCount: Int
}

enum ConsistencyLevel: String {
    case veryConsistent
    case moderate
    case variable
}

struct ConsistencyResult {
    let taskDisplayName: String
    let level: ConsistencyLevel
    let coefficientOfVariation: Double
    let sampleCount: Int
}

/// Combined per-task insight for display
struct TaskInsight {
    let taskDisplayName: String
    let routineName: String
    let bias: BiasResult?
    let trend: TrendResult?
    let consistency: ConsistencyResult?
    let recentActualSeconds: [Double]  // For contextual hint: last N actuals
}
```

### Contextual Hint Generation
```swift
// Source: REQ-019 and REQ-020
extension InsightEngine {
    /// Generate a contextual reference hint for a task, if enough data exists.
    /// Returns nil if insufficient history. Never returns a correction.
    static func contextualHint(
        taskName: String,
        snapshots: [EstimationSnapshot]
    ) -> String? {
        let eligible = snapshots
            .filter { $0.taskDisplayName == taskName && !$0.isCalibration }
            .sorted { $0.recordedAt > $1.recordedAt }  // Most recent first

        guard eligible.count >= minimumSessions else { return nil }

        let recentN = Array(eligible.prefix(5))
        let avgActual = recentN.map(\.actualSeconds).reduce(0, +) / Double(recentN.count)
        let formatted = TimeFormatting.formatDuration(avgActual)

        return "Last \(recentN.count) times: ~\(formatted)"
    }
}
```

### MyPatternsViewModel
```swift
// Source: Project architecture pattern (ProgressionViewModel)
@MainActor
@Observable
final class MyPatternsViewModel {
    var insightsByRoutine: [(routineName: String, insights: [TaskInsight])] = []

    private let sessionRepository: SessionRepositoryProtocol
    private let modelContext: ModelContext

    init(sessionRepository: SessionRepositoryProtocol, modelContext: ModelContext) {
        self.sessionRepository = sessionRepository
        self.modelContext = modelContext
    }

    func refresh() {
        // 1. Fetch all TaskEstimations
        let descriptor = FetchDescriptor<TaskEstimation>(
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        let allEstimations = (try? modelContext.fetch(descriptor)) ?? []

        // 2. Convert to snapshots
        let snapshots = allEstimations.map { EstimationSnapshot(from: $0) }

        // 3. Group by routine, then by task
        let byRoutine = Dictionary(grouping: snapshots) { $0.routineName }

        insightsByRoutine = byRoutine.map { routineName, routineSnapshots in
            let byTask = Dictionary(grouping: routineSnapshots) { $0.taskDisplayName }
            let taskInsights: [TaskInsight] = byTask.compactMap { taskName, taskSnapshots in
                // Only include tasks with enough data for at least one insight
                let eligible = taskSnapshots.filter { !$0.isCalibration }
                guard eligible.count >= InsightEngine.minimumSessions else { return nil }

                return TaskInsight(
                    taskDisplayName: taskName,
                    routineName: routineName,
                    bias: InsightEngine.detectBias(snapshots: taskSnapshots),
                    trend: InsightEngine.detectTrend(snapshots: taskSnapshots),
                    consistency: InsightEngine.computeConsistency(snapshots: taskSnapshots),
                    recentActualSeconds: eligible
                        .sorted { $0.recordedAt > $1.recordedAt }
                        .prefix(5)
                        .map(\.actualSeconds)
                )
            }
            return (routineName: routineName, insights: taskInsights)
        }
        .filter { !$0.insights.isEmpty }
        .sorted { $0.routineName < $1.routineName }
    }
}
```

### InsightCardView Shared Component
```swift
// Source: REQ-021 shared component + project UI patterns (feedbackCard in AccuracyRevealView)
struct InsightCardView: View {
    let insight: TaskInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Task name header
            Text(insight.taskDisplayName)
                .font(.headline)

            // Bias line
            if let bias = insight.bias, bias.direction != .balanced {
                insightRow(
                    icon: bias.direction == .overestimates ? "arrow.up.right" : "arrow.down.right",
                    color: bias.direction == .overestimates ? .orange : .teal,
                    text: biasText(bias)
                )
            }

            // Trend line
            if let trend = insight.trend {
                insightRow(
                    icon: trendIcon(trend.direction),
                    color: trendColor(trend.direction),
                    text: trendText(trend)
                )
            }

            // Consistency line
            if let consistency = insight.consistency {
                insightRow(
                    icon: "waveform.path",
                    color: .secondary,
                    text: consistencyText(consistency)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func biasText(_ bias: BiasResult) -> String {
        let formatted = TimeFormatting.formatDuration(abs(bias.meanDifferenceSeconds))
        switch bias.direction {
        case .overestimates:
            return "Interesting -- you tend to overestimate by ~\(formatted)"
        case .underestimates:
            return "Interesting -- you tend to underestimate by ~\(formatted)"
        case .balanced:
            return "Your estimates are well-balanced"
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Coupled domain logic to Core Data / SwiftData | Value-type snapshot pattern decoupling domain from persistence | SwiftData era (2023+) | Enables pure-Swift testing, reuse across engines (Phase 6) |
| External math libraries (e.g., SigmaSwiftStatistics) for basic stats | Swift Standard Library arithmetic | Always viable | No dependency needed for mean, slope, stddev on small datasets |
| Monolithic analytics view | Reusable card components (InsightCardView) | SwiftUI composability pattern | Shared between My Patterns screen and in-gameplay context (REQ-021) |

**Deprecated/outdated:**
- External statistics libraries for simple computations: unnecessary for the 4 operations needed (mean, sum, variance, linear regression slope)
- Batch/offline insight computation: unnecessary given small dataset size (tens to low hundreds of estimations). Real-time computation on `onAppear` is fine.

## Open Questions

1. **Slope threshold for trend classification**
   - What we know: Linear regression slope > 0 means improving, < 0 means declining. But how much slope constitutes a "meaningful" trend vs. noise?
   - What's unclear: The exact threshold where slope transitions from "stable" to "improving" or "declining." The code example uses 0.5 accuracy points per session.
   - Recommendation: Start with 0.5 accuracy-points-per-session as the threshold. Expose as a static constant in InsightEngine for tuning. This means a player whose accuracy increases by more than 0.5% per session over 5+ sessions is classified as "improving."

2. **Bias threshold in seconds**
   - What we know: Mean signed difference detects bias direction. But small biases (e.g., 5 seconds) are noise for a 10-minute task.
   - What's unclear: Should the threshold be absolute (e.g., 15 seconds) or relative (e.g., 10% of mean actual time)?
   - Recommendation: Start with an absolute 15-second threshold (matching the `spot_on` threshold in `TimeEstimationScorer`). Below 15 seconds mean difference, classify as "balanced." This keeps the logic simple and consistent with existing scoring.

3. **Consistency CV thresholds**
   - What we know: CV < 0.3 is generally considered "low variation" in statistics. CV > 1.0 is "high variation."
   - What's unclear: What CV values feel meaningful to describe a 13-year-old's estimation consistency.
   - Recommendation: Start with CV < 0.3 = "very consistent", 0.3-0.6 = "moderate", > 0.6 = "variable." These are standard statistical breakpoints. Expose as constants for tuning.

4. **My Patterns screen empty state**
   - What we know: REQ-015 requires 5 non-calibration sessions per task before insights. A new player will see an empty My Patterns screen for potentially weeks.
   - What's unclear: What should the empty state communicate?
   - Recommendation: Show a friendly message: "Keep playing! Patterns appear after 5 sessions per task." This frames the empty state as progress-toward-insight, not a missing feature. Could show a progress indicator per task ("Brush Teeth: 3/5 sessions").

5. **Insight update after task rename**
   - What we know: TaskEstimation stores `taskDisplayName` as a snapshot. A renamed task will appear as two separate entries in insights.
   - What's unclear: Whether this should be "fixed" in Phase 4 or deferred.
   - Recommendation: Defer. Accept that renamed tasks create separate insight entries. Document as a known limitation. A proper fix would require adding `taskCloudID` to `TaskEstimation` (schema change), which is out of scope.

## Sources

### Primary (HIGH confidence)
- Existing TimeQuest codebase -- all Swift files read and analyzed directly; architecture patterns, model schemas, domain engines, and view patterns are fully documented
- TaskEstimation SwiftData model -- has all fields needed for insight analysis: `taskDisplayName`, `estimatedSeconds`, `actualSeconds`, `differenceSeconds`, `accuracyPercent`, `recordedAt`
- GameSession SwiftData model -- has `isCalibration` field for filtering calibration sessions
- CalibrationTracker -- defines calibration threshold of 3 sessions, used to understand when non-calibration data begins
- FeedbackGenerator -- establishes curiosity-framed language pattern ("Interesting --", "Big discovery!") that insights must follow
- TimeEstimationScorer -- establishes pure domain engine pattern (static functions, no framework imports) that InsightEngine must follow
- PersonalBestTracker -- establishes per-task grouping-by-displayName pattern already used in the codebase

### Secondary (MEDIUM confidence)
- Linear regression for trend detection -- standard statistical method; least-squares slope formula is well-established mathematics
- Coefficient of variation for consistency -- standard statistical measure for normalized variation; appropriate for comparing tasks with different durations
- SwiftUI shared component patterns -- established in the codebase (AccuracyMeter, XPBarView, etc.) and standard SwiftUI practice

### Tertiary (LOW confidence)
- Exact threshold values (15s bias, 0.5 slope, 0.3/0.6 CV) -- reasonable starting points but require playtesting to validate against real user data
- Empty state UX for My Patterns -- design decision, not verifiable from technical sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies; pure Swift arithmetic for all computations; SwiftData queries follow established patterns
- Architecture: HIGH -- follows Phase 1/2 patterns exactly (pure domain engine, @Observable ViewModel, shared UI components, EstimationSnapshot mirrors EstimationResult pattern)
- Pitfalls: HIGH -- data flow concerns, threshold tuning, and task identity by name are well-understood from codebase analysis
- Statistical thresholds: LOW -- starting values are reasonable but need playtesting validation

**Research date:** 2026-02-13
**Valid until:** 2026-03-15 (stable; no external dependencies, all first-party frameworks)
