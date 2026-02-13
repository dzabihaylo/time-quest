# Roadmap: TimeQuest

## Overview

TimeQuest delivers time-perception training disguised as a game for a 13-year-old with time blindness. Phase 1 builds the complete estimation-feedback loop -- parent creates routines, player estimates task durations, performs tasks without a visible clock, and receives non-punitive accuracy feedback. Phase 2 layers on the progression system, sensory polish, and notifications needed to sustain engagement through the 8+ weeks required for durable skill transfer.

## Phases

- [ ] **Phase 1: Playable Foundation** - Parent setup + core estimation loop + age-appropriate first experience
- [ ] **Phase 2: Engagement Layer** - Progression system + sensory feedback + notifications to sustain play past week 3

## Phase Details

### Phase 1: Playable Foundation
**Goal**: A parent can configure real routines and a player can complete estimation sessions with curiosity-framed accuracy feedback -- the minimum viable training loop that tests whether estimation-with-feedback improves time perception.
**Depends on**: Nothing (first phase)
**Requirements**: FOUN-01, FOUN-02, FOUN-03, FOUN-04, FOUN-05, PRNT-01, PRNT-02, PRNT-03, PRNT-04, PRNT-05, PRNT-06, PRNT-07, GAME-01, GAME-02, GAME-03, GAME-04, GAME-05, GAME-06, GAME-07, GAME-08, FEEL-04, FEEL-05, FEEL-06, PROG-07
**Success Criteria** (what must be TRUE):
  1. App launches into player mode; a parent can access a hidden setup mode via gesture + PIN with zero parent-facing language visible in the player experience
  2. Parent can create a routine with ordered tasks, display names, optional reference durations, and a weekly schedule in under 5 minutes
  3. Player can select an available quest, estimate each task's duration before doing it, tap done when finished, and see accuracy feedback framed as discovery (not judgment) after each task
  4. No visible clock or countdown appears during task execution; the player relies entirely on her internal sense of time
  5. First 3-5 sessions are framed as calibration/discovery to establish a baseline; all estimation data persists locally across app launches
**Plans**: 3 plans

Plans:
- [ ] 01-01: Data layer and dual-mode shell (SwiftData models, repositories, RoleRouter with PIN gate, app entry point)
- [ ] 01-02: Parent setup flow (routine CRUD, task editor, scheduling, display name mapping)
- [ ] 01-03: Core gameplay loop (quest selection, estimation capture, silent timer, accuracy feedback, session completion, onboarding, visual design)

### Phase 2: Engagement Layer
**Goal**: The player has visible progression, sensory reinforcement, and gentle reminders that sustain daily engagement past the week-3 novelty cliff -- long enough for time perception skill to consolidate.
**Depends on**: Phase 1
**Requirements**: PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, PROG-06, FEEL-01, FEEL-02, FEEL-03, NOTF-01, NOTF-02, NOTF-03
**Success Criteria** (what must be TRUE):
  1. Player earns XP based on estimation accuracy (not task speed) and sees a persistent "Time Sense" level that increases with accumulated XP
  2. Player sees a daily participation streak that pauses gracefully on skipped days (no guilt, no punishment) and can view estimation accuracy trends over time via a chart
  3. Player can see personal bests per task and receives haptic feedback, sound effects, and celebratory animations on accuracy milestones
  4. Player receives a single game-framed notification per routine when it is time to play, controls her own notification preferences, and can disable notifications entirely
**Plans**: 3 plans

Plans:
- [ ] 02-01: Progression system (XP engine, level calculation, streak tracking with graceful pause, personal bests)
- [ ] 02-02: Sensory polish (haptic feedback, sound effects, celebratory animations/particles for milestones, accuracy trend charts)
- [ ] 02-03: Notifications (game-framed reminders, player-controlled preferences, single notification per routine)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|---------------|--------|-----------|
| 1. Playable Foundation | 0/3 | Not started | - |
| 2. Engagement Layer | 0/3 | Not started | - |

---
*Roadmap created: 2026-02-12*
*Depth: quick | Phases: 2 | Requirements: 36/36 mapped*
