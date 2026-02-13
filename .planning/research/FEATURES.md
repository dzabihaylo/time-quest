# Feature Landscape: v2.0 Advanced Training

**Domain:** Time-perception training game for teens with time blindness -- contextual insights, self-set routines, weekly reflections, iCloud backup
**Researched:** 2026-02-13
**Confidence:** MEDIUM -- Based on training data (cutoff May 2025) covering gamified skill-training app patterns, SwiftData/CloudKit sync capabilities, and ADHD-focused app design. No live web verification was possible. SwiftData+CloudKit specifics should be verified against current Apple documentation before implementation.

---

## What Already Exists (v1.0 Foundation)

Before categorizing new features, here is what the new features build on top of:

| Existing Feature | Data Available | Relevant For |
|-----------------|----------------|--------------|
| TaskEstimation model (taskDisplayName, estimatedSeconds, actualSeconds, differenceSeconds, accuracyPercent, rating, recordedAt) | Full per-task estimation history | Contextual insights pattern analysis |
| GameSession model (routine, startedAt, completedAt, isCalibration, xpEarned, estimations) | Session-level grouping and completion data | Weekly reflection summaries |
| PlayerProfile (totalXP, currentStreak, lastPlayedDate, preferences) | Player progression state | iCloud backup, weekly reflections |
| Routine + RoutineTask (name, displayName, activeDays, referenceDurationSeconds, ordering) | Routine structure | Self-set routines (reuse model + editor) |
| PersonalBestTracker (per-task closest estimate) | Already groups estimations by taskDisplayName | Contextual insights build on same grouping |
| ProgressionViewModel (chart data, personal bests, daily accuracy averages) | 30-day accuracy trend, per-day grouping | Weekly reflections aggregate from this |
| FeedbackGenerator (curiosity-framed messages per rating) | Per-estimation feedback | Contextual insights extend this to multi-session patterns |
| RoutineEditorViewModel + RoutineEditorView (value-type editing pattern) | Full CRUD for routines | Self-set routines reuse this editor |

**Key insight:** The v1.0 data model already stores everything needed for contextual insights and weekly reflections. No schema changes are required for analysis features -- they are pure read-side computations over existing TaskEstimation and GameSession records. Self-set routines reuse the existing Routine/RoutineTask model. Only iCloud backup requires infrastructure changes, and weekly reflections require one new model for persistence.

---

## Table Stakes

Features that are expected given v1.0 already exists and the player has been using the app for weeks. Without these, the v2.0 update feels hollow.

### Data Protection

| Feature | Why Expected | Complexity | Dependencies on v1.0 | Notes |
|---------|-------------|------------|----------------------|-------|
| **iCloud backup of progress data** | After weeks of daily play, losing XP/levels/history to a phone swap or reset is devastating. A 13-year-old who loses weeks of progress will not re-engage. | MEDIUM | All SwiftData models (PlayerProfile, GameSession, TaskEstimation, Routine, RoutineTask) | SwiftData + CloudKit via `ModelConfiguration(cloudKitDatabase: .automatic)`. Existing models mostly comply with CloudKit requirements (optional relationships, default values). Verify `Routine.activeDays` array compatibility. See STACK.md and PITFALLS.md for details. |
| **Backup status indicator** | Player should see that her data is safe. Reduces anxiety about data loss. | LOW | iCloud backup feature | Simple "Synced" / "Last backed up: [date]" in settings. Not a full sync status dashboard -- keep it simple. |

**Age-appropriate note:** A 13-year-old does not think about backup proactively. This feature is invisible until it matters (phone swap, data corruption). The value is parent peace-of-mind and disaster recovery, not daily user engagement.

### Production Polish

