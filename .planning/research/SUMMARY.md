# Project Research Summary

**Project:** TimeQuest — iOS Time-Perception Training Game
**Domain:** Gamified behavioral training app for teens with time blindness
**Researched:** 2026-02-12
**Overall Confidence:** MEDIUM

## Executive Summary

TimeQuest is fundamentally a time-perception training tool disguised as a game, not a timer app with game mechanics bolted on. The research reveals a critical insight: every existing app in this space (Brili, Tiimo, Habitica, Forest) either externalizes time through timers/planners or gamifies task completion without training the underlying perception skill. TimeQuest's competitive advantage lies in estimation-first mechanics where the player predicts task duration, performs the task without seeing a clock, and receives non-punitive feedback on accuracy. This approach directly trains the internal clock that time-blind individuals lack.

The recommended technical stack is deliberately minimal: SwiftUI for all non-game UI, SpriteKit for interactive game elements, SwiftData for persistence, and zero third-party dependencies. This allows a solo developer to ship quickly while maintaining native performance and future-proofing for CloudKit sync. The architecture must separate parent setup from player experience at the foundational level — not as an afterthought — because a 13-year-old will reject any tool that feels like parental surveillance. The parent creates routines behind a PIN-protected mode; the player experiences these as "quests" without seeing the setup scaffolding.

The most dangerous pitfall is building a timer app in game clothing. If the core mechanic shows a countdown during task execution, the app recreates the external dependency pattern that already fails. The second-most dangerous pitfall is the overjustification effect: lavish external rewards (points, badges, leaderboards) initially drive engagement but train "gaming the system" behavior rather than genuine time perception improvement. By week 3, when reward novelty fades, engagement collapses. Prevention requires making accuracy itself the score, using informational feedback over controlling rewards, and designing for a 90-day engagement arc with progressive difficulty.

## Key Findings

### Recommended Stack

The stack is unapologetically Apple-first-party. SwiftUI + SpriteKit (via SpriteView) handles all UI and game rendering. SwiftData (iOS 17+) provides local persistence with optional CloudKit sync. The Observation framework (@Observable macro) replaces older ObservableObject patterns for cleaner state management. AVFoundation handles audio, Core Haptics provides tactile feedback that reinforces time perception, UserNotifications enables thoughtful reminders, and Swift Charts visualizes progress over time.

**Core technologies:**

- **SwiftUI + SpriteKit hybrid** — SwiftUI owns navigation/state, SpriteKit owns real-time game rendering. SpriteView embeds scenes in SwiftUI with zero friction. This splits UI-heavy screens (setup, progress) from interactive challenges.
- **SwiftData (iOS 17+)** — Modern persistence with @Model macros and SwiftUI @Query integration. Handles routines, estimation history, progression state. CloudKit sync is a config change, not an architecture change.
- **Observation framework (@Observable)** — Fine-grained change tracking for ViewModels. Simpler than Combine, better performance than ObservableObject, and Apple's current direction.
- **Core Haptics** — Custom haptic patterns create rhythmic "tick" feedback that directly reinforces time perception. This is a critical training mechanism, not polish.
- **Swift Charts (iOS 16+)** — First-party charting shows estimation accuracy trends. Visual proof of improvement sustains motivation.

**Version constraints flagged for validation:**
- iOS 17.0+ deployment target (required for SwiftData)
- Xcode 16.x with Swift 6.x (verify latest stable at project init)
- SwiftData had early-adopter bugs in iOS 17.0–17.2; by iOS 17.4+ it's stable

### Expected Features

Research reveals a clear three-tier feature structure: table stakes (required for baseline functionality), differentiators (what makes TimeQuest unique), and anti-features (things to explicitly NOT build because they undermine the core design).

**Must have (table stakes):**

