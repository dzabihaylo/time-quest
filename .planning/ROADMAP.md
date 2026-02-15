# Roadmap: TimeQuest

## Milestones

- v1.0 MVP -- Phases 1-2 (shipped 2026-02-13)
- v2.0 Advanced Training -- Phases 3-6 (shipped 2026-02-14)
- v3.0 Adaptive & Connected -- Phases 7-10 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-2) -- SHIPPED 2026-02-13</summary>

- [x] Phase 1: Playable Foundation (3/3 plans) -- completed 2026-02-13
- [x] Phase 2: Engagement Layer (3/3 plans) -- completed 2026-02-13

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>v2.0 Advanced Training (Phases 3-6) -- SHIPPED 2026-02-14</summary>

- [x] Phase 3: Data Foundation + CloudKit Backup (2/2 plans) -- completed 2026-02-13
- [x] Phase 4: Contextual Learning Insights (2/2 plans) -- completed 2026-02-13
- [x] Phase 5: Self-Set Routines + Production Audio (2/2 plans) -- completed 2026-02-14
- [x] Phase 6: Weekly Reflection Summaries (2/2 plans) -- completed 2026-02-14

Full details: `.planning/milestones/v2.0-ROADMAP.md`

</details>

### v3.0 Adaptive & Connected (In Progress)

**Milestone Goal:** Make TimeQuest a daily-use app that adapts to the player's skill level, integrates with her real schedule and music, and looks like something a teen in 2026 would actually want on her phone.

- [x] **Phase 7: Schema Evolution + Adaptive Difficulty** - Game automatically calibrates challenge level per task based on accuracy history
- [x] **Phase 8: Calendar Intelligence** - Routines surface and hide based on the player's real-world schedule
- [ ] **Phase 9: Spotify Integration** - Music serves as an intuitive, hands-free time cue during routines
- [ ] **Phase 10: UI/Brand Refresh** - Every screen looks and feels like a modern teen app

## Phase Details

### Phase 7: Schema Evolution + Adaptive Difficulty
**Goal**: The game invisibly adapts to the player's improving skill -- tighter accuracy thresholds, scaled XP rewards, and fair historical comparisons -- without the player ever seeing a "difficulty" label
**Depends on**: Phase 6 (v2.0 complete)
**Requirements**: DIFF-01, DIFF-02, DIFF-03, DIFF-04, DIFF-05
**Success Criteria** (what must be TRUE):
  1. A player who consistently estimates accurately sees her accuracy thresholds tighten over subsequent sessions for that specific task -- the game gets harder without telling her
  2. A player having a rough streak never sees her difficulty decrease -- the game holds steady or progresses, never regresses
  3. The player sees no UI indication that difficulty exists -- no labels, no notifications, no settings related to difficulty level
  4. A player at a higher difficulty level earns noticeably more XP per quest than she did at the starting level for equivalent accuracy
  5. Historical accuracy comparisons in insights and charts remain fair -- earlier sessions scored under easier thresholds are not retroactively distorted
**Plans:** 2 plans -- completed 2026-02-14

Plans:
- [x] 07-01: SchemaV4 + DifficultyConfiguration + DifficultySnapshot -- completed 2026-02-14
- [x] 07-02: AdaptiveDifficultyEngine + game flow wiring + tests -- completed 2026-02-14

### Phase 8: Calendar Intelligence
**Goal**: The app knows the player's real schedule and passively surfaces the right routines on the right days -- school mornings on school days, hidden on holidays -- without the player managing anything
**Depends on**: Phase 7 (schema must be stable)
**Requirements**: CAL-01, CAL-02, CAL-03, CAL-04, CAL-05
**Success Criteria** (what must be TRUE):
  1. On a school day, the player opens the app and sees her school morning routine surfaced automatically without manual selection
  2. On a holiday or summer day, school-specific routines are hidden and the player sees only relevant options (activities, player-created quests)
  3. A player who denies calendar permission experiences the app identically to v2.0 -- no broken screens, no nagging prompts, no missing features
  4. Calendar data is never stored in the app's database or synced to iCloud -- it is read fresh each time and used only for immediate context
  5. Any calendar-derived suggestions use passive language ("Free afternoon today") rather than directive language ("Time for a quest!")