| Feature | Why Expected | Complexity | Dependencies on v1.0 | Notes |
|---------|-------------|------------|----------------------|-------|
| **Real sound assets** | v1.0 shipped with placeholder .wav files (all 8,864 bytes -- identical size, clearly generated). Placeholder audio feels broken, not unfinished. | LOW | SoundManager already loads and plays named sounds | Drop-in replacement of 5 .wav files. Zero code changes. Source from freesound.org (CC0 filter) or Pixabay. See STACK.md for specifications. |
| **XP curve tuning** | After weeks of play, the concave curve (baseXP * level^1.5) may feel too fast or too slow. Requires actual play data. | LOW | XPEngine, LevelCalculator | Constants change, not a feature build. Expose tunable values. Pending playtesting data. |

---

## Differentiators

Features that transform TimeQuest from a training tool into a self-awareness platform. These are what make the player feel like she is *understanding* her time sense, not just exercising it.

### Contextual Learning Insights

**What it is:** The app analyzes per-task estimation history and surfaces patterns like "You always underestimate packing by 4 minutes" or "Your shower estimates are getting more accurate every week."

| Feature | Value Proposition | Complexity | Dependencies on v1.0 | Notes |
|---------|-------------------|------------|----------------------|-------|
| **Per-task bias detection** | Tells her WHICH tasks she misjudges and in WHICH direction. More actionable than aggregate accuracy. "You underestimate packing" is something she can act on. | MEDIUM | TaskEstimation.taskDisplayName + differenceSeconds history | Pure computation: group estimations by taskDisplayName, compute mean signed difference. Positive mean = chronic overestimation, negative = chronic underestimation. Minimum 5 estimations per task before showing insight. |
| **Trend detection per task** | Shows whether her estimates for a specific task are improving, stagnating, or getting worse. | LOW | TaskEstimation history ordered by date | Compare recent 5 estimates vs previous 5 estimates. Improving = absolute difference shrinking. Simple windowed comparison. |
| **In-gameplay contextual nudge** | Before estimating a task she consistently misjudges, show a subtle hint: "Last 5 times, this actually took around 12 minutes." Not a correction -- a data point. | MEDIUM | Per-task bias detection + estimation input flow | Show DURING the estimation phase, not after. The player still makes her own estimate. This aligns with prospective timing research: reference information before estimation improves accuracy. |
| **"My Patterns" dedicated screen** | Standalone view showing all per-task insights, sortable by routine. Accessible from PlayerHomeView. | MEDIUM | All per-task analysis computations | Shows: (1) tasks ranked by chronic bias size, (2) improving vs stagnating vs regressing, (3) over/under estimation tendency per task. Visual bias bars, not dense tables. |
| **Consistency score per task** | How stable (or volatile) estimates are. High consistency + high accuracy = mastered. High consistency + low accuracy = systematic bias (actionable). Low consistency = still calibrating. | LOW | Standard deviation on existing data | PatternAnalyzer computes this alongside bias. |

**Age-appropriate note:** Insights must be framed as discoveries, not criticisms. "Interesting -- packing usually takes 4 minutes longer than you think" not "You always get packing wrong." Match the curiosity framing in FeedbackGenerator.

**Anti-feature boundary:** Do NOT show insights as pre-estimation corrections ("your estimate is probably wrong, try adding 4 minutes"). That externalizes the calibration. Show the data, let her adjust.

### Self-Set Routines

**What it is:** The player can create her own routines alongside parent-configured ones. This is the ownership transfer milestone.

| Feature | Value Proposition | Complexity | Dependencies on v1.0 | Notes |
|---------|-------------------|------------|----------------------|-------|
| **Player-created routines** | She wants to practice time estimation for things the parent did not set up. Transfers ownership from "parent's tool" to "my tool." | LOW | Routine + RoutineTask model (reuse), RoutineEditorViewModel (reuse) | Add player entry point, visual distinction (createdByPlayer flag), simplified flow. |
| **Guided creation with templates** | A blank form will be abandoned. Templates give starting points: "Getting ready for a friend's house," "Homework time," "Packing for [activity]." | LOW | New template data + modified editor flow | Pre-populates RoutineEditState. She can edit/add/remove. Templates are scaffolding; customization is ownership. |
| **Player vs parent routine distinction** | She needs to know which she created. But this must not reveal parent routines as "parent-assigned." | LOW | New boolean flag on Routine model | Subtle visual distinction: star or "Created by you" badge. Parent routines show nothing special. Never label "assigned by parent." |

