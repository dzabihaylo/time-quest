# Feature Landscape: v3.0 Adaptive & Connected

**Domain:** Educational iOS game -- time perception training for teens with time blindness
**Researched:** 2026-02-14
**Confidence:** HIGH (feature design) / MEDIUM (Spotify SDK capabilities)

---

## What Already Exists (v2.0 Foundation)

Before categorizing new features, here is what v3.0 builds on:

| Existing System | Data / Capability Available | Relevant For |
|----------------|---------------------------|--------------|
| InsightEngine (bias, trend, consistency per task) | Per-task mean signed difference, linear regression slope, coefficient of variation | Adaptive difficulty -- trend/consistency feed difficulty adjustments |
| CalibrationTracker (3-session threshold per routine) | Completion count per routine | Adaptive difficulty -- calibration is the "easy mode" seed |
| TimeEstimationScorer (4-tier rating: spot_on/close/off/way_off) | AccuracyRating with percentage thresholds (10%, 25%, 50%) | Adaptive difficulty -- these thresholds are the knobs to turn |
| XPConfiguration (tunable constants) | spotOnXP, closeXP, offXP, wayOffXP, completionBonus, levelBaseXP, levelExponent | Adaptive difficulty -- XP rewards scale with difficulty |
| EstimationSnapshot (value type bridge) | taskDisplayName, estimated/actual/difference seconds, accuracy%, date, routine, isCalibration | Adaptive difficulty -- full history for any analysis |
| SoundManager (.ambient AVAudioSession) | 5 sound effects, preloaded AVAudioPlayers, mute toggle | Spotify -- must coexist with SoundManager's .ambient category |
| Routine.activeDays ([Int] weekday values 1-7) | Static day-of-week scheduling | Calendar intelligence -- replace/augment with dynamic calendar-driven activation |
| SchedulePickerView (weekday toggles + quick-select) | UI for day selection | Calendar intelligence -- augment with calendar-linked option |
| RoutineRepository.fetchActiveForToday() | Filters by today's weekday against activeDays | Calendar intelligence -- this is the function to extend |
| PlayerHomeView (quest list, XP bar, streak, reflection card) | Full home screen layout | UI refresh -- complete visual overhaul |
| AccuracyRevealScene (SpriteKit particles) | Celebration animations | UI refresh -- particle effects need visual update |
| WeeklyReflectionCardView | Summary card styling | UI refresh -- redesign with new visual language |

**Key insight:** The difficulty adjustment system has natural anchor points in the existing AccuracyRating thresholds (10%/25%/50%) and the InsightEngine's trend detection. Adaptive difficulty is not starting from scratch -- it is parameterizing what is currently hard-coded.

---

## Table Stakes

Features users expect. Missing = the v3.0 milestone feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Difficulty-aware accuracy thresholds | If game "adapts," the most visible adaptation is whether spot_on/close/off bands shift | Medium | Per-task difficulty level stored alongside task. Levels widen or narrow existing thresholds. |
| Automatic difficulty progression | Game must adjust without player choosing a setting. She should never see "Easy/Medium/Hard." | Medium | EMA of recent accuracy per task. Improve = tighten. Struggle = loosen. |
| Difficulty floor (never punishing) | 3+ consecutive off/way_off at current level triggers step down. ADHD-critical. | Medium | Frustration spiral prevention. Difficulty never drops below baseline (v2.0 thresholds). |
| Spotify account connection | One-time OAuth link to her Spotify account. No re-auth every session. | Medium | SpotifyiOS SDK handles native SSO. Keychain for token persistence. |
| Music during active task phase | Playlist plays while she does real-world tasks. Core Spotify value prop. | Medium | SPTAppRemote controls Spotify app. Pauses on task complete or app background. |
| Duration-matched playlist | Playlist length approximates total routine length. Music = audible time cue. | Medium | Greedy algorithm: fill target duration from her tracks within 30s tolerance. |
| Calendar permission request | Graceful, non-scary prompt with clear explanation. Parent grants this. | Low | EventKit requestFullAccessToEvents() on iOS 17+. |
| School day detection | Know whether today is a school day from calendar events. | Medium | Keyword matching against calendar event titles. Parent configures keywords. |
| Routine auto-surfacing | Show school morning routine on school days, skip on holidays/summer. | Medium | CalendarIntelligenceEngine determines ScheduleContext, filters routines. |
| Visual refresh of home screen | First impression must look 2026-modern. | Medium | New color palette, typography, card styling, animations. |
| Visual refresh of quest flow | Core gameplay loop needs to feel fresh. | High | Estimation input, active task, accuracy reveal, session summary. |
| Graceful degradation everywhere | Spotify not installed? Calendar denied? Everything works without them. | Low | Every new feature has a "without" path. No forced connections. |

