# Milestones

## v1.0 MVP (Shipped: 2026-02-13)

**Phases completed:** 2 phases, 6 plans, 13 tasks
**Timeline:** 2 days (2026-02-12 → 2026-02-13)
**Codebase:** 46 Swift files, 3,575 LOC
**Git range:** fa282fd → 9902b97 (23 commits, 9 feat commits)

**Key accomplishments:**
1. Complete estimation-first gameplay loop — player estimates task durations before doing them, performs tasks without a visible clock, and receives curiosity-framed accuracy feedback
2. Hidden parent setup with PIN gate — parent configures real routines (school mornings, activities) behind triple-tap gesture; player UI shows zero evidence of parent involvement
3. XP/leveling progression system — accuracy-based XP (never speed-based), concave level curve for fast early levels, "Time Sense" level display
4. Graceful streak tracking — daily participation streaks that pause on skipped days (never reset, never punish)
5. Sensory polish — haptic feedback on estimation and reveal, SpriteKit particle celebrations for milestones, game-framed notifications with player-controlled preferences
6. Accuracy trend charts and personal bests — Swift Charts line graph showing improvement over time, closest-ever estimate tracking per task

**Delivered:** A complete iOS game that trains time perception in a 13-year-old with time blindness through estimation practice, progressive difficulty via calibration, and sustained engagement through XP/leveling/streaks/charts — all without visible clocks, lectures about time blindness, or parental surveillance.

---


## v2.0 Advanced Training (Shipped: 2026-02-14)

**Phases completed:** 4 phases (3-6), 8 plans, 19 tasks
**Timeline:** 2 days (2026-02-13 → 2026-02-14)
**Codebase:** 66 Swift files, 6,211 LOC (+2,636 LOC, +20 files from v1.0)
**Git range:** 3a2d8b0 → a05ad47 (27 feat commits)

**Key accomplishments:**
1. iCloud backup via CloudKit — SchemaV1→V2→V3 lightweight migrations, CloudKitSyncMonitor, graceful fallback to local-only, PlayerProfile deduplication with sentinel cloudID pattern
2. Per-task learning insights — InsightEngine pure domain engine detecting estimation bias (over/underestimate), accuracy trend (linear regression), and consistency (coefficient of variation), with "My Patterns" dedicated screen
3. In-gameplay contextual hints — before estimating a familiar task, player sees "Last 5 times: ~12 min" reference data that informs without correcting
4. Player-created quests — guided multi-step creation flow with 3 templates (Homework, Friend's House, Activity Prep), orange star badge distinction, parent dashboard filtered to exclude player routines
5. Production audio — AVAudioSession .ambient config, synthesized sound effects for 5 game events, XPConfiguration struct exposing 7 tunable constants
6. Weekly reflection summaries — "sports score card" showing quests completed, accuracy, accuracy delta, best estimate, most improved task, positive streak framing, InsightEngine pattern highlight, dismissible card on home screen with "Weekly Recaps" history in stats

**Delivered:** Self-awareness layer for time perception training — the player now sees her estimation patterns, creates her own quests, and absorbs weekly progress digests, transforming TimeQuest from "parent's tool" into "my game" with iCloud-backed data and production-quality audio.

---