### Weekly Reflection Summary

**What it is:** A brief weekly digest showing progress, patterns, and achievements from the past 7 days.

| Feature | Value Proposition | Complexity | Dependencies on v1.0 | Notes |
|---------|-------------------|------------|----------------------|-------|
| **Weekly summary card** | Creates a rhythm of meta-awareness. "This week I did 6 quests and my accuracy went up 8%." | MEDIUM | GameSession, TaskEstimation, PlayerProfile | Aggregate past 7 days. Show: quests completed, average accuracy, accuracy change, best estimate, streak. New WeeklyReflection model to persist. |
| **Pattern highlight** | Surface the most interesting per-task insight: "Biggest improvement: shower estimates got 30% closer this week." | MEDIUM | Per-task trend detection | Reuses PatternAnalyzer. Pick the single most noteworthy finding. One highlight, not a wall of data. |
| **Delivery mechanism** | Card at top of PlayerHomeView on first launch of new week. Dismissible. Accessible from stats if missed. | LOW | PlayerHomeView, PlayerProfile.lastReflectionDate | Do NOT send push notification for this. Regular quest notification brings her into the app. |
| **Streak context** | "You played 5 out of 7 days. Streak: 12 days." Frame positively. | LOW | StreakTracker | Always celebrate: "5 out of 7 days" not "you missed 2 days." |

**Age-appropriate note:** Must be SHORT. Target 15 seconds to absorb. One screen, no scrolling. Numbers and visuals, not paragraphs. "Sports score card" not "quarterly business review."

---

## Anti-Features

| Anti-Feature | Why Tempting | Why Avoid | What to Do Instead |
|--------------|-------------|-----------|-------------------|
| **AI-generated coaching messages** | Per-task data enables "Great job improving packing!" | Teens detect and despise inauthentic positivity. PROJECT.md forbids this. | Show data: "Packing: 4m12s bias (down from 6m30s)." Facts, not cheerleading. |
| **Comparison to "normal" time** | referenceDurationSeconds exists on RoutineTask | Introduces external judgment. Reveals parent's reference, breaking invisible-parent contract. | Compare only to her own history. Never surface referenceDurationSeconds. |
| **Parent insight reports** | Rich per-task data could give parents detailed analytics | Surveillance. Trust breaks if she discovers parents see "you underestimate packing by 4 minutes." | Parent sees aggregate only: "Routine X played Y times this month." |
| **Mandatory weekly reflection** | Force reading before playing | Makes app feel like school. Instant resentment. | Optional, dismissible card. Data is there when she is curious. |
| **Achievement badges system** | Common gamification pattern | Scope creep. Requires design, assets, unlock logic. XP/levels already provide progression. | Keep level system. Personal bests serve as per-task achievements. |
| **Full multi-device sync** | CloudKit enables it "for free" | A 13-year-old has one phone. Multi-device adds merge conflicts and debugging burden for a non-existent use case. | CloudKit for backup/restore only. New phone = data restores automatically. |
| **Streak multipliers** | Reward longer streaks | Creates anxiety. v1.0 streak design is "pause, never reset" to avoid guilt. Multipliers = implicit punishment for breaks. | Streaks as passive milestone. No mechanical benefit. |
| **Goal-setting in reflections** | "Try to improve packing by 10% this week" | Goals = pressure = homework feel. | Reflection is a mirror, not a coach. |
| **Home screen widget** | Show streaks on home screen | Widget extension adds target, App Group, build complexity | Defer to v3.0. |

