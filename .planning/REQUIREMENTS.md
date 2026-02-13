# Requirements: TimeQuest

**Defined:** 2026-02-12
**Core Value:** The player develops an accurate internal sense of time — the ability to predict how long things take and act on those predictions without external prompting.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Foundation

- [ ] **FOUN-01**: App launches into player mode by default (game feels like hers, not parent's)
- [ ] **FOUN-02**: Parent mode accessible via hidden gesture + 4-digit PIN
- [ ] **FOUN-03**: Player UI shows zero evidence of parent setup (no "admin," "settings locked," or "parent" language)
- [ ] **FOUN-04**: All data persists locally via SwiftData (offline-first, no account required)
- [ ] **FOUN-05**: App targets iOS 17+ using SwiftUI + SpriteKit hybrid

### Parent Setup

- [ ] **PRNT-01**: Parent can create a routine with a name and player-facing display name (e.g., "School Morning" → "Morning Quest")
- [ ] **PRNT-02**: Parent can add ordered tasks to a routine with names and player-facing display names
- [ ] **PRNT-03**: Parent can set optional reference duration per task (hidden from player, used for difficulty calibration)
- [ ] **PRNT-04**: Parent can set which days of the week a routine is active
- [ ] **PRNT-05**: Parent can activate/deactivate routines
- [ ] **PRNT-06**: Parent can edit and reorder tasks within a routine
- [ ] **PRNT-07**: Parent setup takes under 5 minutes for a full routine with 5-7 tasks

### Core Gameplay

- [ ] **GAME-01**: Player selects an available routine ("quest") from active routines for today
- [ ] **GAME-02**: Player estimates how long each task will take BEFORE doing it (estimation-first, no visible clock)
- [ ] **GAME-03**: Player taps "done" when they finish each task (no visible timer during task execution)
- [ ] **GAME-04**: After each task, player sees accuracy feedback: estimated vs actual, difference, and accuracy rating
- [ ] **GAME-05**: Accuracy feedback is non-punitive and curiosity-framed (e.g., "1:12 off!" not "Wrong!")
- [ ] **GAME-06**: Large estimation gaps are framed as discoveries, not failures
- [ ] **GAME-07**: Session completes when all tasks in the routine are estimated and done
- [ ] **GAME-08**: Both overestimation and underestimation are tracked and displayed separately

### Progression

- [ ] **PROG-01**: Player earns XP based on estimation accuracy (not task completion speed)
- [ ] **PROG-02**: Player has a "Time Sense" level that increases with accumulated XP
- [ ] **PROG-03**: Player sees a daily participation streak (rewards engagement, not perfection)
- [ ] **PROG-04**: Streak pauses gracefully on skipped days (no guilt, no punishment)
- [ ] **PROG-05**: Player can view estimation accuracy trends over time (chart/graph)
- [ ] **PROG-06**: Player can see personal bests per task ("closest estimate ever for Shower: 0:08 off")
- [ ] **PROG-07**: First 3-5 sessions are framed as "calibration" to establish a baseline

### Feedback & Polish

- [ ] **FEEL-01**: Haptic feedback on key moments (submitting estimate, seeing result)
- [ ] **FEEL-02**: Sound effects for game events (optional, can be muted)
- [ ] **FEEL-03**: Celebratory animation/particle effects for accuracy milestones
- [ ] **FEEL-04**: Visual design is age-appropriate for a 13-year-old (not childish, not clinical — modern, slightly aspirational)
- [ ] **FEEL-05**: Onboarding explains the game, not the problem (no lectures about time blindness)
- [ ] **FEEL-06**: Progressive disclosure — first session teaches one routine, one estimate, one result; complexity reveals over first week

### Notifications

- [ ] **NOTF-01**: Single notification per routine when it's time to play ("Your quest awaits")
- [ ] **NOTF-02**: Notifications are game-framed, not task-framed (never sounds like a parent nagging)
- [ ] **NOTF-03**: Player controls notification preferences (can disable entirely)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Engagement Depth

- **V2-01**: Estimation difficulty curve — graduate from single tasks to task sequences to full routine estimates
- **V2-02**: Surprise accuracy bonus with special celebration when estimate is within tight margin (e.g., 30 seconds)
- **V2-03**: Unlockable visual themes and customization earned through consistent play
- **V2-04**: Quest/adventure narrative wrapper giving story meaning to daily routines

### Advanced Perception Training

- **V2-05**: Time anchoring mini-games ("Close your eyes. Open them when you think 2 minutes have passed.")
- **V2-06**: Contextual learning insights per task ("You always underestimate packing by 4 minutes")
- **V2-07**: Self-set routine creation — player creates her own routines alongside parent-configured ones
- **V2-08**: Weekly reflection summary ("This week: 6 quests, accuracy improved 8%")
- **V2-09**: Subjective time distortion awareness challenges (boring vs fun time perception)
- **V2-10**: Duration-range specific training (micro/short/medium/long categories tracked separately)

### Infrastructure

- **V2-11**: iCloud backup for key progress data (estimation history, accuracy baselines, achievements)
- **V2-12**: Parent periodic review prompt to update stale routines

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Visible countdown timer during tasks | Externalizes the clock — the opposite of building an internal one. She already ignores timers. |
| Parent monitoring dashboard | If she discovers real-time monitoring, trust is broken. Parent role is setup only. |
| Multiple/repeated notifications per routine | She already ignores nagging. One notification, then the game waits for her. |
| Punishment for inaccuracy (lost points, lives, red screens) | Time blindness is neurological, not laziness. Punishment creates avoidance. |
| Social features / leaderboards | Deeply personal skill-building tool. Social comparison shifts motivation from mastery to performance. |
| Complex RPG systems (inventory, battles, skill trees) | Scope creep. Solo developer cannot build and maintain deep RPG. Core mechanic IS estimation. |
| Screen time tracking / phone monitoring | Off-mission. This trains time perception, not phone discipline. Signals distrust. |
| AI-generated motivational messages | Teens detect and despise inauthentic positivity. Data is more respectful than cheerleading. |
| Server backend / accounts / cloud sync (v1) | YAGNI. One player, one parent, one device. Add CloudKit later if needed. |
| Android version | iOS only for v1. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUN-01 | TBD | Pending |
| FOUN-02 | TBD | Pending |
| FOUN-03 | TBD | Pending |
| FOUN-04 | TBD | Pending |
| FOUN-05 | TBD | Pending |
| PRNT-01 | TBD | Pending |
| PRNT-02 | TBD | Pending |
| PRNT-03 | TBD | Pending |
| PRNT-04 | TBD | Pending |
| PRNT-05 | TBD | Pending |
| PRNT-06 | TBD | Pending |
| PRNT-07 | TBD | Pending |
| GAME-01 | TBD | Pending |
| GAME-02 | TBD | Pending |
| GAME-03 | TBD | Pending |
| GAME-04 | TBD | Pending |
| GAME-05 | TBD | Pending |
| GAME-06 | TBD | Pending |
| GAME-07 | TBD | Pending |
| GAME-08 | TBD | Pending |
| PROG-01 | TBD | Pending |
| PROG-02 | TBD | Pending |
| PROG-03 | TBD | Pending |
| PROG-04 | TBD | Pending |
| PROG-05 | TBD | Pending |
| PROG-06 | TBD | Pending |
| PROG-07 | TBD | Pending |
| FEEL-01 | TBD | Pending |
| FEEL-02 | TBD | Pending |
| FEEL-03 | TBD | Pending |
| FEEL-04 | TBD | Pending |
| FEEL-05 | TBD | Pending |
| FEEL-06 | TBD | Pending |
| NOTF-01 | TBD | Pending |
| NOTF-02 | TBD | Pending |
| NOTF-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 36 total
- Mapped to phases: 0
- Unmapped: 36 ⚠️ (will be mapped during roadmap creation)

---
*Requirements defined: 2026-02-12*
*Last updated: 2026-02-12 after initial definition*