- **Time estimation challenge** — Core mechanic: player estimates task duration, does task, sees accuracy. Without this, there's no product.
- **Non-punitive accuracy feedback** — Feedback must be curiosity-inducing ("3 minutes off!") not shame-inducing ("Wrong!"). Bad estimates are calibration data, not failures.
- **Multiple routines with task breakdown** — Parent configures routines (school mornings, activity prep) composed of granular tasks. Each task is an estimation opportunity.
- **Streak/consistency tracking** — Every habit app has this. Teens expect it. Tracks participation (daily play), not perfection (accuracy).
- **Progress visualization** — "Am I getting better?" is the core motivation question. Must show estimation accuracy trending over time.
- **Parent setup mode (invisible to player)** — Parent configures routines behind a PIN. Player never sees setup UI or language.
- **Age-appropriate design** — Not cartoon-y (too young), not clinical (too boring). Reference Duolingo's polish: slightly playful, modern, mainstream-passable.
- **Offline functionality** — Morning routines happen with or without wifi. Core loop must work offline.

**Should have (competitive differentiators):**

- **Estimation calibration mechanic** — No competitor trains estimation. This IS the product. Over time, the gap between estimated and actual shrinks.
- **Real-task anchoring** — Estimates are for tasks she's about to do (brush teeth, pack bag), not abstract exercises. Training transfers because it's in-situ.
- **Invisible parent role** — Parent sets up, player owns. She never feels managed. The game "just has quests" that happen to match her routines.
- **Estimation history with personal bests** — "You used to think this took 1 minute. Your average is 3:20. Last week you guessed 3:00 — closest ever!"
- **Quest/narrative wrapper** — Routines are "quests." Thin narrative gives daily repetition a sense of meaning and progress.
- **Estimation difficulty curve** — Early: estimate one task. Later: estimate a sequence. Advanced: estimate total routine time. Builds complexity as skill grows.
- **"Time Sense" score/level** — Persistent progression metric representing overall accuracy. "I'm Level 12 in Time Sense."
- **Surprise accuracy bonus** — When estimate is very close (e.g., within 30 seconds), special celebration. Creates positive surprise moments.

**Defer (v2+):**

- **Time anchoring exercises** — Standalone mini-games for raw duration sense ("Close your eyes. Open when you think 2 minutes have passed"). Adds depth but not required for MVP.
- **Contextual learning** — App learns per-task patterns ("You always underestimate packing by 4 minutes"). Advanced analytics layer.
- **Self-set routine creation** — Player creates her own routines. Signals the skill is transferring, but not needed for initial validation.
- **Social/multiplayer features** — This is personal skill-building, not social competition. Adds scope without value.
- **Parent monitoring dashboard** — If she discovers parent can see real-time data, trust is broken. If progress visibility is needed, make it optional and periodic.

**Anti-features (explicitly do NOT build):**

- **Visible countdown timer during tasks** — Externalizes time instead of building internal clock. She already ignores timers.
- **Punishment for inaccuracy** — Losing points/lives for bad estimates creates anxiety. Time blindness is neurological, not motivational.
- **Nagging/repeated reminders** — Multiple notifications = new nagging system. One prompt per routine. No follow-up if she doesn't engage.
- **Complex RPG systems** — Scope creep. Solo dev cannot maintain deep RPG. Keep gamification light: levels, streaks, unlockables.

### Architecture Approach

The recommended pattern is **feature-sliced MVVM with a shared domain core**. TimeQuest is two apps in one shell: a parent setup tool and a player game. They share data (SwiftData repositories) and domain logic (GameEngine, ProgressionEngine, TimeEstimationScorer) but have completely separate UI flows. SwiftUI's reactive binding maps directly to MVVM, it's the iOS standard, and it keeps game logic testable without UI dependencies.

**Four-layer architecture (bottom-up):**