---

## Differentiators

Features that set the product apart. Not expected, but high value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Songs as time anchors | Song transitions align with expected task transitions. She hears where she "should" be without checking a screen. | Medium | Order playlist tracks so song boundaries approximate task boundaries. |
| Post-routine song count | "You got through 4.5 songs. Last time it was 5." Songs as intuitive time unit. | Low | Track count during playback. Show in SessionSummaryView. |
| XP scaling with difficulty | Higher difficulty = more XP per accurate estimate. Rewards improvement. | Low | Multiply base XP by difficulty tier multiplier (0.8x to 1.5x). |
| Difficulty-aware reflections | Weekly card shows "3 tasks leveled up this week" as accomplishment. | Low | Count difficulty increases in reflection computation. |
| Mastery badges per task | Quiet checkmark when task reaches Level 5 and sustains. Not loud, not childish. | Low | Visible on My Patterns screen only. Subtle visual indicator. |
| Activity season detection | Auto-activate "Roller Derby Prep" during derby season from calendar events. | High | Scan 14-day calendar window for recurring event patterns. |
| Holiday awareness | No "School Morning" on Christmas. Detect all-day holiday events. | Low | Apple's calendar subscriptions include public holidays. |
| Parent schedule preview | 7-day preview in parent dashboard confirming auto-scheduling works. | Low | Simple list view showing which routines activate each day. |
| Animated breathing dot upgrade | Subtle gradient orb replacing plain circle in TaskActiveView. The brand element. | Medium | SwiftUI Canvas rendering with gentle morphing animation. |
| Dark mode as primary | Design dark mode first. She uses her phone at night and in dim rooms. | Low | Dark-first color palette with light mode fallback. |
| SF Rounded typography | .fontDesign(.rounded) for friendly-modern feel without custom font. | Low | Zero bundle size impact. Automatic Dynamic Type support. |

---

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Visible difficulty level display | Externalizes difficulty. "Level 4 -- Expert!" creates anxiety for ADHD. | Difficulty is invisible. She experiences growing precision, not a label. |
| Player-selectable difficulty | She will choose Easy to maximize XP, or feel pressured to choose Hard. | Fully automatic. The algorithm reads her data and adjusts. |
| Sudden difficulty jumps | Jump from Level 2 to Level 5 feels punishing even if data supports it. | Max 1 level change per adjustment window. Gradual always. |
| Music during estimation phase | Music distracts from the cognitive estimation task. | Play during ACTIVE task phase only (real-world task execution). |
| Spotify Premium gate | Features requiring Premium exclude free-tier users. | Design for free tier. Note Premium benefits without pressure. |
| Forced Spotify connection | "Connect Spotify to continue" blocks gameplay. | Music is always optional. Quest flow works identically without it. |
| Calendar write access | Adding events feels like parent surveillance. | Read-only. Never write to the user's calendar. |
| Auto-create playlists without consent | Creating playlists on her account without asking. | Always confirm: "Create a morning playlist?" with track preview. |
| Built-in music player | Building a music player is a product, not a feature. | Spotify only. Without Spotify, app works as v2.0. |
| Focus music curation | "We will pick the best ADHD focus beats" is patronizing. | Her music, her library, her taste. App just handles timing. |
| Full calendar display | TimeQuest is not a calendar app. | Use calendar data invisibly to filter routines. |
| AI schedule prediction | Calendar already contains the schedule. Prediction is unnecessary. | Read the actual calendar. Do not predict. |
| Customizable themes | Complex, most users never change defaults. Get the ONE default right. | One great dark-first theme. |
| Avatar system | Massive scope, not core to time perception training. | Identity = level, stats, mastery badges. Not a cartoon character. |
| Animated backgrounds | Battery drain. ADHD players need calm backgrounds. | Static dark with subtle gradient. Motion on interactions only. |
| Skeuomorphic gamification | Treasure chests, coins, gems read as "kids game." | Clean, minimal XP/level system. Restraint IS the design. |
| Spotify login on first launch | Too early. Login fatigue. She does not know the app yet. | Offer after 3+ completed routines, or discoverable in settings. |
| Time pressure challenges | Speed pressure is opposite of time blindness treatment. | Difficulty adjusts accuracy thresholds only, never time pressure. |

