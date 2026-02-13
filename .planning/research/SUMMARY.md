# Project Research Summary

**Project:** TimeQuest v2.0 -- Advanced Training Features
**Domain:** iOS time-perception training game with contextual learning insights, self-set routines, real sound assets, iCloud backup, and weekly reflections
**Researched:** 2026-02-13
**Confidence:** MEDIUM

## Executive Summary

TimeQuest v2.0 extends the successful v1.0 MVP (46 files, 3,575 LOC) with ownership-transfer features that shift the player from passive training to active self-awareness. Research reveals an architecturally ideal scenario: every v2.0 feature maps to capabilities already latent in the v1.0 stack. No third-party dependencies are needed. The core additions are CloudKit framework integration for iCloud backup, new pure domain engines for pattern analysis and reflection generation, schema evolution to support self-set routines, and real audio asset replacements. The v1.0 architecture was explicitly designed to accommodate these additions through its repository abstraction, pure domain engine pattern, and value-type editing approach.

The recommended approach is CloudKit-first migration followed by independent feature buildouts. CloudKit compatibility requires adding property defaults to all SwiftData models (a lightweight migration), which must happen before any other work begins. This migration is the critical path dependency. Once complete, three feature streams can proceed in parallel: (1) pattern analysis and contextual insights (dependency root for weekly reflections), (2) self-set routines with templates (ownership transfer), and (3) sound asset replacement (polish). Weekly reflections integrate insights and session data as a capstone feature. The pure-domain-engine pattern allows pattern analysis and reflection generation to be built and tested independently of UI or persistence concerns.

The primary risk is CloudKit sync complexity. SwiftData's built-in CloudKit support handles the infrastructure, but four critical pitfalls must be prevented: (1) non-optional properties without defaults cause sync failures, (2) schema migration can corrupt v1.0 data if not properly versioned, (3) duplicate records and merge conflicts require stable identity and deduplication strategy, and (4) relationship predicates based on `persistentModelID` break across devices. Prevention requires: adding defaults to all model properties in a versioned migration, implementing stable custom identifiers for all models, establishing deduplication logic for the singleton `PlayerProfile`, and replacing `persistentModelID`-based queries with custom ID queries. These are well-understood challenges with documented solutions. Testing on real devices with real iCloud accounts is mandatory before ship.

## Key Findings

### Recommended Stack