1. **Data Layer** — SwiftData models (Routine, Task, GameSession, EstimationEntry, PlayerProgress) + repository protocols. Repositories abstract ModelContext behind protocol for testability.
2. **Domain Layer** — Pure Swift engines with zero framework dependencies. GameEngine (challenge selection, session orchestration), ProgressionEngine (XP, levels, streaks, unlocks), TimeEstimationScorer (accuracy algorithms), RoutineManager (validation, CRUD orchestration).
3. **ViewModel Layer** — @Observable ViewModels mediate between UI and domain. ParentViewModel, GameViewModel, ChallengeViewModel, ProgressionViewModel.
4. **UI Layer** — SwiftUI views split into Parent Flow (routine setup, task editor, progress view) and Player Flow (challenge screen, results/feedback, progression dashboard, reward showcase). RoleRouter switches between flows based on PIN gate.

**Critical architectural insight:** Parent-created data (routines, tasks) becomes player-facing game content (quests, challenges). The domain layer transforms structured routines into game challenges. The player UI completely re-skins setup-oriented data as game language. A routine named "School Morning" becomes "Morning Quest." A task "Take a shower" becomes a challenge "Shower Power."

**Major components:**

1. **RoleRouter** — Determines parent vs player mode. PIN-protected gate. Defaults to player mode so the app feels like hers.
2. **GameEngine** — Core game loop: selects challenges from parent-created routines, evaluates estimates, advances difficulty. Pure logic, no UI/framework dependencies.
3. **ProgressionEngine** — XP calculation, level thresholds, streak logic, unlock rules. Pure logic, unit-testable.
4. **TimeEstimationScorer** — Scores accuracy (estimated vs actual duration). Returns rating (.perfect, .close, .off, .wayOff). Pure function.
5. **SwiftData Repositories** — Protocol-based data access (RoutineRepository, SessionRepository, ProgressRepository). Abstracts ModelContext for testing. Implementations inject ModelContext.
6. **ViewModels (@Observable)** — Hold presentation state, orchestrate domain engines, communicate with repositories. Never pass @Model objects directly to views.

**Build order (respects dependencies):**
1. SwiftData models (foundation)
2. Repository protocols + implementations
3. RoleRouter with PIN gate
4. Parent flow (RoutineManager → ParentViewModel → Parent UI)
5. Core gameplay (TimeEstimationScorer → GameEngine → ChallengeViewModel → GameViewModel → Player UI)
6. Progression system (ProgressionEngine → ProgressionViewModel → Progression UI)
7. Polish (haptics, sound, animations, onboarding)

### Critical Pitfalls

**1. Building a Timer App in Game Clothing**
The core mechanic must be estimation-first: "How long will this take?" BEFORE any timing begins. Time feedback comes AFTER the task, not during. Never show a running clock during execution. The game moment is the reveal (gap between estimate and reality), not the countdown. If playtesters describe it as "a timer with points," the mechanic is wrong. Phase relevance: Phase 1 (core game loop). This is THE make-or-break decision.

**2. Overjustification Effect — Rewards That Destroy Intrinsic Motivation**
Lavish external rewards (points, badges, leaderboards) initially drive engagement but train "gaming the system" behavior. By week 3, when novelty fades, engagement collapses because she now associates the activity with extrinsic reward. Prevention: reward accuracy and improvement, not just participation. Use informational feedback ("how close") not controlling feedback ("points for compliance"). The "score" should BE the estimation accuracy. Celebrate perception milestones ("You've nailed 5-minute estimates 3 times in a row"). Phase relevance: Phase 1-2 (game mechanics, reward system). Must be baked into core loop.

**3. Parental Control Pattern Leaks Through UX**
If she discovers routines were parent-configured, the app shifts from "my game" to "another thing my parents make me do." At 13, autonomy is the central need. Any parental-control perception gets rejected. Prevention: parent setup must be invisible (separate device, PIN-locked mode, zero trace in player UI). Player must be able to create her own challenges alongside parent-seeded ones. Frame routines in game language, not parent language ("Morning Quest" not "Get ready for school"). Notifications must be opt-in and player-controlled. Phase relevance: Phase 1 (UX architecture). Two-persona architecture must be designed from day one. Retrofitting is nearly impossible.

