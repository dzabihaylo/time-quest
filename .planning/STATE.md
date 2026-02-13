# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-13)

**Core value:** The player develops an accurate internal sense of time -- the ability to predict how long things take and act on those predictions without external prompting.
**Current focus:** v2.0 Advanced Training -- Phase 3 ready to plan

## Current Position

Milestone: v2.0 Advanced Training
Phase: 3 of 6 (Data Foundation + CloudKit Backup)
Plan: --
Status: Ready to plan
Last activity: 2026-02-13 -- v2.0 roadmap created (4 phases, 46 requirements mapped)

Progress: [##########....................] 46% (6/13 plans -- v1.0: 6/6, v2.0: 0/7)

## Performance Metrics

**v1.0 MVP:**
- Phases: 2, Plans: 6, Tasks: 13
- Timeline: 2 days (2026-02-12 -> 2026-02-13)
- Codebase: 46 Swift files, 3,575 LOC

**v2.0 Advanced Training:**
- Phases: 4 (Phases 3-6), Plans: 7 (estimated)
- Status: Not started

## Accumulated Context

### Decisions

See .planning/PROJECT.md Key Decisions table for full list with outcomes.

**v2.0 scope decisions:**
- CloudKit-first migration: schema + defaults must complete before any feature work
- InsightEngine is dependency root: insights before reflections (Phase 4 before Phase 6)
- Self-set routines + sound assets bundled: independent features, similar risk level
- All new model properties require defaults (CloudKit + lightweight migration constraint)

### Pending Todos

- Create v2.0 roadmap -- DONE
- Plan Phase 3 (Data Foundation + CloudKit Backup)
- Begin phase execution

### Blockers/Concerns

- CloudKit + SwiftData integration needs real-device testing (MEDIUM research flag)
- Sound effects still placeholder .wav files (Phase 5 will fix)
- XP curve constants need playtesting data (Phase 5 exposes tunables)

## Session Continuity

Last session: 2026-02-13
Stopped at: v2.0 roadmap created, Phase 3 ready to plan
Resume file: None