---

## Feature Dependencies

```
EXISTING v1.0 (already built)
  |
  +--- TaskEstimation history
  |      |
  |      +---> PatternAnalyzer engine (pure computation) [BUILD FIRST]
  |      |      |
  |      |      +---> "My Patterns" screen (display)
  |      |      |
  |      |      +---> In-gameplay contextual nudge (modify estimation flow)
  |      |      |
  |      |      +---> Pattern highlight in weekly summary
  |      |
  |      +---> Weekly reflection computation (aggregate)
  |             |
  |             +---> Weekly summary card (display)
  |             +---> Streak context
  |
  +--- Routine + RoutineTask model
  |      |
  |      +---> RoutineTemplateProvider (static data)
  |             |
  |             +---> Player routine creator (reuses RoutineEditorViewModel)
  |             +---> createdByPlayer flag on Routine model
  |
  +--- All SwiftData models
         |
         +---> iCloud backup via CloudKit (ModelConfiguration change)
                |
                +---> Backup status indicator (simple UI)

INDEPENDENT (no dependencies on other v2.0 features):
  Real sound assets (asset replacement)
  XP curve tuning (constants change)
```

**Critical path:** PatternAnalyzer is the dependency root for 3 downstream features. Build it first.

**Parallel work:** iCloud backup, real sound assets, and self-set routines are independent of each other and of the insights chain.

---

## Feature Sizing

| Feature | New Files | Modified Files | LOC Estimate | Risk |
|---------|-----------|----------------|--------------|------|
| Real sound assets | 0 (asset swap) | 0 | 0 | LOW |
| PatternAnalyzer engine | 1 | 0 | ~80 | LOW |
| My Patterns view + VM | 2 | 1 (PlayerHomeView) | ~200 | LOW |
| In-gameplay insights | 0 | 2 (GameSessionVM, AccuracyRevealView) | ~40 | MEDIUM |
| Self-set routines (creator + templates) | 3 | 2 (Routine model, PlayerHomeView) | ~250 | LOW |
| Weekly reflections (model + engine + view + VM) | 4 | 2 (PlayerProfile, PlayerHomeView) | ~300 | LOW |
| iCloud backup | 0 | 3 (TimeQuestApp, project.yml, entitlements) | ~20 | HIGH |
| Backup status indicator | 0 | 1 (settings) | ~30 | LOW |
| XP curve tuning | 0 | 2 (XPEngine, LevelCalculator) | ~10 | LOW |
| **Total** | **~10** | **~13** | **~930** | -- |

~25% codebase growth (3,575 -> ~4,505 LOC). Manageable for a solo developer.

---

## MVP Recommendation

**Priority order:**

1. **Real sound assets** -- lowest effort, highest perceived polish. Do first.
2. **PatternAnalyzer engine** -- the dependency root. Unlocks 3 downstream features.
3. **My Patterns screen** -- first user-facing value from pattern engine.
4. **In-gameplay contextual insights** -- extends AccuracyRevealView with pattern data.
5. **Self-set routines with templates** -- ownership transition. Independent of insights.
6. **Weekly reflections** -- capstone feature tying patterns + sessions together.
7. **iCloud backup** -- safety net. Highest risk. Ship last after all model changes finalized.
8. **XP curve tuning** -- data-dependent. Tune after playtesting.

**If scope pressure, cut:** XP curve tuning (just expose constants) and backup status indicator (backup works silently anyway).

---

## Sources

- TimeQuest v1.0 codebase (46 files, fully analyzed)
- PROJECT.md v2.0 target features
- Training data: SwiftData + CloudKit (WWDC 2023-2024), gamified learning patterns (Duolingo, Headspace), time perception research (Zakay & Block), ADHD-friendly design (CHADD, ADDitude)
- **Confidence caveat:** SwiftData + CloudKit model constraints should be verified against current Apple documentation before implementation.