---

## Feature Dependencies

```
ADAPTIVE DIFFICULTY (pure domain, no external deps):
CalibrationTracker (existing) -> AdaptiveDifficultyEngine (NEW)
InsightEngine (existing)      -> AdaptiveDifficultyEngine (trend data)
TimeEstimationScorer (existing) -> Parameterized thresholds (MODIFY)
                                -> Difficulty-scaled XP (MODIFY XPEngine)

SPOTIFY (external dependency):
SpotifyiOS SDK -> SpotifyAuthService -> SpotifyMusicService
                                     -> Web API track search
                                     -> Playlist assembly
Routine duration estimate (existing data) -> RoutinePlaylistEngine (NEW)

CALENDAR (Apple framework):
EventKit -> CalendarService (NEW)
         -> CalendarIntelligenceEngine (NEW, pure domain)
         -> RoutineRepository.fetchActiveForToday() (MODIFY)

UI REFRESH (independent, touches everything):
Design system tokens -> All views
Dark-first palette -> All color references
Typography tokens -> All text styles

CROSS-PILLAR:
  UI tokens MUST be established before any view work.
  Pillars 1, 2, 3 can proceed in parallel after tokens.
```

**Critical path:** Design system tokens first, then adaptive difficulty (lowest risk, highest value), then calendar (medium risk, stable framework), then Spotify (highest risk, external dependency). UI refresh pass applies to all views after features are built.

---

## MVP Recommendation

### Must Ship

1. **Design system tokens** -- Color palette, typography, card style. Foundation for everything.
2. **Adaptive difficulty engine** -- Pure domain logic, highest value for player skill development.
3. **Calendar intelligence** -- EventKit integration, school/holiday detection, routine auto-surfacing.
4. **UI refresh of all views** -- Apply new design to home, quest flow, patterns, reflections.
5. **Spotify basic flow** -- Connect, play during quest, graceful without it.

### Defer

- **Batch estimation mode** (High complexity, unlocks only at max difficulty. v4.0.)
- **Activity season awareness** (Requires weeks of calendar data analysis. Ship day-by-day detection first.)
- **Music taste learning** (Speculative. Need data on whether music affects accuracy.)
- **Per-routine music preferences** (Nice-to-have overlay on basic Spotify. v3.1.)
- **Smart notification timing from calendar** (Complex. v3.1.)
- **Name refresh** (Branding decision, do not block engineering.)
- **Challenge mode for mastered tasks** (v4.0 stretch goal.)

### If Scope Pressure

Cut Spotify entirely. Pillars 1 (adaptive), 3 (calendar), and 4 (UI) deliver a complete v3.0. Spotify can be a standalone v3.1 release.

---

## Feature Sizing

| Feature | New Files | Modified Files | LOC Estimate | Risk |
|---------|-----------|----------------|--------------|------|
| **Adaptive Difficulty** | 3 | 5 | ~330 | LOW |
| **Spotify Integration** | 4 | 5 | ~680 | HIGH |
| **Calendar Intelligence** | 3 | 5 | ~470 | MEDIUM |
| **UI/Brand Refresh** | 7 | 13 | ~1,190 | LOW |
| **v3.0 TOTAL** | **~17** | **~28** | **~2,670** | |

Estimated codebase growth: 6,211 LOC -> ~8,880 LOC (+43%).

---

## Sources

- TimeQuest v2.0 codebase analysis (66 files, 6,211 LOC)
- PROJECT.md player context and constraints
- Existing InsightEngine, CalibrationTracker, and WeeklyReflectionEngine patterns
- Game design: adaptive difficulty for neurodivergent players (flow channel theory, invisible adjustment)
- ADHD-friendly design principles (no time pressure, graceful failure, positive framing)

---
*Feature landscape for: TimeQuest v3.0 -- Adaptive & Connected*
*Researched: 2026-02-14*
