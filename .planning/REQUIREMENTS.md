# Requirements: TimeQuest

**Defined:** 2026-02-14
**Core Value:** The player develops an accurate internal sense of time — the ability to predict how long things take and act on those predictions without external prompting.

## v3.0 Requirements

Requirements for v3.0 Adaptive & Connected. Each maps to roadmap phases.

### Adaptive Difficulty

- [ ] **DIFF-01**: Game automatically adjusts estimation accuracy thresholds per task based on the player's historical performance
- [ ] **DIFF-02**: Difficulty only progresses or holds — never decreases — so the player never feels like she's going backwards
- [ ] **DIFF-03**: Difficulty adjustment is completely invisible to the player (no difficulty labels, no notifications about changes)
- [ ] **DIFF-04**: XP rewards scale with difficulty level so harder thresholds earn proportionally more XP
- [ ] **DIFF-05**: SchemaV4 migration stores difficulty state per session for fair historical comparisons

### Spotify Integration

- [ ] **SPOT-01**: Parent can connect a Spotify account via OAuth from the parent dashboard
- [ ] **SPOT-02**: Parent can select a playlist to associate with a routine
- [ ] **SPOT-03**: When a routine starts, a duration-matched playlist is suggested/opened in the Spotify app
- [ ] **SPOT-04**: Player sees a "Now Playing" indicator during active quests without needing to leave the app
- [ ] **SPOT-05**: Post-routine summary shows song count as an intuitive time unit ("You got through 4.5 songs")
- [ ] **SPOT-06**: Spotify is completely optional — game works identically without it, no forced login or nagging
- [ ] **SPOT-07**: Both Spotify Free and Premium tiers work gracefully (no Premium-gating)

### Calendar Intelligence

- [ ] **CAL-01**: App can access the player's calendar (with permission) to detect school days vs. holidays vs. summer
- [ ] **CAL-02**: Routines auto-surface based on calendar context (school morning routine on school days, hidden on holidays)
- [ ] **CAL-03**: Calendar permission is optional with graceful denial — app works identically without it
- [ ] **CAL-04**: Calendar data is read-only and never persisted to SwiftData or synced via CloudKit
- [ ] **CAL-05**: Calendar suggestions are passive context ("Free afternoon today"), never proactive nagging

### UI/Brand Refresh

- [ ] **UI-01**: Design system with semantic color, typography, spacing, and icon tokens injected via SwiftUI environment
- [ ] **UI-02**: Dark mode as the primary design, light mode as fallback
- [ ] **UI-03**: All player-facing screens updated to the new visual language
- [ ] **UI-04**: Card-based layout with consistent corner radius, shadows, and material backgrounds
- [ ] **UI-05**: SF Rounded typography throughout for a friendly-modern teen feel
- [ ] **UI-06**: Updated celebration and accuracy reveal animations using the new design language

## Future Requirements

Deferred to v3.1+ release. Tracked but not in current roadmap.

### Adaptive Difficulty

- **DIFF-06**: Batch estimation mode unlocked at maximum difficulty level
- **DIFF-07**: Challenge mode for tasks the player has mastered

### Spotify Integration

- **SPOT-08**: Per-routine music preferences (different playlists for different routines)

### Calendar Intelligence

- **CAL-06**: Activity season awareness from multi-week calendar pattern analysis
- **CAL-07**: Smart notification timing based on calendar events

### UI/Brand Refresh

- **UI-07**: App name refresh (branding decision, separate from engineering)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Visible difficulty level display | Creates anxiety, externalizes what should be invisible |
| Player-selectable difficulty | She'll game the system or feel pressured |
| Music during estimation phase | Distracts from cognitive estimation task |
| Spotify Premium gate | Excludes Free users |
| Calendar write access | Feels like surveillance |
| Full calendar display | TimeQuest is not a calendar app |
| Customizable themes | Get one default right; theme picker adds scope for no core value |
| Avatar system | Massive scope, not core to time perception training |
| Animated backgrounds | Battery drain, visual distraction from content |
| Skeuomorphic gamification (coins, gems, treasure chests) | Patronizing for a teen; XP/levels already provide progression |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DIFF-01 | — | Pending |
| DIFF-02 | — | Pending |
| DIFF-03 | — | Pending |
| DIFF-04 | — | Pending |
| DIFF-05 | — | Pending |
| SPOT-01 | — | Pending |
| SPOT-02 | — | Pending |
| SPOT-03 | — | Pending |
| SPOT-04 | — | Pending |
| SPOT-05 | — | Pending |
| SPOT-06 | — | Pending |
| SPOT-07 | — | Pending |
| CAL-01 | — | Pending |
| CAL-02 | — | Pending |
| CAL-03 | — | Pending |
| CAL-04 | — | Pending |
| CAL-05 | — | Pending |
| UI-01 | — | Pending |
| UI-02 | — | Pending |
| UI-03 | — | Pending |
| UI-04 | — | Pending |
| UI-05 | — | Pending |
| UI-06 | — | Pending |

**Coverage:**
- v3.0 requirements: 23 total
- Mapped to phases: 0
- Unmapped: 23

---
*Requirements defined: 2026-02-14*
*Last updated: 2026-02-14 after initial definition*
