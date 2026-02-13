# Roadmap: TimeQuest

## Milestones

- v1.0 MVP -- Phases 1-2 (shipped 2026-02-13)
- v2.0 Advanced Training -- Phases 3-6 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-2) -- SHIPPED 2026-02-13</summary>

- [x] Phase 1: Playable Foundation (3/3 plans) -- completed 2026-02-13
- [x] Phase 2: Engagement Layer (3/3 plans) -- completed 2026-02-13

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### v2.0 Advanced Training

**Milestone Goal:** The player develops self-awareness about her estimation patterns and takes ownership of her time training through contextual insights, self-created routines, and weekly reflections -- plus production polish (real sounds, XP tuning, iCloud backup).

- [x] **Phase 3: Data Foundation + CloudKit Backup** - All player data survives device replacement and all v1.0 features work after schema migration -- completed 2026-02-13
- [x] **Phase 4: Contextual Learning Insights** - Player can see which tasks she misjudges, in which direction, and whether she's improving -- completed 2026-02-13
- [ ] **Phase 5: Self-Set Routines + Production Audio** - Player can create her own quests and all sounds feel real
- [ ] **Phase 6: Weekly Reflection Summaries** - Player absorbs a weekly snapshot of her progress and patterns

## Phase Details

### Phase 3: Data Foundation + CloudKit Backup
**Goal**: Player's progress data is backed up to iCloud, protected against device loss, and the app upgrades from v1.0 without losing anything
**Depends on**: Phase 2 (v1.0 shipped)
**Requirements**: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008, REQ-009, REQ-010
**Success Criteria** (what must be TRUE):
  1. Player opens the upgraded app and all v1.0 data (XP, levels, streaks, sessions, routines) is intact -- nothing lost, nothing corrupted
  2. Settings screen shows iCloud backup status ("Synced" or last backup date) confirming data is protected
  3. All existing v1.0 features (estimation game, stats, parent setup, notifications) work identically after migration
  4. Parent-created routines, player sessions, and profile data persist correctly through the schema upgrade
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md -- Retroactive V1 schema, V2 schema with cloudID + defaults, lightweight migration plan, model typealiases
- [x] 03-02-PLAN.md -- CloudKit entitlements, sync monitor, ModelContainer init, cloudID queries, PlayerProfile deduplication, backup status UI

### Phase 4: Contextual Learning Insights
**Goal**: Player understands WHICH specific tasks she misjudges, in WHICH direction, and whether her estimates are getting better or worse over time
**Depends on**: Phase 3 (schema + CloudKit foundation)
**Requirements**: REQ-011, REQ-012, REQ-013, REQ-014, REQ-015, REQ-016, REQ-017, REQ-018, REQ-019, REQ-020, REQ-021, REQ-022
**Success Criteria** (what must be TRUE):
  1. Player can navigate to "My Patterns" from the home screen and see per-task insights grouped by routine -- showing bias direction, accuracy trend, and consistency for each task with enough history
  2. During gameplay, before making an estimate for a task with known patterns, the player sees a contextual reference hint ("Last 5 times: ~12 min") that informs without correcting
  3. Insights use curiosity-framed language ("Interesting -- you tend to...") that feels exploratory, not judgmental
  4. No insights appear for tasks with fewer than 5 non-calibration sessions -- the player never sees a misleading pattern from thin data
  5. Insight cards render consistently across the patterns screen and in-gameplay context
**Plans**: 2 plans

Plans:
- [x] 04-01-PLAN.md -- EstimationSnapshot value type + InsightEngine TDD (bias, trend, consistency, contextual hints)
- [x] 04-02-PLAN.md -- InsightCardView shared component, MyPatternsView + ViewModel, contextual gameplay hints, PlayerHomeView navigation

### Phase 5: Self-Set Routines + Production Audio
**Goal**: Player creates her own quests (transferring ownership from "parent's tool" to "my tool") and all game sounds feel polished and real
**Depends on**: Phase 3 (createdBy schema field)
**Requirements**: REQ-023, REQ-024, REQ-025, REQ-026, REQ-027, REQ-028, REQ-029, REQ-030, REQ-031, REQ-032, REQ-043, REQ-044, REQ-045, REQ-046
**Success Criteria** (what must be TRUE):
  1. Player taps "Create Quest" on the home screen and can build a routine from a template or from scratch, with guided steps for naming, adding tasks, and choosing days
  2. Player-created quests appear in her quest list with a visual distinction (badge/indicator) -- without parent routines being labeled as "assigned" or "parent-created"
  3. Parent dashboard does not show player-created routines, and parent cannot edit or delete them
  4. All 5 game sounds (estimate lock, reveal, level up, personal best, session complete) play real production audio that mixes with background music and respects the silent switch
  5. XP curve constants are exposed as tunable values ready for post-playtesting adjustment
**Plans**: 2 plans

Plans:
- [ ] 05-01-PLAN.md -- SchemaV3 with createdBy field, RoutineTemplateProvider, player guided creation flow, PlayerHomeView Create Quest button + star badge, RoutineListView parent filtering
- [ ] 05-02-PLAN.md -- AVAudioSession ambient config, production sound effects generation, XPConfiguration tunable struct, XPEngine + LevelCalculator refactor, build system updates

### Phase 6: Weekly Reflection Summaries
**Goal**: Player absorbs a brief weekly digest of her progress and patterns -- building a meta-awareness rhythm without it feeling like homework
**Depends on**: Phase 4 (InsightEngine for pattern highlights)
**Requirements**: REQ-033, REQ-034, REQ-035, REQ-036, REQ-037, REQ-038, REQ-039, REQ-040, REQ-041, REQ-042
**Success Criteria** (what must be TRUE):
  1. On the first app open of a new week, a dismissible reflection card appears at the top of the home screen showing quests completed, average accuracy, accuracy change vs prior week, best estimate, and streak context
  2. The reflection is absorbable in ~15 seconds on a single screen with no scrolling -- a "sports score card" not a report
  3. Streak context is framed positively ("5 of 7 days") and includes one pattern highlight sourced from InsightEngine
  4. If the player dismisses or misses a reflection, she can access it later from stats/history
  5. Reflections generate correctly even for weeks with gaps, computing summaries from whatever historical data exists
**Plans**: TBD

Plans:
- [ ] 06-01: WeeklyReflectionEngine + reflection view + home integration

## Progress

**Execution Order:** Phase 3 -> Phase 4 -> Phase 5 -> Phase 6
(Phase 5 depends on Phase 3 only, but sequenced after Phase 4 for solo developer flow. Phase 6 depends on Phase 4.)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|---------------|--------|-----------|
| 1. Playable Foundation | v1.0 | 3/3 | Complete | 2026-02-13 |
| 2. Engagement Layer | v1.0 | 3/3 | Complete | 2026-02-13 |
| 3. Data Foundation + CloudKit Backup | v2.0 | 2/2 | Complete | 2026-02-13 |
| 4. Contextual Learning Insights | v2.0 | 2/2 | Complete | 2026-02-13 |
| 5. Self-Set Routines + Production Audio | v2.0 | 0/2 | Not started | - |
| 6. Weekly Reflection Summaries | v2.0 | 0/1 | Not started | - |

---
*Roadmap created: 2026-02-12*
*v1.0 shipped: 2026-02-13*
*v2.0 roadmap created: 2026-02-13*
*Depth: quick | v2.0 Phases: 4 (3-6) | v2.0 Requirements: 46/46 mapped*
