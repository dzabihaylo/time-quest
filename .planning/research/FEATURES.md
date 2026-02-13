# Feature Landscape

**Domain:** Time-perception training game for teens with time blindness (iOS)
**Researched:** 2026-02-12
**Confidence Note:** External search tools were unavailable. All findings below draw from training data (cutoff May 2025) covering the competitive landscape of ADHD time-management apps, gamified habit apps, and time-perception research. Confidence is MEDIUM overall -- the app landscape and feature norms are well-established, but specific version details and any apps launched after May 2025 are not reflected. Flag for validation against current App Store listings.

---

## Competitive Landscape (Context for Feature Decisions)

Before categorizing features, it helps to understand what exists and where TimeQuest sits.

**Existing apps that touch this space:**

| App | What It Does | Why It Falls Short for TimeQuest's Goal |
|-----|-------------|----------------------------------------|
| **Brili** | Visual routine app for kids with ADHD. Step-by-step routines with timers. | Designed for younger children (4-10). Timer-centric, not perception-training. Parent-directed. |
| **Tiimo** | Visual daily planner with time blocks, designed for neurodivergent users. | Planner/scheduler, not a game. Doesn't train estimation -- just displays time. |
| **Habitica** | RPG-style gamified task manager. Complete tasks to level up a character. | Gamifies task completion, not time perception. No estimation mechanic. Social-heavy. |
| **Forest** | Focus timer -- plant a virtual tree, it dies if you leave the app. | Focus/distraction tool, not time perception. Passive timer, no estimation training. |
| **Time Timer** | Visual countdown timer showing time remaining as a shrinking red disc. | Externalized time display. Doesn't build internal perception. She already ignores timers. |
| **Routinery** | Step-by-step routine timer for adults. | Adult-oriented, timer-based, no game layer, no estimation training. |
| **Alarmy** | Alarm that requires puzzles/actions to dismiss. | Wake-up only. Punitive, not training-oriented. |

**The gap TimeQuest fills:** No existing app trains time *estimation* as a game mechanic. Every competitor either (a) displays time externally (timers/planners) or (b) gamifies task completion without touching perception. TimeQuest is fundamentally different: it treats time perception as a trainable skill and wraps calibration exercises in game mechanics.

---

## Table Stakes

Features users expect. Missing = the app feels broken, confusing, or immediately abandoned. For a teen audience, "users" means both the player (13yo) and the setup parent.

### Core Game Loop

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Time estimation challenge** | THE core mechanic. Player guesses how long a task will take, does the task, sees accuracy. Without this, there is no product. | High | This is the entire value proposition. Must feel like a game challenge, not a quiz. Needs careful UX to feel fun rather than judgmental. |
| **Accuracy feedback (non-punitive)** | Player needs to see how close their estimate was. Without feedback, no learning loop. | Medium | Critical: feedback must be curiosity-inducing ("Whoa, 3 minutes off!") not shame-inducing ("Wrong!"). Show a spectrum, not pass/fail. |
| **Streak / consistency tracking** | Every habit app and game has this. Teens expect it. Missing = feels incomplete. | Low | Daily streak for playing, not for being accurate. Reward participation, not perfection. Streaks create return behavior. |
| **Progress visualization** | Player needs to see improvement over time. "Am I getting better?" is the core motivation question. | Medium | Show estimation accuracy trending over days/weeks. Graph or visual metaphor. This is what makes weeks of play feel worthwhile. |
| **Multiple routines** | School mornings are 5x/week, but activities add 2-3 more. App must handle varied routines. | Medium | Each routine is a set of tasks with different time profiles. "Get ready for school" vs "pack for roller derby." |
| **Task breakdown within routines** | A routine is multiple steps (brush teeth, get dressed, eat breakfast, pack bag). Must support granular estimation. | Medium | Parent configures the tasks. Player estimates each one. Granularity is where estimation training happens. |

