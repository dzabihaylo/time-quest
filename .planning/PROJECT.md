# TimeQuest

## What This Is

An iOS game that trains time perception in a 13-year-old with time blindness. Disguised as a quest game, it teaches the player to accurately estimate how long real-life tasks take, building an internal clock through repeated estimation-feedback cycles. A parent sets up routines behind the scenes; the player experiences it as her own game with XP, levels, streaks, and accuracy milestones.

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

### Active

## Current Milestone: v2.0 Advanced Training

**Goal:** The player develops self-awareness about her estimation patterns and takes ownership of her time training through contextual insights, self-created routines, and weekly reflections — plus production polish.

**Target features:**
- Contextual learning insights (in-gameplay + dedicated "My Patterns" screen)
- Self-set routines with guided creation (templates + customization)
- Real sound assets replacing placeholders
- XP curve tuning from playtesting
- iCloud backup for progress data
- Weekly reflection summaries

### Out of Scope

- Nagging/reminder system — defeats the purpose; she ignores timers already
- Social/multiplayer features — this is a personal skill-building tool
- Parental surveillance dashboard — parent role is setup only, not monitoring
- Android version — iOS only for v1
- Visible countdown timer during tasks — externalizes the clock, opposite of training internal sense
- Punishment for inaccuracy — time blindness is neurological, not laziness
- AI-generated motivational messages — teens detect and despise inauthentic positivity

## Context

Shipped v1.0 MVP with 3,575 LOC across 46 Swift files.
Tech stack: SwiftUI + SwiftData + SpriteKit + Swift Charts, iOS 17.0+, Swift 6.0, Xcode 16.2.
Build system: generate-xcodeproj.js (Node script) for pbxproj generation.
Architecture: Feature-sliced MVVM, pure domain engines, @Observable ViewModels, value-type editing.

- The player is a 13-year-old girl with deep time blindness (not selective — she can't calibrate time for anything, including things she enjoys)
- She values independence and feeling grown up / in control
- Current dynamic: parent nags → she feels less independent → resists more → conflict loop
- She has school mornings (5x/week) plus 2-3 activities (roller derby, art class) = 7-8 real training opportunities per week
- Her phone is the one thing she always has and pays attention to
- Success = mornings and activity prep stop being a conflict, not perfection
- Sound effects use placeholder .wav files — real audio assets needed for production

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
| generate-xcodeproj.js for build | xcodegen unavailable, CLI project creation unreliable | ✓ Good — worked reliably across all 6 plans |
| Value-type editing in ViewModels | Prevents SwiftData auto-save corruption | ✓ Good |
| Pure domain engines | Testable, zero-dependency business logic | ✓ Good |
| Concave XP curve (baseXP * level^1.5) | Fast early levels keep 13-year-old engaged | — Pending playtesting |
| Graceful streak pause (never reset) | No guilt, no punishment aligns with ADHD-friendly design | ✓ Good |
| Placeholder .wav sound files | Infrastructure works; real assets swappable later | ⚠️ Revisit — need real audio |

---
*Last updated: 2026-02-13 after v2.0 milestone start*
