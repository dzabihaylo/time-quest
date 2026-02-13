# TimeQuest

## What This Is

An iOS game that trains time perception in a 13-year-old with time blindness. Disguised as a game, it teaches the player to accurately estimate how long real-life tasks take, building an internal clock through repeated calibration. A parent sets up routines behind the scenes; the player experiences it as her own game.

## Core Value

The player develops an accurate internal sense of time — the ability to predict how long things take and act on those predictions without external prompting.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Time estimation game mechanics that train duration perception
- [ ] Parent setup mode for configuring real routines (school mornings, activity prep)
- [ ] Player-facing game experience that feels like HER thing, not a parent's tool
- [ ] Progress tracking that shows time estimation accuracy improving over time
- [ ] Support for multiple routine types (school mornings, roller derby, art class)
- [ ] Game loop that makes time calibration engaging across weeks of use

### Out of Scope

- Nagging/reminder system — defeats the purpose; she ignores timers already
- Social/multiplayer features — this is a personal skill-building tool
- Parental surveillance dashboard — parent role is setup only, not monitoring
- Android version — iOS only for v1

## Context

- The player is a 13-year-old girl with deep time blindness (not selective — she can't calibrate time for anything, including things she enjoys)
- She values independence and feeling grown up / in control
- Current dynamic: parent nags → she feels less independent → resists more → conflict loop
- Checklists and timers have failed because they don't address the root issue (perception, not motivation)
- She has school mornings (5x/week) plus 2-3 activities (roller derby, art class) = 7-8 real training opportunities per week
- Her phone is the one thing she always has and pays attention to
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
| Game-first, not tool-first | Tools (timers, checklists) already failed; game mechanics create intrinsic motivation | — Pending |
| Parent as invisible setup | Preserves her sense of independence and ownership | — Pending |
| Time estimation as core mechanic | Root cause is perception, not motivation — train the actual skill | — Pending |
| iOS native | Her phone is the delivery channel; native gives best UX | — Pending |

---
*Last updated: 2026-02-12 after initialization*