**4. Training Compliance Instead of Perception**
If the game rewards completing tasks on time (compliance) rather than estimating accurately (perception), she learns "rush through the checklist" not "develop internal time sense." Prevention: core metric MUST be estimation accuracy: |estimated - actual|. Being "wrong" on an estimate should feel informative ("That took 2.5x longer than you thought!") not punitive ("You failed!"). Track calibration trends over time. Explicitly separate "how accurate was your guess" from "did you finish on time." Phase relevance: Phase 1 (core mechanic), Phase 2 (feedback/progress). Estimation-accuracy-as-score must be the foundation.

**5. Novelty Cliff — Week 3 Abandonment**
Time perception training requires months of daily practice for measurable skill transfer. Most gamified apps front-load content; by session 20, it's repetitive. ADHD amplifies novelty-seeking. Prevention: design for a 90-day engagement arc, not 7 days. Map what's new at week 2, week 4, week 8. Progressive challenge: start with 5-minute tasks, graduate to 30-minute tasks, then sequences. Variable reward schedule: occasional surprise feedback, unlockable insights, changing visual themes. Real-world anchoring provides inherent variety (each day's routines are slightly different). Phase relevance: Phase 2-3 (content roadmap, progressive difficulty). But Phase 1 core loop must be designed with extensibility in mind.

**Additional pitfalls (moderate severity):**

- **Wrong notification strategy** — Notifications become new nagging. Prevention: game-framed ("Your quest awaits" not "Time to get ready"), player-controlled, never at parent-nag times.
- **Age-inappropriate aesthetic** — Too childish or too clinical. Prevention: reference mainstream teen apps (Duolingo, BeReal), use game language not medical terms, let her customize.
- **Punishing inaccuracy** — Red screens, lost points for bad estimates. Prevention: every estimate is data. Frame surprises as discoveries ("That took 2.5x longer!"), show trends not individual failures.
- **Scope creep** — Adding social features, web portals, multi-device sync, detailed analytics. Prevention: MVP is estimate → do → see accuracy → track improvement. Everything else is post-validation.
- **No baseline** — Can't measure improvement without knowing initial accuracy. Prevention: first 3-5 sessions = calibration/discovery. Record initial accuracy per task type. Show improvement after 1-2 weeks.

## Implications for Roadmap

Based on combined research, the roadmap should follow a **foundation → core loop → engagement → depth** progression. Dependencies drive the order: player needs parent-created routines to exist before there's anything to play. Core gameplay must work before progression wraps it. Engagement features sustain long enough for skill transfer (8-12 weeks minimum).

### Phase 1: Playable Foundation (MVP)

**Rationale:** Establishes the minimum viable training loop and tests the core hypothesis: does estimation-with-feedback in a game wrapper improve time perception and reduce morning conflict?

**Delivers:**
- Parent setup mode (PIN-protected) with routine configuration (tasks, order, schedule)
- Time estimation challenge (player estimates each task, does task, sees elapsed time)
- Non-punitive accuracy feedback ("1:12 off!" curiosity-framed)
- Single notification per routine ("Your morning quest is ready")
- Basic streak tracking (daily participation, not accuracy)
- Simple progress visualization (accuracy over time — even a list/graph)
- Age-appropriate visual design (clean, modern, not childish/clinical)
- Offline-first functionality

**Stack elements:**
- SwiftData models + repository protocols
- RoleRouter with PIN gate
- RoutineManager domain logic
- ParentViewModel + Parent UI
- TimeEstimationScorer (pure logic, test-first)
- GameEngine (challenge selection)
- ChallengeViewModel (timer management)
- GameViewModel (session orchestration)
- Player gameplay views (ChallengeView, ResultsView)

**Architecture components:**
- Data layer (models, repositories)
- Domain layer (RoutineManager, TimeEstimationScorer, GameEngine)
- Parent flow (full stack)
- Player core gameplay (challenge → result loop)

**Must avoid:**
- Pitfall 1 (timer in disguise) — estimation-first, no visible clock during tasks
- Pitfall 3 (parent control leakage) — invisible parent mode, game-framed language
- Pitfall 4 (training compliance) — score = accuracy, not on-time completion
- Pitfall 10 (no baseline) — first sessions record initial accuracy per task type

**Research flags:** Standard patterns. No phase-specific research needed. Well-documented iOS development (SwiftUI, SwiftData MVVM).

**Success criteria:** Parent can create routines. Player can complete a session (estimate → task → feedback). Estimation accuracy data persists. Both roles feel separate.

---

### Phase 2: Engagement Layer (Sustain 8+ Weeks)

**Rationale:** MVP validates the core mechanic works. Phase 2 adds the engagement hooks needed to sustain play long enough for time perception skill to consolidate (research suggests 4-8 weeks of regular practice for durable improvement).

**Delivers:**
- "Time Sense" score/level (persistent progression metric representing overall accuracy)
- Estimation history with personal bests (per-task calibration data)
- Surprise accuracy bonus (special celebration when estimate is very close)
- Estimation difficulty curve (progress from single-task → sequence → full-routine estimation)
- Unlockable themes/customization (earn visual rewards)
- Notification system (game-framed, player-controlled)
- Data persistence with iCloud backup (key metrics)

**Stack elements:**
- ProgressionEngine (XP, levels, streaks, unlock rules)
- ProgressionViewModel
- Player progression views (ProgressionView, RewardsView)
- HapticManager (tactile feedback reinforcement)
- SoundManager (audio feedback)
- Swift Charts (accuracy trend visualization)
- UserNotifications (thoughtful reminders)

**Architecture components:**
- Progression system (ProgressionEngine → ProgressionViewModel → Progression UI)
- Services layer (haptics, sound, notifications)
- Polish layer (animations, visual feedback)

**Must avoid:**
- Pitfall 2 (overjustification) — reward accuracy/improvement, not just participation; informational over controlling feedback
- Pitfall 5 (novelty cliff) — 90-day engagement arc; progressive difficulty; variable reward schedule
- Pitfall 6 (notification nagging) — game-framed, player-controlled, never at parent-nag times
- Pitfall 8 (punishing inaccuracy) — discoveries not failures; trend-based feedback

**Research flags:** Standard patterns for progression systems, notifications, analytics. Consider light research on haptic patterns for time reinforcement (Core Haptics custom patterns).

**Success criteria:** Engagement sustains past week 3. Estimation accuracy shows measurable improvement. Player returns daily without external prompting.

---

### Phase 3: Depth and Transfer (Solidify Skill)

**Rationale:** Skill is developing. Phase 3 deepens training, promotes skill transfer beyond routines, and shifts ownership fully to the player.

**Delivers:**
- Quest/narrative wrapper (thin story layer giving meaning to daily quests)
- Contextual learning (per-task insights: "you always underestimate packing")
- Time anchoring exercises (standalone duration-sense mini-games)
- Self-set routine creation (player creates her own routines)
- Weekly reflection prompt (brief summary of week's progress)
- Subjective time distortion challenges ("10 min of homework vs 10 min of TikTok")
- Advanced difficulty: estimate by duration range (micro 1-5min, short 5-15min, medium 15-30min)

**Stack elements:**
- SpriteKit for interactive mini-games (time anchoring exercises)
- Advanced analytics (trend detection, per-task pattern recognition)
- Contextual feedback engine

**Architecture components:**
- Extended domain logic (DifficultyCalculator, per-task pattern detection)
- Advanced game mechanics (time anchoring, subjective distortion challenges)
- Player-owned content (self-set routines)

**Must avoid:**
- Pitfall 9 (scope creep) — strict feature gating; defer social, web portals, accounts
- Pitfall 11 (treating all durations equal) — per-duration-range tracking; graduate short → long
- Pitfall 13 (ignoring subjective distortion) — awareness challenges as advanced content

**Research flags:** Phase-specific research recommended for time-perception training mechanics (prospective timing paradigm, interval timing research). Game design for sustained engagement (variable reward schedules, narrative progression).

**Success criteria:** Skill transfers outside structured routines. Player creates own challenges. Morning conflict measurably reduced. She doesn't need the app anymore (internalized time sense).

---

### Phase Ordering Rationale

**Why this order:**

1. **Foundation before engagement** — Without a working core loop (estimate → task → feedback), progression systems have nothing to wrap. Parent setup must exist before player content exists.

2. **Engagement before depth** — Players won't reach advanced features if they abandon at week 3. Sustaining engagement (Phase 2) unlocks time for skill consolidation before adding depth (Phase 3).

3. **Dependencies respected** — Data models → repositories → domain engines → ViewModels → UI. Parent flow before player flow (player needs routines to exist). Core gameplay before progression (can't calculate XP without estimation results).

4. **Risk mitigation sequenced** — Critical pitfalls (timer-in-disguise, parent control leakage, training compliance) are addressed in Phase 1 because they're architectural. If these are wrong, nothing else matters. Engagement pitfalls (overjustification, novelty cliff) are addressed in Phase 2. Advanced pitfalls (scope creep, subjective distortion) are Phase 3 concerns.

5. **Validation gates** — Each phase tests a hypothesis. Phase 1: does the mechanic work? Phase 2: can we sustain engagement? Phase 3: does the skill transfer? Don't build Phase 2 until Phase 1 validates. Don't build Phase 3 until Phase 2 shows retention.

**Critical path:**
```
SwiftData Models → Repositories → RoleRouter → Parent Flow → GameEngine → Player Core Loop → ProgressionEngine → Engagement Layer → Depth Features
```

### Research Flags

**Needs phase-specific research:**

- **Phase 3 advanced mechanics** — Time-perception training literature (prospective timing paradigm, Zakay & Block research). How to design time anchoring exercises that actually improve duration sense. Subjective time distortion patterns in ADHD populations.

- **Phase 2 haptic patterns** — Core Haptics custom patterns for rhythmic time reinforcement. Research optimal haptic feedback cadences for internal clock calibration.

**Standard patterns (skip phase research):**

- **Phase 1 foundation** — SwiftUI + SwiftData MVVM is well-documented. Parent/player role separation is standard multi-persona architecture. Timer logic, data persistence, basic game loops have established iOS patterns.

- **Phase 2 progression systems** — XP/level calculations, streak tracking, unlockables are standard gamification patterns. Notification best practices are well-documented in HIG.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| **Stack** | MEDIUM | SwiftUI + SpriteKit + SwiftData hybrid is well-established. Version numbers (iOS 17, Xcode 16, Swift 6) should be verified at project start. Zero third-party dependencies is intentional and sound. |
| **Features** | MEDIUM | Competitive analysis draws from training data (cutoff May 2025). Table stakes vs differentiators vs anti-features are internally consistent with project goals. Any apps launched after May 2025 not reflected. Validate current App Store landscape. |
| **Architecture** | MEDIUM | MVVM + repository pattern + pure domain engines is standard iOS architecture. SwiftData specifics (macro syntax, migration APIs) should be verified. Two-persona architecture (parent/player separation) is logically sound but implementation details need validation. |
| **Pitfalls** | MEDIUM | Grounded in established psychology (Deci & Ryan SDT, Barkley ADHD research) and iOS UX patterns. Overjustification effect, novelty cliff, autonomy needs are well-documented. Specific to this domain (time perception training for teens) but generalizable principles. |

**Overall confidence: MEDIUM**

All research conducted without web search or Context7 access. Findings draw from training data through January 2025. Stack recommendations are conservative (Apple first-party frameworks) and unlikely to have changed. Feature landscape and pitfalls are grounded in stable research (psychology, UX, ADHD literature). However, specific version numbers, API details, and apps launched post-May 2025 need validation.

### Gaps to Address

**Version validation (HIGH priority):**
- Exact iOS deployment target (iOS 17.0 or iOS 17.4 based on SwiftData stability)
- Current Xcode/Swift versions (16.x and 6.x are estimates)
- SwiftData API syntax (macro usage, migration patterns, @Query specifics)
- Swift 6 strict concurrency with SpriteKit (potential friction with SKScene)

**Domain-specific research (MEDIUM priority):**
- Current state of time-perception training research (any new findings post-2025)
- Optimal haptic patterns for duration reinforcement (Core Haptics implementation details)
- Time anchoring exercise design (prospective timing task variations)

**Competitive validation (LOW priority):**
- Current App Store landscape for ADHD/time management apps (any new entrants)
- Latest versions of Brili, Tiimo, Habitica (feature sets may have evolved)

**How to handle:**
- **During Phase 1 planning:** Verify all version numbers against current Xcode/iOS docs before project init. Test SwiftData migration patterns early (build simple prototype).
- **During Phase 2 planning:** Research Core Haptics custom patterns. Review latest ADHD time-management app releases for competitive intelligence.
- **During Phase 3 planning:** Deep research on time-perception training mechanics (prospective timing paradigm, interval timing). This is when advanced game mechanics are designed.

## Sources

### Stack (STACK.md)
- Apple Developer Documentation (developer.apple.com) — SwiftUI, SpriteKit, SwiftData, Observation framework
- WWDC 2023 sessions — SwiftData introduction, Observation framework
- WWDC 2024 sessions — Swift Testing, Observation refinements
- iOS framework documentation — AVFoundation, Core Haptics, UserNotifications, Charts
- **Note:** Web verification unavailable. Version numbers should be confirmed at project start.

### Features (FEATURES.md)
- Training data knowledge of competitive apps (reviewed prior to May 2025): Brili, Tiimo, Habitica, Forest, Time Timer, Routinery, Alarmy
- Time perception research — Zakay & Block prospective timing paradigm, interval timing literature, ADHD time perception studies (Barkley, Toplak & Tannock)
- Gamification design — Self-Determination Theory (Deci & Ryan), autonomy/competence/relatedness as motivation drivers
- ADHD app design patterns — ADDitude Magazine, CHADD resources
- Teen UX patterns — Nielsen Norman Group teen user research, Common Sense Media app evaluations

### Architecture (ARCHITECTURE.md)
- SwiftData architecture patterns — WWDC 2023/2024 sessions, @Model/ModelContainer/ModelContext API design
- @Observable macro — iOS 17, WWDC 2023 "Discover Observation in SwiftUI"
- NavigationStack path-based routing — iOS 16+, stable pattern
- MVVM as SwiftUI standard — Community consensus, Apple sample code
- Repository pattern for SwiftData — Common iOS community pattern to abstract ModelContext
- Game architecture patterns — iOS game development patterns applied to UI-driven context

### Pitfalls (PITFALLS.md)
- Deci, E. L., & Ryan, R. M. — Self-Determination Theory (intrinsic vs extrinsic motivation, overjustification effect)
- Barkley, R. A. — ADHD and time perception (time blindness as executive function deficit)
- Deterding, S. et al. — Gamification research (failure patterns in applied game mechanics)
- CHADD — Practical guidance on time blindness interventions
- Nielsen Norman Group — Gamification UX patterns and anti-patterns
- Apple HIG — iOS design patterns, age-appropriate design, notification best practices

---
*Research completed: 2026-02-12*
*Ready for roadmap: YES*