### Player Experience

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Age-appropriate visual design** | A 13-year-old will reject anything that looks like it is for little kids or like a medical tool. | Medium | Not cartoon-y (too young), not clinical (too boring), not overly gendered. Clean, modern, slightly aspirational. Think Duolingo-level polish. |
| **Onboarding that explains the game, not the problem** | She should understand how to play, not receive a lecture about time blindness. | Medium | "Here's how the game works" not "You have trouble with time and this will help." Frame as skill, not deficit. |
| **Haptic/sound feedback on interactions** | iOS games have tactile feedback. Missing = feels cheap. | Low | Subtle haptics on key moments (submitting estimate, seeing result). Sound effects optional but polishing. |
| **Notification for routine start** | She needs to know when to start. Without notification, app sits unused. | Low | Single notification: "Your morning quest is ready." Not nagging. One prompt, player decides to engage. |
| **Offline functionality** | Morning routines happen with or without wifi. Must work offline. | Low | Core game loop should be fully offline. Sync when connection available. |

### Parent Setup

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Parent setup mode (separate from player mode)** | Parent needs to configure routines without player seeing setup scaffolding. | Medium | PIN or separate entry point. Parent creates routines, sets task names, sets schedule. Player sees the game layer. |
| **Routine configuration (tasks, order, schedule)** | Parent must be able to define what tasks exist and when they happen. | Medium | Task name, optional time hint (parent's estimate of how long it "should" take for reference), day-of-week schedule. |
| **Simple, fast parent UX** | Parent does setup once and tweaks occasionally. Must not be burdensome. | Low | If parent setup is annoying, routines never get configured. Keep it under 5 minutes for initial setup. |

---

## Differentiators

Features that create competitive advantage. Not expected by users walking in, but create delight, engagement, or outcomes that competitors cannot match.

### Core Differentiators (What Makes TimeQuest Unique)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Estimation calibration mechanic** | No competitor trains estimation. This IS the product. Player predicts duration, lives through the task, sees the gap. Over time, the gap shrinks. | High | The accuracy-over-time curve IS the training. Research on time perception (Zakay & Block, prospective timing paradigm) shows that repeated estimation-with-feedback genuinely improves duration judgment. |
| **Real-task anchoring** | Estimates are for actual tasks she is about to do (brush teeth, pack bag), not abstract exercises. Training transfers because it IS the real context. | Medium | Most "brain training" apps fail on transfer. TimeQuest avoids this by training in-situ. The game IS the morning routine. |
| **Invisible parent role** | Parent sets up, player owns. She never feels managed. No "your parent assigned this." The game just has quests that happen to be her routines. | Medium | Enormous psychological differentiator. Preserves autonomy and intrinsic motivation. Most competitor apps make parental control visible, which triggers resistance in teens. |
| **Estimation history with personal bests** | "You used to think brushing teeth took 1 minute. Your average is actually 3:20. Last week you guessed 3:00 -- closest ever!" | Medium | Makes the calibration journey visible and personal. Combines data tracking with achievement psychology. |

### Engagement Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Quest/adventure narrative wrapper** | Routines are "quests." Completing morning routine = completing a quest. Builds a story layer over daily repetition. | Medium | Narrative gives meaning to repetition. Even a thin narrative ("You're a time traveler calibrating your chrono-sense") makes daily play feel purposeful rather than rote. |
| **Estimation difficulty curve** | Early: estimate one task at a time. Later: estimate a sequence. Advanced: estimate total routine time. Builds complexity as skill grows. | Medium | Prevents boredom. Creates natural progression. Mirrors how time perception actually develops (item-level before aggregate-level). |
| **"Time sense" score or level** | A single number/level representing overall estimation accuracy. Levels up as she improves. | Low | Gives a persistent sense of progression. "I'm Level 12 in Time Sense." Tangible identity marker. |
| **Surprise accuracy bonus** | When an estimate is within a tight margin (e.g., within 30 seconds), special celebration/reward. | Low | Creates positive surprise moments. Reinforces that accuracy is the valued skill, not speed. |
| **Unlockable themes/customization** | Earn new visual themes, colors, or avatar elements through consistent play. | Medium | Standard gamification, but important for teen retention. Customization = ownership = identity = stickiness. |

### Advanced Differentiators (Later Phases)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Time anchoring exercises** | Short standalone mini-games for calibrating sense of specific durations. "Close your eyes. Open them when you think 2 minutes have passed." | Medium | Supplementary training separate from routines. Builds raw duration sense. Can be played anytime. Research-backed (prospective timing tasks). |
| **Contextual learning** | App learns that she always underestimates "packing bag" and overestimates "getting dressed." Provides per-task calibration insights. | Medium | Personalized feedback is more actionable than aggregate feedback. "You're great at estimating shower time but consistently underestimate packing by 4 minutes." |
| **Self-set routine creation** | Player can create her own routines (not just parent-configured ones). | Low | Transfers ownership further. She might create "getting ready for a friend's house" routine on her own. Signals the tool is working -- she's internalizing the skill. |
| **Weekly reflection prompt** | Brief weekly summary: "This week you completed 6 quests. Your estimation accuracy improved 8%. Your best estimate: breakfast at 0:12 off." | Low | Creates a rhythm of reflection. Low effort, high insight. |

---

## Anti-Features

Features to explicitly NOT build. Each one is tempting but would undermine TimeQuest's core design or psychological model.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Visible timer counting down during tasks** | She already ignores timers. A visible countdown externalizes time awareness instead of building internal perception. It also creates anxiety. | Let her do the task without seeing a clock. App tracks elapsed time silently. The reveal of actual-vs-estimated is the learning moment. |
| **Parent monitoring dashboard** | If she discovers parent can see her data in real-time, trust is broken. The "my game" illusion dies. She'll resist. | Parent sees only high-level setup. If parent needs to know progress, consider an optional periodic summary, never real-time monitoring. |
| **Nagging/repeated reminders** | She already ignores reminders and they create conflict. Multiple notifications = another nagging system. | One notification per routine. If she doesn't engage, no follow-up. The game is available when she's ready. Natural consequences teach what nagging cannot. |
| **Punishment for inaccuracy** | Losing points, lives, or progress for bad estimates creates anxiety and avoidance. Time blindness is neurological, not laziness. | Reward participation and improvement trajectory. Bad estimates are data, not failures. "Interesting -- 5 minutes off! Let's see if you get closer tomorrow." |
| **Social features / leaderboards** | This is a deeply personal skill-building tool for a specific person. Social comparison adds pressure and shifts motivation from mastery to performance. Project scope also cannot support social infrastructure. | Keep it single-player. Her competition is her past self. |
| **Complex RPG systems (inventory, battles, skill trees)** | Scope creep. A solo developer cannot build and maintain a deep RPG. Complexity also distracts from the core estimation mechanic. | Keep gamification light: levels, streaks, unlockables, narrative. The game IS the estimation challenge, not a separate game with estimation bolted on. |
| **Rigid scheduling / "you missed your window" penalties** | Real life is messy. Some mornings are different. Penalizing missed routines creates resentment. | Routines are available on scheduled days but flexible. If she starts late, the quest is still there. If she skips a day, streak pauses gracefully. |
| **AI-generated motivational messages** | Teens detect and despise inauthentic positivity. "You're doing amazing sweetie!" from an app is cringe. | Keep feedback factual and game-flavored. "3:12 actual vs 2:00 estimated. 1:12 off. Your average gap this week: 0:45." Data is more respectful than cheerleading. |
| **Screen time tracking / phone usage monitoring** | Completely off-mission. This is a time perception trainer, not a parental control tool. Bundling these signals "I don't trust you with your phone." | Stay focused on time estimation training. Nothing else. |
| **Extensive onboarding / tutorials** | A 13-year-old will skip any tutorial longer than 30 seconds. Long onboarding signals "this is complicated" and kills first-session engagement. | Progressive disclosure. Show one thing at a time. First session: one routine, one estimate, one result. Everything else reveals itself over the first week. |

---

## Feature Dependencies

```
Parent Setup Mode
  |
  v
Routine Configuration (tasks, order, schedule)
  |
  v
Notification for Routine Start
  |
  v
Time Estimation Challenge  <-- Core loop starts here
  |
  v
Accuracy Feedback (non-punitive)
  |
  +---> Streak / Consistency Tracking
  |
  +---> Progress Visualization
  |       |
  |       v
  |     Estimation History with Personal Bests
  |       |
  |       v
  |     Contextual Learning (per-task insights)
  |
  +---> "Time Sense" Score / Level
  |       |
  |       v
  |     Unlockable Themes / Customization
  |
  +---> Surprise Accuracy Bonus
  |
  v
Estimation Difficulty Curve (unlocks after baseline established)
  |
  v
Quest / Narrative Wrapper (can be added at any phase)
  |
  v
Time Anchoring Exercises (standalone, no dependency on routines)
  |
  v
Self-Set Routine Creation (requires player comfort with core loop)
```

**Key dependency insight:** The entire feature tree grows from **Parent Setup -> Routine Configuration -> Estimation Challenge -> Accuracy Feedback**. This is the critical path. Everything else layers on top. Build this path first, get it right, and every other feature adds value to a working core.

---

## MVP Recommendation

### Phase 1: Playable Core (Must Ship)

Prioritize these -- they create the minimum viable training loop:

1. **Parent setup mode** with routine configuration (tasks, order, schedule days)
2. **Time estimation challenge** -- player estimates each task, does the task, sees elapsed time
3. **Accuracy feedback** -- non-punitive, curiosity-framed ("1:12 off!")
4. **Single notification** per routine ("Your morning quest is ready")
5. **Streak tracking** -- simple daily participation streak
6. **Basic progress visualization** -- estimation accuracy over time (even a simple list/graph)
7. **Age-appropriate visual design** -- clean, modern, not childish, not clinical
8. **Offline functionality** -- core loop works without network

### Phase 2: Engagement Layer (Retain Over Weeks)

These make the app worth returning to after the novelty wears off:

9. **"Time Sense" score/level** -- persistent progression metric
10. **Estimation history with personal bests** -- per-task calibration data
11. **Surprise accuracy bonus** -- special moment when estimate is very close
12. **Estimation difficulty curve** -- progress from single-task to sequence to full-routine estimation
13. **Unlockable themes/customization** -- earn visual rewards

### Phase 3: Depth and Transfer (Solidify the Skill)

These deepen the training and promote skill transfer:

14. **Quest/narrative wrapper** -- thin story layer giving meaning to daily quests
15. **Contextual learning** -- per-task insights ("you always underestimate packing")
16. **Time anchoring exercises** -- standalone duration-sense mini-games
17. **Self-set routine creation** -- player creates her own routines
18. **Weekly reflection prompt** -- brief summary of the week's progress

### Defer Indefinitely

- Social features
- Complex RPG systems
- Parent monitoring dashboard
- Screen time tracking
- AI motivational messages

**Rationale for ordering:** Phase 1 is the hypothesis test -- does estimation-with-feedback in a game wrapper actually improve time perception and reduce morning conflict? If yes, Phase 2 keeps her engaged long enough for the skill to consolidate (research suggests 4-8 weeks of regular practice for durable improvement in time estimation). Phase 3 deepens the skill and transfers ownership, which is the real success state -- she doesn't need the app anymore because she has internalized time sense.

---

## Sources

- Training data knowledge of the following apps (reviewed prior to May 2025 cutoff): Brili, Tiimo, Habitica, Forest, Time Timer, Routinery, Alarmy, Streaks, Todoist, Things 3
- Time perception research: Zakay & Block prospective timing paradigm, interval timing literature, ADHD time perception studies (Barkley, Toplak & Tannock)
- Gamification design: Self-Determination Theory (Deci & Ryan) applied to app design, particularly autonomy, competence, and relatedness as motivation drivers
- ADHD app design patterns: ADDitude Magazine recommendations, CHADD resources on time management tools
- Teen UX patterns: Nielsen Norman Group research on teen users, Common Sense Media app evaluations

**Confidence caveat:** All sources are from training data (cutoff May 2025). No live verification was possible during this research session. The competitive landscape and feature norms are stable enough that MEDIUM confidence is warranted, but specific app versions and any new entrants after May 2025 are not captured. Recommend spot-checking current App Store listings for Brili, Tiimo, and Habitica before finalizing requirements.