**Plans:** 3 plans -- completed 2026-02-15

Plans:
- [x] 08-01: SchemaV5 + CalendarContextEngine -- completed 2026-02-15
- [x] 08-02: CalendarService EventKit wrapper -- completed 2026-02-15
- [x] 08-03: Parent calendar UI + PlayerHomeView filtering -- completed 2026-02-15

### Phase 9: Spotify Integration
**Goal**: Music becomes an intuitive time cue -- the player starts a routine, a duration-matched playlist plays in Spotify, and she develops a feel for "how many songs" things take without checking a clock
**Depends on**: Phase 7 (schema must be stable; Spotify fields in SchemaV4)
**Requirements**: SPOT-01, SPOT-02, SPOT-03, SPOT-04, SPOT-05, SPOT-06, SPOT-07
**Success Criteria** (what must be TRUE):
  1. A parent can connect a Spotify account from the parent dashboard through a standard OAuth flow and see confirmation that it worked
  2. A parent can browse and select a playlist to associate with any routine
  3. When the player starts a routine that has a linked playlist, the Spotify app opens with a duration-matched playlist ready to play -- no manual song selection needed
  4. During an active quest, the player sees a minimal "Now Playing" indicator without leaving the app
  5. After completing a routine, the summary shows song count as a time unit ("You got through 4.5 songs") alongside the standard time display
  6. A player whose family has no Spotify or who uses Spotify Free tier experiences the full game with zero degradation -- Spotify is purely additive
**Plans:** 4 plans

Plans:
- [ ] 09-01-PLAN.md -- SchemaV6 + SpotifyModels + SpotifyPlaylistMatcher domain engine
- [ ] 09-02-PLAN.md -- SpotifyAuthManager OAuth PKCE + SpotifyAPIClient service layer
- [ ] 09-03-PLAN.md -- Parent UI: Spotify settings, playlist picker, routine editor integration
- [ ] 09-04-PLAN.md -- Player UI: playback launch, Now Playing indicator, song count summary

### Phase 10: UI/Brand Refresh
**Goal**: Every player-facing screen uses a cohesive, modern visual language that a teen in 2026 would consider worth having on her phone -- dark-first design, rounded typography, card-based layouts, polished animations
**Depends on**: Phases 7-9 (all features exist; theme applied to final view set in one pass)
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06
**Success Criteria** (what must be TRUE):
  1. A design system with semantic tokens (colors, typography, spacing, icons) is injected via SwiftUI environment and consumed by all views -- no hardcoded style values remain in player-facing screens
  2. The app defaults to dark mode and looks intentionally designed in dark mode (not just inverted light mode), with a correct light mode fallback
  3. All player-facing screens -- home, quest flow, stats, reflections, settings, and any new screens from Phases 7-9 -- use the updated visual language consistently
  4. Celebration animations and accuracy reveal effects use the new design tokens and feel cohesive with the refreshed screens
**Plans**: TBD

Plans:
- [ ] 10-01: TBD
- [ ] 10-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 7 -> 8 -> 9 -> 10

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|---------------|--------|-----------|
| 1. Playable Foundation | v1.0 | 3/3 | Complete | 2026-02-13 |
| 2. Engagement Layer | v1.0 | 3/3 | Complete | 2026-02-13 |
| 3. Data Foundation + CloudKit Backup | v2.0 | 2/2 | Complete | 2026-02-13 |
| 4. Contextual Learning Insights | v2.0 | 2/2 | Complete | 2026-02-13 |
| 5. Self-Set Routines + Production Audio | v2.0 | 2/2 | Complete | 2026-02-14 |
| 6. Weekly Reflection Summaries | v2.0 | 2/2 | Complete | 2026-02-14 |
| 7. Schema Evolution + Adaptive Difficulty | v3.0 | 2/2 | Complete | 2026-02-14 |
| 8. Calendar Intelligence | v3.0 | 3/3 | Complete | 2026-02-15 |
| 9. Spotify Integration | v3.0 | 0/4 | Planned | - |
| 10. UI/Brand Refresh | v3.0 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-12*
*v1.0 shipped: 2026-02-13*
*v2.0 shipped: 2026-02-14*
*v3.0 roadmap created: 2026-02-14*