v2.0 requires zero new third-party dependencies. Every new capability maps to an Apple first-party framework that ships with iOS 17 SDK. The only framework addition is CloudKit (via SwiftData's `ModelConfiguration(cloudKitDatabase: .automatic)`), which enables iCloud backup through configuration rather than architectural change. Pattern analysis, reflection generation, and routine templates are pure Swift domain engines with zero framework dependencies, following the established v1.0 pattern. Real sound assets replace placeholders through file swap with no code changes. The existing stack (SwiftUI, SwiftData, SpriteKit, Swift Charts, AVFoundation, UserNotifications, iOS 17.0+, Swift 6.0) is validated and unchanged.

**Core technologies:**
- **CloudKit framework** (via SwiftData): iCloud backup/sync of all player data — integrated through `ModelConfiguration`, not manual CloudKit API usage. SwiftData handles schema mapping and conflict resolution.
- **New SwiftData models**: `WeeklyReflection` for persisted summaries, schema additions to `Routine` (`createdBy: String`) and `PlayerProfile` (`lastReflectionViewedDate: Date?`) — lightweight migrations with defaults.
- **New domain engines** (pure Swift): `InsightEngine` (pattern detection), `WeeklyReflectionEngine` (weekly summary generation), `RoutineTemplateProvider` (static routine templates) — follow `TimeEstimationScorer` and `XPEngine` pattern, zero dependencies, fully testable.
- **Real audio assets**: Replace 5 placeholder .wav files with production sounds from freesound.org (CC0) — .wav format, under 1MB total, zero code changes. AVAudioSession configuration added for `.ambient` category (mix with background music, respect silent switch).

**Critical CloudKit constraints:**
All SwiftData models must have property defaults or be optional for CloudKit compatibility. Current models violate this (e.g., `Routine.name: String` has no default). Adding defaults is a lightweight migration but must be the first v2.0 task. Existing models already use optional relationships and cascade deletes, which are CloudKit-compatible. Array properties like `Routine.activeDays: [Int]` should be verified for CloudKit round-trip correctness.

### Expected Features

v2.0 transforms TimeQuest from a training tool into a self-awareness platform. Research identifies three feature tiers based on v1.0's shipped foundation and expert patterns for gamified skill-building apps targeting teens with ADHD.

**Must have (table stakes):**
- **iCloud backup of progress data** — After weeks of daily play, losing XP/levels/history to device replacement is devastating for a 13-year-old. A backup status indicator ("Synced" / "Last backed up: [date]") provides parent peace-of-mind.
- **Real sound assets** — v1.0 shipped with placeholder .wav files (all 8,864 bytes, identical size). Placeholder audio feels broken, not unfinished. Replacing 5 core sounds (estimate lock, reveal, level up, personal best, session complete) is zero-complexity, high-polish.
- **XP curve tuning** — After weeks of play, the concave curve (baseXP * level^1.5) requires validation against actual play data. This is a constants change, not a feature build.

**Should have (differentiators):**
- **Contextual learning insights** — Per-task pattern detection ("You underestimate packing by 4 minutes," "Shower estimates improving every week"). Shows WHICH tasks she misjudges and in WHICH direction. More actionable than aggregate accuracy. Includes in-gameplay contextual nudges before estimation (reference data, not corrections), "My Patterns" dedicated screen, consistency scores, and trend detection per task.
- **Self-set routines with guided creation** — Player creates her own routines alongside parent-configured ones. Transfers ownership from "parent's tool" to "my tool." Templates provide starting points ("Homework session," "Getting ready for a friend's house") with full customization. Visual distinction between player-created and parent-created routines without revealing parent routines as "assigned."
- **Weekly reflection summaries** — Brief weekly digest (quests completed, average accuracy, accuracy change, best estimate, streak context, pattern highlight). Creates meta-awareness rhythm. Delivered as dismissible card at top of PlayerHomeView, not push notification. Target 15 seconds to absorb — "sports score card" not "quarterly business review."

**Anti-features (explicitly avoid):**
- AI-generated coaching messages (teens detect and despise inauthentic positivity)
- Comparison to "normal" time (introduces external judgment, reveals parent reference)
- Parent insight reports (surveillance breaks trust)
- Achievement badges system (scope creep, XP/levels already provide progression)
- Streak multipliers (create anxiety, break "pause never reset" design)
- Home screen widget (defer to v3.0)

**Feature dependencies:**
`EstimationSnapshot` (shared value type) → `InsightEngine` → contextual insights + weekly reflections. `Routine.createdBy` → self-set routines. CloudKit defaults → iCloud backup. Sound assets and XP tuning are independent. InsightEngine is the dependency root — build it first.

### Architecture Approach

v2.0 integrates through established v1.0 patterns with zero architectural disruption. The existing repository abstraction, pure domain engines, value-type editing pattern, and composition root remain unchanged. New domain engines (`InsightEngine`, `WeeklyReflectionEngine`, `RoutineTemplateProvider`) follow the pure-struct-with-static-methods pattern — zero framework imports, value-type inputs/outputs, no SwiftData dependencies. ViewModels bridge between SwiftData models and domain engines using a shared `EstimationSnapshot` value type that decouples business logic from persistence. CloudKit integration occurs at the ModelContainer configuration level (single-line change) with model property defaults added for compatibility. Schema changes are additive only (new properties with defaults, new optional properties) to ensure lightweight migration.

**Major components:**
1. **Pattern Analysis Layer** — `InsightEngine` (pure domain) takes `[EstimationSnapshot]` and returns `[Insight]`. `InsightsViewModel` queries `SessionRepository`, maps to snapshots, calls engine, publishes results. `MyPatternsView` and in-gameplay contextual hints consume insights. No new repositories needed.
2. **Self-Set Routine Creation** — Reuses `RoutineEditState` value type and repository save logic. New `PlayerRoutineEditorViewModel` auto-sets `createdBy = "player"` and `name = displayName`. `RoutineTemplateProvider` provides static template data. Separate view for player-facing language/templates; shared data types and persistence.
3. **Weekly Reflection Engine** — `WeeklyReflectionEngine` (pure domain) aggregates session data and reuses `InsightEngine` for pattern highlights. Computed lazily on app open (no background scheduler needed). Optional `WeeklyReflectionSummary` model for historical persistence (defer if not immediately needed). Displayed as dismissible card on `PlayerHomeView`.
4. **CloudKit Backup Infrastructure** — `ModelConfiguration(cloudKitDatabase: .automatic)` enables sync. All models get property-level defaults. Stable `cloudID: String = UUID().uuidString` added for deduplication. `PlayerProfile` uses sentinel ID ("player-profile-singleton") for singleton enforcement across devices. Relationship queries replaced with custom ID queries (no `persistentModelID` usage).

**Integration touchpoints:**
- `GameSessionViewModel` adds `contextualHint: Insight?` property for in-gameplay nudges
- `PlayerHomeView` adds navigation to MyPatternsView, weekly reflection banner, "Create Quest" button
- `TimeQuestApp` registers new models and CloudKit configuration
- `SoundManager` receives AVAudioSession configuration for `.ambient` category
- `NotificationManager` adds weekly reflection scheduling (optional)

**File growth:** ~10 new Swift files, ~8 modified files. Estimated ~930 LOC addition (3,575 → ~4,505 LOC, +25% codebase growth).

### Critical Pitfalls

Research identified 15 domain-specific pitfalls across severity tiers. The five critical pitfalls (data loss, architectural rework, or v1.0 breakage) must be prevented in Phase 1.

1. **CloudKit requires all properties to be optional or have defaults — models are not ready** — Current models have non-optional properties without defaults (`Routine.name`, `TaskEstimation.taskDisplayName`, etc.). Enabling CloudKit without fixing causes crashes, silent sync failures, or records uploading with nil values. Prevention: Audit every @Model property and add sensible defaults (`var name: String = ""`, `var estimatedSeconds: Double = 0`). Test CloudKit sync on real device with real iCloud account before shipping. This is the first v2.0 task.

2. **Schema migration corrupts existing v1.0 data** — Adding defaults, new fields (`createdBy`, `lastReflectionViewedDate`), or restructuring properties triggers migration. Without proper versioning, SwiftData fails to open existing store and either crashes or creates new empty store, erasing all v1.0 data. Prevention: Introduce `VersionedSchema` retroactively defining v1.0 as `SchemaV1`, define `SchemaV2` with v2.0 changes, create `SchemaMigrationPlan`. Only make lightweight migration changes (add properties with defaults, add optional properties, add new models). Never rename or remove properties. Test migration with real v1.0 data. This is the foundation all v2.0 features depend on.

3. **CloudKit sync creates duplicate records and merge conflicts** — Models lack stable unique identity beyond device-local `persistentModelID`. Two devices could each create a `PlayerProfile`, sync would deliver both. Last-writer-wins merge loses XP/streak data. Prevention: Add stable `cloudID: String = UUID().uuidString` to all models. Use sentinel ID for singleton `PlayerProfile`. Implement post-sync deduplication. For `PlayerProfile.totalXP`, use max(localXP, remoteXP) merge (XP only goes up). Design deduplication strategy alongside CloudKit enablement.

4. **Enabling CloudKit breaks @Query predicates on relationships** — `SessionRepository.fetchSessions(for:)` filters by `$0.routine?.persistentModelID == routineID`. With CloudKit, `persistentModelID` is not stable across devices. Synced routines have different IDs on receiving device; predicate fails to match sessions to routines. Prevention: Replace `persistentModelID`-based queries with stable custom ID queries. Add `routineCloudID: String` on `GameSession` as denormalized lookup key. Test every `FetchDescriptor` and `#Predicate` against CloudKit-backed store.

5. **Analytics/pattern detection queries cause UI stutter on growing dataset** — Contextual insights and weekly reflections require fetching ALL `TaskEstimation` records, grouping, computing aggregates. Entire repository layer is @MainActor. After weeks/months of use, synchronous main-thread queries cause visible UI freezes. Prevention: Create pure domain engine that takes value types (not @Model objects), run heavy fetch + computation on background ModelActor, cache computed insights (invalidate on session completion), set query limits ("last 90 days" not "all time"). Profile with Instruments before/after, budget: patterns screen under 300ms.

**Additional moderate pitfalls:**
- Player-created routines contaminating parent dashboard (add `createdByPlayer: Bool`, filter queries)
- Replacing placeholder sounds breaking audio session (configure `.ambient` category, use .caf format, test with background music)
- Weekly reflection needing reliable scheduler (compute lazily on app open, persist summaries)
- Contextual insights generating misleading patterns from small samples (minimum 5 sessions, exclude calibration, confidence language)
- iCloud exposing parent config to shared family account (verify single-device backup-only design)

## Implications for Roadmap

Based on research, v2.0 should be structured as four sequential phases driven by dependency and risk analysis. CloudKit migration is the critical path that unblocks all other work. Pattern analysis is the dependency root for two downstream features. Self-set routines and sound replacement are independent. Weekly reflections integrate everything as a capstone.

### Phase 1: Data Foundation + CloudKit Backup

**Rationale:** Schema migration and CloudKit compatibility must come first. Every v2.0 feature requires model changes; those changes must not corrupt v1.0 data (Pitfall 2). CloudKit requires property defaults (Pitfall 1). Doing migration and CloudKit as a single phase ensures all subsequent feature data is synced from day one. This phase has the highest risk (data loss) and highest confidence (well-documented constraints).

**Delivers:**
- Versioned schema (SchemaV1 retroactive, SchemaV2 with v2.0 changes)
- SchemaMigrationPlan (V1 → V2)
- Property defaults on all models (CloudKit compatible)
- New model properties: `Routine.createdBy`, `PlayerProfile.lastReflectionViewedDate`, stable `cloudID` on all models
- CloudKit ModelConfiguration enabled
- iCloud + CloudKit entitlements
- Backup status indicator in settings

**Addresses features:**
- iCloud backup of progress data (table stakes)
- Foundation for all v2.0 features (enables schema changes)

**Avoids pitfalls:**
- Pitfall 1 (CloudKit property defaults)
- Pitfall 2 (schema migration corruption)
- Pitfall 3 (duplicate records — stable cloudID added)
- Pitfall 4 (relationship predicates — replace persistentModelID queries)
- Pitfall 10 (parent config exposure — document single-device backup-only design)

**Testing requirements:**
- Test migration with real v1.0 data (build v1.0, populate, upgrade to v2.0)
- Test CloudKit sync on real device with real iCloud account
- Verify existing v1.0 features work with defaults
- Verify all repository queries work with CloudKit-backed store

**Research flag:** MEDIUM — SwiftData + CloudKit constraints are well-documented but exact behavior with relationships needs validation during implementation. Test early and often on real devices.

### Phase 2: Contextual Learning Insights

**Rationale:** Pattern analysis is the dependency root for weekly reflections (Phase 4 reuses `InsightEngine` types and computation). Building the pure domain engine first unlocks both features. This is the most complex new domain code and benefits from early testing. With CloudKit enabled (Phase 1), the analytics engine automatically handles both local and synced data. This phase is read-only (queries existing data) with no schema changes beyond Phase 1.

**Delivers:**
- `EstimationSnapshot` value type (shared domain type)
- `InsightEngine` pure domain engine (pattern detection, bias detection, trend analysis, consistency scoring)
- `InsightsViewModel` (bridges SwiftData to domain)
- `InsightCardView` shared component
- `MyPatternsView` (dedicated patterns screen)
- In-gameplay contextual hints (modify `GameSessionViewModel`, `EstimationInputView`)
- Navigation from `PlayerHomeView`/`PlayerStatsView` to MyPatternsView

**Addresses features:**
- Contextual learning insights (differentiator)
- Per-task bias detection
- Trend detection per task
- Consistency scores
- "My Patterns" screen

**Avoids pitfalls:**
- Pitfall 5 (UI stutter — pure domain engine, background computation, caching strategy)
- Pitfall 9 (small-sample misleading insights — minimum 5 sessions, exclude calibration, confidence language)
- Pitfall 12 (analytics fields breaking migration — compute dimensions at query time, no new stored fields)

**Testing requirements:**
- Unit tests for InsightEngine (pure functions, fast)
- Test with real estimation history (hundreds of records)
- Profile with Instruments (Time Profiler) — patterns screen under 300ms
- Test contextual hints do not interrupt gameplay flow

**Research flag:** LOW — Pattern detection is pure Swift math on existing data types. No framework uncertainty. Standard statistical computations well-understood.

### Phase 3: Self-Set Routines + Sound Assets (Parallel)

**Rationale:** Self-set routines depend on `createdBy` schema change (completed in Phase 1) but are otherwise independent of insights. Sound replacement is completely independent of all features. Both can be built in parallel (or sequentially if solo developer). Both are lower risk than CloudKit and analytics. Self-set routines are the ownership transfer milestone. Sound assets are table-stakes polish.

**Delivers:**
- `RoutineTemplateProvider` domain engine (static template data)
- `RoutineCreator` enum (creator type)
- `PlayerRoutineEditorViewModel` (reuses `RoutineEditState`)
- `PlayerRoutineEditorView` (player-facing language, templates, validation)
- "Create Quest" button on `PlayerHomeView`
- Visual distinction for player-created quests (badge/indicator)
- Updated `RoutineEditorViewModel` to set `createdBy = "parent"`
- Filtered queries: parent dashboard excludes player routines
- **Sound assets:** 5 production-quality .wav files (freesound.org CC0), AVAudioSession `.ambient` configuration, under 1MB total

**Addresses features:**
- Self-set routines with guided creation (differentiator)
- Routine templates
- Player vs parent routine distinction
- Real sound assets (table stakes)

**Avoids pitfalls:**
- Pitfall 6 (player/parent data contamination — `createdByPlayer` flag, filtered queries, separated UI)
- Pitfall 7 (audio session misconfiguration — `.ambient` category, .wav/.caf format, test with background music)
- Pitfall 11 (sound bundle bloat — AAC-encoded .caf if needed, mono, target under 1MB)
- Pitfall 13 (creation UI too open/restrictive — guided templates + validation guardrails)
- Pitfall 15 (@Query bypass — update @Query filter alongside repository)

**Testing requirements:**
- Player can create routine from template
- Player routine appears in quest list
- Parent dashboard does not show player routines
- Parent cannot edit player routines
- Sounds play correctly with background music (Spotify, Apple Music)
- Sounds respect silent switch

**Research flag:** LOW — Reuses existing `RoutineEditState` pattern. Sound asset replacement is file swap. Standard patterns, minimal uncertainty.

### Phase 4: Weekly Reflection Summaries

**Rationale:** Depends on `InsightEngine` from Phase 2 (reuses insight types for pattern highlights). Integrates session data and pattern analysis as capstone feature. Least critical feature (can slip if time-constrained). Benefits from having more estimation data to summarize (weeks of play).

**Delivers:**
- `WeeklyReflectionEngine` pure domain engine (aggregation logic)
- `WeeklyReflectionViewModel` (lazy computation on app open)
- `WeeklyReflectionView` (summary cards, streak context, pattern highlight)
- Reflection banner on `PlayerHomeView` (dismissible)
- Optional: `WeeklyReflectionSummary` model for historical persistence (defer if not needed)
- Optional: Weekly notification scheduling via `NotificationManager` (defer if not needed)

**Addresses features:**
- Weekly reflection summaries (differentiator)
- Weekly summary card
- Pattern highlight
- Streak context
- Delivery mechanism

**Avoids pitfalls:**
- Pitfall 8 (no reliable scheduler — lazy computation on app open, persisted reflection models)
- Pitfall 5 (UI stutter — same mitigation as Phase 2 insights)

**Testing requirements:**
- Weekly summary renders correctly from 7 days of sessions
- Computation completes under 300ms
- Historical reflections accessible if persistence added
- Reflection does not block app launch

**Research flag:** LOW — Reuses `InsightEngine` and `EstimationSnapshot`. Standard aggregation logic. No framework uncertainty.

### Phase Ordering Rationale

- **CloudKit first:** Schema migration is the critical path. All features depend on model changes. Doing CloudKit early means all feature data is synced from day one, avoiding "partially backed up" states. CloudKit is infrastructure that doesn't affect feature code.
- **Insights before reflections:** `InsightEngine` is reused by weekly reflections. Building the dependency root first unlocks downstream features. The shared `EstimationSnapshot` type is used by both engines.
- **Routines + sounds parallel with insights:** Self-set routines are independent of insights (different code paths, different ViewModels). Sound assets are independent of everything. If solo developer, do after insights; if parallel work possible, overlap with Phase 2.
- **Reflections last:** Integrates everything (sessions + insights). Least critical for v2.0 success. Can slip without breaking other features.

**Dependency graph:**
```
Phase 1 (CloudKit + schema) → Phase 2 (insights) → Phase 4 (reflections)
Phase 1 (CloudKit + schema) → Phase 3 (routines + sounds)
```

**XP curve tuning:** Not a phase — it's a constants change pending playtesting data. Expose tunable values during any phase, adjust after real play sessions.

### Research Flags

Phases with deeper research needs during planning:

- **Phase 1 (CloudKit):** MEDIUM flag — SwiftData + CloudKit constraints are well-documented (WWDC 2023-2024, Apple docs), but exact behavior with cascade deletes, array properties (`activeDays: [Int]`), and merge conflict resolution should be verified against current iOS 17.4+ behavior. Web search was unavailable during research; recommendations based on training data through May 2025. Test on real device early to validate assumptions.

- **Phase 2 (Insights):** LOW flag — Pattern detection is pure Swift math. Statistical thresholds (minimum sample size, confidence intervals) are well-understood. Performance profiling needed but no framework uncertainty. Skip additional research.

Phases with standard patterns (skip research-phase):

- **Phase 3 (Routines):** Standard SwiftUI CRUD with value-type editing pattern already established in v1.0. Sound asset replacement is file swap. No research needed.

- **Phase 4 (Reflections):** Reuses Phase 2 engines and patterns. Standard aggregation logic. No research needed.

**Overall:** Phase 1 is the only phase with meaningful research uncertainty, and it's well-bounded (CloudKit + SwiftData constraints are thoroughly documented). The rest of v2.0 builds on patterns already validated in v1.0.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | CloudKit via SwiftData is well-documented (WWDC 2023-2024) but exact behavior with relationships and array properties needs validation. Web/Context7 unavailable during research. All other stack elements (SwiftData, SwiftUI, domain engines) are HIGH confidence based on v1.0 codebase analysis. |
| Features | HIGH | Feature recommendations based on existing v1.0 data model analysis, established patterns for gamified skill-training apps, and ADHD-friendly design principles. All v2.0 features are read-side computations over existing data or reuse established patterns. |
| Architecture | HIGH | Architecture approach directly derived from v1.0 codebase analysis (46 files read in full). Pure domain engine pattern, repository abstraction, value-type editing, and composition root are shipped patterns with high confidence. Integration points clearly mapped. |
| Pitfalls | MEDIUM to HIGH | CloudKit pitfalls (1-4) are well-documented failure modes with clear prevention strategies (HIGH confidence). Analytics pitfalls (5, 9, 12) are architectural concerns based on codebase analysis (MEDIUM confidence). Sound and UX pitfalls (7, 11, 13) are well-understood (HIGH confidence). Overall: pitfalls are known, mitigations are standard. |

**Overall confidence:** MEDIUM

The medium rating is driven entirely by CloudKit integration uncertainty (SwiftData + CloudKit exact API syntax and edge case behavior) due to web search being unavailable during research. All other aspects of v2.0 have HIGH confidence: the feature design builds on validated v1.0 patterns, the architecture reuses existing abstractions, and the pitfalls are well-documented with known mitigations. The CloudKit uncertainty is well-bounded and can be resolved through testing on real devices early in Phase 1.

### Gaps to Address

**CloudKit + SwiftData specifics:**
- **Gap:** Exact entitlement configuration for SwiftData-managed CloudKit (vs. manual CloudKit) should be verified. Training data suggests only `CloudKit` service needed, not `CloudDocuments`, but this should be validated against current Xcode documentation.
- **How to handle:** Test CloudKit enablement on real device in Phase 1 immediately. Apple Developer Forums and WWDC session transcripts (2023-2024) cover this extensively.

**Array property CloudKit compatibility:**
- **Gap:** `Routine.activeDays: [Int]` is an array of primitives. Codable arrays should serialize correctly to CloudKit, but round-trip behavior should be verified (especially with empty arrays and arrays containing 0).
- **How to handle:** Test CloudKit sync with routines containing various `activeDays` values (empty, single value, 7 days) during Phase 1.

**`persistentModelID` CloudKit stability:**
- **Gap:** Training data indicates `persistentModelID` is device-local and not stable across CloudKit sync (inherited from Core Data behavior). SwiftData documentation should be checked to see if this has changed.
- **How to handle:** Phase 1 testing should verify this by syncing a routine from device A to device B and checking if `persistentModelID` matches. If unstable, implement custom `cloudID` as planned.

**XP curve tuning data:**
- **Gap:** Optimal XP curve requires actual play data from v1.0 usage. Research cannot determine this in advance.
- **How to handle:** Not a blocker. Expose tunable constants (`baseXP`, `exponent` in `XPEngine`), gather play data, tune during Phase 2-4 as background task. Ship v2.0 with v1.0 curve, iterate post-launch if needed.

**Performance profiling for analytics:**
- **Gap:** Exact query performance (fetch all TaskEstimations, group by task, compute aggregates) depends on device hardware and data volume. Cannot be determined from static analysis.
- **How to handle:** Profile with Instruments (Time Profiler) during Phase 2 with realistic data volume (100-500 TaskEstimation records). Set budget: MyPatternsView appearance under 300ms. Add caching if needed.

**Weekly reflection persistence necessity:**
- **Gap:** Research recommends optional `WeeklyReflectionSummary` model for historical reflection persistence. Whether this is needed depends on UX decision: does player want to review "3 weeks ago" reflections?
- **How to handle:** Defer during Phase 4. Start with lazy computation (no persistence). If product owner wants history access, add `WeeklyReflectionSummary` model as lightweight follow-on. Not a critical path decision.

## Sources

### Primary (HIGH confidence)
- **TimeQuest v1.0 codebase** — All 46 Swift files analyzed directly from `/Users/davezabihaylo/Desktop/Claude Cowork/GSD/TimeQuest/`. Architecture patterns, data models, domain engines, repository implementations, ViewModel patterns, and composition root observed directly from shipped code.
- **v1.0 STACK.md research** (2026-02-12) — Established base stack decisions (SwiftUI, SwiftData, SpriteKit, Swift Charts, iOS 17.0+, Swift 6.0). Validated against shipped codebase.
- **PROJECT.md v2.0 target features** — Feature requirements sourced from project definition.

### Secondary (MEDIUM confidence)
- **Apple Developer Documentation** (training data, not live-verified): SwiftData ModelConfiguration API, CloudKit integration patterns, schema versioning and migration behavior, AVAudioSession programming guide, CloudKit record constraints.
- **WWDC sessions** (training data, May 2025 cutoff): "Meet SwiftData" (WWDC 2023), "Build an app with SwiftData" (WWDC 2023 — CloudKit configuration demonstrated), "What's new in SwiftData" (WWDC 2024 — improvements to CloudKit sync).
- **Core Data + CloudKit patterns** — SwiftData inherits Core Data migration and CloudKit sync behavior. Community patterns from developer forums and post-mortems (training data knowledge).

### Tertiary (LOW confidence, needs validation)
- **CloudKit entitlement configuration for SwiftData** — Training data suggests `.cloudKitDatabase: .automatic` uses private database with specific entitlements. Exact keys (`CloudKit` service vs. `CloudDocuments`) should be verified against current Xcode project settings documentation.
- **SwiftData CloudKit edge cases** — Cascade delete sync behavior, relationship conflict resolution, array property serialization. Training data provides general guidance but specific API behavior should be tested in Phase 1.
- **iOS 17.4+ SwiftData CloudKit stability** — Training data indicates early iOS 17 releases had SwiftData CloudKit bugs; iOS 17.4+ reportedly more stable. Recommend iOS 17.4 as minimum deployment target (verify against current bug reports).

**Web search and Context7 were unavailable during research.** All CloudKit-specific claims based on training data through May 2025. SwiftData + CloudKit integration API was demonstrated at WWDC 2023 and refined at WWDC 2024, so core patterns are stable. Exact syntax and edge cases should be verified against current Apple documentation during Phase 1 implementation.

---
*Research completed: 2026-02-13*
*Ready for roadmap: yes*
