# TimeQuest

## What This Is

An iOS game that trains time perception in a 13-year-old who struggles with estimating how long things take. Disguised as a quest game, it teaches the player to accurately estimate how long real-life tasks take, building an internal clock through repeated estimation-feedback cycles. A parent sets up routines behind the scenes; the player experiences it as her own game with XP, levels, streaks, accuracy milestones, learning insights, self-created quests, and weekly progress reflections.

## Core Value

The player develops an accurate internal sense of time — the ability to predict how long things take and act on those predictions without external prompting.

## Requirements

### Validated

- ✓ Time estimation game mechanics that train duration perception — v1.0
- ✓ Parent setup mode for configuring real routines (school mornings, activity prep) — v1.0
- ✓ Player-facing game experience that feels like HER thing, not a parent's tool — v1.0
- ✓ Progress tracking that shows time estimation accuracy improving over time — v1.0
- ✓ Support for multiple routine types (school mornings, roller derby, art class) — v1.0
- ✓ Game loop that makes time calibration engaging across weeks of use — v1.0
- ✓ XP/leveling progression system based on estimation accuracy — v1.0
- ✓ Graceful streak tracking that pauses on skipped days — v1.0
- ✓ Haptic feedback, sound effects, and celebratory animations — v1.0
- ✓ Game-framed notifications with player-controlled preferences — v1.0
- ✓ Accuracy trend charts and personal bests per task — v1.0
- ✓ iCloud backup for progress data with graceful offline fallback — v2.0
- ✓ Per-task learning insights (bias, trend, consistency) with curiosity-framed language — v2.0
- ✓ In-gameplay contextual hints showing reference data, not corrections — v2.0
- ✓ Player-created quests with guided creation flow and templates — v2.0
- ✓ Production audio that mixes with background music and respects silent switch — v2.0
- ✓ XP curve constants exposed as tunable values — v2.0
- ✓ Weekly reflection summaries absorbable in 15 seconds — v2.0

### Active

#### Current Milestone: v3.0 Adaptive & Connected

**Goal:** Make TimeQuest a daily-use app that adapts to the player's skill level, integrates with her real schedule and music, and looks like something a teen in 2026 would actually want on her phone.

**Target features:**
- Adaptive difficulty that evolves challenge level based on accuracy trends
- Spotify-powered routine playlists that serve as audible time cues (hands-free)
- Calendar-aware routines that know school vs. summer, activity seasons, holidays
- Modern teen-friendly UI/brand refresh with updated visual identity and naming

### Out of Scope

- Nagging/reminder system — defeats the purpose; she ignores timers already
- Social/multiplayer features — this is a personal skill-building tool
- Parental surveillance dashboard — parent role is setup only, not monitoring
- Android version — iOS only for now
- Visible countdown timer during tasks — externalizes the clock, opposite of training internal sense
- Punishment for inaccuracy — this is a game, not a test; punishment kills engagement
- AI-generated motivational messages — teens detect and despise inauthentic positivity
- Goal-setting in reflections — reflections are informational, not prescriptive
- Mandatory reflection before play — reflections must never block gameplay

## Context

Shipped v2.0 Advanced Training with 6,211 LOC across 66 Swift files. Starting v3.0 Adaptive & Connected.
Tech stack: SwiftUI + SwiftData + SpriteKit + Swift Charts + CloudKit, iOS 17.0+, Swift 6.0, Xcode 16.2.
New for v3.0: Spotify Web API (or iOS SDK), EventKit (Calendar/Reminders), adaptive algorithms.
Build system: generate-xcodeproj.js (Node script) for pbxproj generation.
Architecture: Feature-sliced MVVM, pure domain engines, @Observable ViewModels, value-type editing.
Schema: V1→V2→V3 with lightweight migrations, CloudKit-backed with local fallback.

- The player is a 13-year-old girl who struggles with time perception — she can't accurately estimate how long things take, including things she enjoys
- She values independence and feeling grown up / in control
- Current dynamic: parent nags → she feels less independent → resists more → conflict loop
- She has school mornings (5x/week) plus 2-3 activities (roller derby, art class) = 7-8 real training opportunities per week
- Her schedule rotates annually: school year, summers off, various holidays, activity seasons
- Her phone is the one thing she always has and pays attention to
- She listens to music constantly — Spotify is already part of her routine
- Success = mornings and activity prep stop being a conflict, not perfection

## Constraints

- **Platform**: iOS (Swift/SwiftUI) — she uses an iPhone
- **Audience**: Must feel age-appropriate for a 13-year-old girl — not childish, not clinical
- **Parent visibility**: Parent sets up routines but player shouldn't feel surveilled
- **Engagement**: Must sustain engagement over weeks/months — this is a skill that builds slowly
- **Simplicity**: A solo developer (Claude-assisted) project — scope must be buildable

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Game-first, not tool-first | Tools (timers, checklists) already failed; game mechanics create intrinsic motivation | ✓ Good |
| Parent as invisible setup | Preserves her sense of independence and ownership | ✓ Good |
| Time estimation as core mechanic | Root cause is perception, not motivation — train the actual skill | ✓ Good |
| iOS native | Her phone is the delivery channel; native gives best UX | ✓ Good |
| generate-xcodeproj.js for build | xcodegen unavailable, CLI project creation unreliable | ✓ Good — worked reliably across all 14 plans |
| Value-type editing in ViewModels | Prevents SwiftData auto-save corruption | ✓ Good |
| Pure domain engines | Testable, zero-dependency business logic | ✓ Good — InsightEngine + WeeklyReflectionEngine both pure Foundation |
| Concave XP curve (baseXP * level^1.5) | Fast early levels keep 13-year-old engaged | — Pending playtesting |
| Graceful streak pause (never reset) | No guilt, no punishment — keeps the game encouraging | ✓ Good |
| EstimationSnapshot bridge pattern | Decouples domain engines from SwiftData; enables reuse across InsightEngine + WeeklyReflectionEngine | ✓ Good |
| Curiosity-framed language throughout | "Interesting --" not "You failed" — keeps tone encouraging and non-judgmental | ✓ Good |
| CloudKit with graceful fallback | try? .automatic first, fall back to .none — works on simulator and without iCloud | ✓ Good |
| SchemaV3 lightweight migrations only | No custom migration code needed; defaults on new properties | ✓ Good |
| UserDefaults for reflection state | No schema change needed for week tracking; avoids V4 migration | ✓ Good |
| Player routine creation as separate view | Simpler than sharing parent RoutineEditorView; different validation and UX needs | ✓ Good |
| Sports score card format for reflections | Quick, scannable, visual — absorbs in 15 seconds without scrolling | ✓ Good |

---
*Last updated: 2026-02-14 after v3.0 milestone started*
