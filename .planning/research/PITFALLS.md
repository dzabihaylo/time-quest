# Domain Pitfalls: v2.0 Advanced Training Features

**Domain:** Adding iCloud sync, contextual insights, self-set routines, real sounds, and weekly reflections to existing SwiftData iOS app
**Researched:** 2026-02-13
**Overall confidence:** MEDIUM (training data only -- web search and Context7 unavailable)
**Source basis:** Apple developer documentation (training data, May 2025 cutoff), SwiftData/CloudKit integration patterns, iOS audio engineering patterns, established SwiftData migration behavior. All claims should be verified against current Apple documentation during implementation.

---

## Critical Pitfalls

Mistakes that cause data loss, require architectural rework, or break the existing v1.0 functionality.

---

### Pitfall 1: CloudKit Requires All Properties to Be Optional or Have Defaults -- Your Models Are Not Ready

**What goes wrong:** You enable CloudKit sync by switching from the default `ModelConfiguration` to one with a CloudKit container, and the app crashes on launch or silently fails to sync. CloudKit's underlying `CKRecord` schema requires that every field be optional because records can arrive partially from the cloud. SwiftData models destined for CloudKit must have every stored property either be `Optional` or have a default value.

**Why it happens with THIS codebase:** Looking at the current models:
- `Routine.name: String` -- no default, not optional
- `Routine.displayName: String` -- no default, not optional
- `RoutineTask.name: String` -- no default, not optional
- `RoutineTask.displayName: String` -- no default, not optional
- `TaskEstimation.taskDisplayName: String` -- no default, not optional
- `TaskEstimation.estimatedSeconds: Double` -- no default, not optional
- `TaskEstimation.actualSeconds: Double` -- no default, not optional
- `TaskEstimation.differenceSeconds: Double` -- no default, not optional
- `TaskEstimation.accuracyPercent: Double` -- no default, not optional
- `TaskEstimation.ratingRawValue: String` -- no default, not optional
- `GameSession.startedAt: Date` -- has default (`.now`), OK
- `PlayerProfile` -- all properties have defaults, OK

Nearly every model violates the CloudKit requirement. Enabling sync without fixing this will produce runtime errors or silent sync failures.

**Consequences:** If you just flip on CloudKit without model changes, you get one of: (a) crash on container initialization, (b) records fail to upload to CloudKit with opaque CKError codes, (c) records sync up but fail to materialize on the receiving device. Worst case: data appears to save locally but never syncs, and the user believes backup is working when it is not.

**Warning signs:**
- CKError with code `.invalidArguments` or `.serverRecordChanged` in console
- Records show up in CloudKit Dashboard with nil values where you expect data
- Sync works for `PlayerProfile` but not for other models (because PlayerProfile already has all defaults)

**Prevention:**
- Before enabling CloudKit, audit every `@Model` property. Every stored property must be `Optional<T>` or have a `= defaultValue` assigned at declaration
- For this codebase, the practical approach is adding sensible defaults to non-optional properties: `var name: String = ""`, `var estimatedSeconds: Double = 0`, etc.
- Do NOT make everything Optional and litter the codebase with `!` unwraps. Prefer defaults over optionals for properties that logically always have a value
- This is a schema migration. It must happen in a versioned `VersionedSchema` with a `SchemaMigrationPlan` to avoid corrupting existing local data (see Pitfall 2)

**Detection:** Test CloudKit sync on a real device with a real iCloud account before shipping. The Simulator's CloudKit behavior differs from production.

**Phase relevance:** Must be resolved BEFORE enabling CloudKit. This is the first task in any iCloud backup phase.

**Confidence:** HIGH -- this is a well-documented, fundamental CloudKit/Core Data constraint that has not changed since CloudKit's introduction and applies identically to SwiftData.

---

### Pitfall 2: Schema Migration Corrupts Existing v1.0 Data

**What goes wrong:** Adding defaults to every model property (required for CloudKit, per Pitfall 1), adding new fields for v2.0 features (e.g., `createdByPlayer: Bool` on `Routine`, analytics fields on `TaskEstimation`, weekly summary models), or renaming/restructuring properties triggers a schema migration. If the migration is not handled correctly, SwiftData fails to open the existing persistent store and either crashes or silently creates a new empty store -- erasing all v1.0 data.

**Why it happens with THIS codebase:** The current app uses the default `modelContainer(for:)` with no `VersionedSchema` or `SchemaMigrationPlan`. SwiftData's lightweight migration can handle simple additive changes (new optional properties, new properties with defaults) automatically. But it CANNOT handle:
- Renaming properties
- Changing property types
- Removing properties
- Adding new required (non-optional, no-default) properties
- Changing relationship cardinality

The danger zone is that v2.0 needs BOTH CloudKit compatibility changes (Pitfall 1) AND new feature fields, and some of these changes might accidentally cross the lightweight migration boundary.

**Consequences:** The player opens the updated app and all her estimation history, XP, streaks, calibration data, and routines are gone. For a skill-building app where visible progress is the primary motivator, this is catastrophic. She will not re-enter weeks of data.

**Warning signs:**
- App launches but shows empty state after update
- Console shows "Failed to load persistent stores" or "The model used to open the store is incompatible"
- SwiftData silently creates a new `.store` file alongside the old one

**Prevention:**
1. Introduce `VersionedSchema` NOW, retroactively defining v1.0's schema as `SchemaV1`
2. Define `SchemaV2` with all the changes needed for CloudKit + new features
3. Create a `SchemaMigrationPlan` that maps V1 to V2
4. For all v2.0 model changes, ONLY make changes that qualify as lightweight migrations: add new properties with defaults, add new optional properties, add entirely new models
5. Never rename or remove existing properties. If a property name is wrong, add a new one and deprecate the old
6. Test migration with REAL v1.0 data: build v1.0, populate data, then install v2.0 on top and verify everything survives
7. Keep a copy of the v1.0 `.store` file in test fixtures for automated migration testing

**Detection:** Add a migration test that opens a v1.0 store file with v2.0 schemas and verifies all records load correctly. Run this test in CI.

**Phase relevance:** Must be the FIRST thing built in v2.0 -- before any model changes. Schema versioning is the foundation that every other v2.0 feature depends on.

**Confidence:** HIGH -- SwiftData migration behavior is well-documented and inherited from Core Data's migration system.

---

### Pitfall 3: CloudKit Sync Creates Duplicate Records and Merge Conflicts

**What goes wrong:** The player uses the app on one device, then opens it on another (or restores from backup). CloudKit sync delivers records that already exist locally, creating duplicates. Or the player modifies the same routine on two devices before sync occurs, and the merge produces corrupted or unexpected data.

**Why it happens with THIS codebase:** The current models have no unique identity constraints. `PlayerProfile` uses `fetchOrCreate()` which fetches the first profile -- but with CloudKit sync, two devices could each create a `PlayerProfile`, and sync would deliver both. You'd end up with two profiles. Similarly, `Routine` objects have no unique identifier beyond their SwiftData `persistentModelID`, which is device-local and not stable across CloudKit sync.

CloudKit uses a "last writer wins" merge policy by default. If the player's XP is 500 on device A and 600 on device B, whichever syncs last overwrites the other. The player loses XP, streaks, or session data silently.

**Consequences:**
- Two `PlayerProfile` instances -- the app picks one arbitrarily, the other's XP/streak data is orphaned
- Duplicate routines appearing in the quest selection list
- XP or streak values reverting after sync
- Session data from one device overwriting or duplicating on another

**Warning signs:**
- Player sees duplicate routines or quests
- XP/level goes backward after opening app on a second device
- `PlayerProfile.fetchOrCreate()` returns different profiles on different launches

**Prevention:**
- Add a stable unique identifier (`var cloudID: String = UUID().uuidString`) to every model that should be deduplicated across devices
- For `PlayerProfile`, which is a singleton, use a hardcoded sentinel ID (e.g., `"player-profile-singleton"`) and deduplicate on receipt
- Implement a post-sync deduplication pass that runs when the app detects CloudKit history changes (using `NSPersistentCloudKitContainer`'s history tracking or SwiftData's equivalent)
- For additive data (sessions, estimations), duplicates are less dangerous but still annoying. Use the `recordedAt` timestamp + task name as a natural deduplication key
- For `PlayerProfile` fields like `totalXP`, consider whether sync should use "last writer wins" or "highest value wins." XP should only go UP, so a custom merge of `max(localXP, remoteXP)` is safer
- Treat CloudKit sync as eventually consistent. Never assume sync has completed. Always handle the "data arrived late" case

**Phase relevance:** Design the deduplication strategy alongside the CloudKit enablement. Not something to bolt on after.

**Confidence:** HIGH -- CloudKit merge conflicts and deduplication are the single most complained-about issue in the Core Data + CloudKit ecosystem.

---

### Pitfall 4: Enabling CloudKit Silently Breaks @Query Predicates on Relationships

**What goes wrong:** `RoutineListView` uses `@Query(sort: \Routine.createdAt)` and the repository uses `#Predicate { $0.routine?.persistentModelID == routineID }`. After enabling CloudKit, some predicates that worked with a local-only store start failing or returning incomplete results, because CloudKit-backed stores have different query behavior for relationship traversal.

**Why it happens with THIS codebase:** The `SessionRepository.fetchSessions(for:)` method filters by `$0.routine?.persistentModelID == routineID`. With CloudKit sync, `persistentModelID` is not stable across devices -- it is a local identifier. A routine synced from another device will have a different `persistentModelID` than the original. The predicate will fail to match sessions to their routines on the receiving device.

Additionally, CloudKit-backed stores do not support all predicate operations that local stores support. Complex predicates involving optionals, relationship traversal, or computed properties may behave differently.

**Consequences:**
- `fetchSessions(for:)` returns empty arrays for synced routines
- Calibration tracking breaks (it counts completed sessions per routine)
- Accuracy trends show incomplete data
- The app appears to work but is silently losing data associations

**Warning signs:**
- Sessions exist in the store but `fetchSessions(for:)` returns empty
- CalibrationTracker always says calibration is needed even for routines with many sessions
- AccuracyTrendChartView shows gaps or missing data points

**Prevention:**
- Replace `persistentModelID`-based relationship queries with queries on a stable custom identifier (the `cloudID` from Pitfall 3)
- Test every `FetchDescriptor` and `#Predicate` against a CloudKit-backed store, not just the local store
- Keep the relationship (`session.routine`) but don't query by `persistentModelID` -- query by your own stable ID
- Consider adding `routineCloudID: String` directly on `GameSession` as a denormalized lookup key for queries that need to filter sessions by routine

**Phase relevance:** Must be addressed alongside CloudKit enablement. Every repository method needs audit.

**Confidence:** MEDIUM -- the `persistentModelID` instability across CloudKit sync is well-documented for Core Data. The exact behavior in SwiftData may have improved but should be verified against current documentation.

---

### Pitfall 5: Analytics/Pattern Detection Queries Cause UI Stutter on Growing Dataset

**What goes wrong:** Contextual insights ("You always underestimate packing by 4 minutes") and weekly reflections require querying ALL `TaskEstimation` records, grouping by task name, computing averages, detecting trends. As the dataset grows over weeks/months of use, these aggregate queries become slow. Running them synchronously on the main thread (where `@MainActor`-bound repositories currently operate) causes visible UI freezes.

**Why it happens with THIS codebase:** The entire repository layer is `@MainActor`. Every fetch and computation happens on the main thread. The current usage is fine because v1.0 queries are simple: fetch routines, fetch sessions for a routine, fetch a profile. But v2.0 analytics need to:
- Fetch ALL estimations (potentially hundreds after weeks of use)
- Group by task name
- Compute running averages, standard deviations, trend slopes
- Detect patterns (time-of-day effects, day-of-week effects, duration-range accuracy)
- Generate natural language insights from the analysis

Doing this on `@MainActor` during view appearance will cause the UI to hang, especially on older devices.

**Consequences:** The "My Patterns" screen takes 1-3 seconds to appear. The weekly reflection view stutters. If the user has been playing for months, it gets progressively worse. The player associates the app with slowness and delays -- ironic for a time perception app.

**Warning signs:**
- Purple "main thread hang" warnings in Instruments
- ProgressView spinners appearing on the patterns/insights screen
- Performance degrading over time as more sessions accumulate

**Prevention:**
- Create a separate `AnalyticsEngine` as a pure domain engine (like `XPEngine`, `StreakTracker`) that takes arrays of `TaskEstimation` values and returns computed insights. This keeps the computation pure and testable
- Run the heavy fetch + computation on a background `ModelActor`, not on `@MainActor`
- Cache computed insights and invalidate only when new sessions are completed (not on every view appearance)
- Consider pre-computing insights at session completion time (when the user expects a brief processing moment) rather than on-demand when opening the patterns screen
- Set a practical query limit: "Last 90 days" or "Last 100 sessions" rather than "all time" for trend calculations. Older data can still be included in lifetime stats but excluded from trend analysis
- Profile with Instruments (Time Profiler) before and after adding analytics. Set a budget: patterns screen must appear in under 300ms

**Phase relevance:** Design the analytics computation architecture before building insights UI. The computation model determines whether insights feel instant or sluggish.

**Confidence:** MEDIUM -- the @MainActor constraint and growing dataset concern are architectural realities of this codebase. The specific performance thresholds depend on device and data volume.

---

## Moderate Pitfalls

Mistakes that cause significant friction, rework of a subsystem, or degraded user experience.

---

### Pitfall 6: Player-Created Routines Contaminate Parent-Created Data Model

**What goes wrong:** Adding self-set routines means the `Routine` model now has two sources: parent-created and player-created. Without a clear distinction in the data model, the parent dashboard shows player-created routines (confusing the parent), the parent accidentally edits a player routine (breaking the player's autonomy), or analytics blend parent-routine accuracy with player-routine accuracy (muddying insights).

**Why it happens with THIS codebase:** The current `Routine` model has no `createdBy` or `source` field. `RoutineListView` in the parent dashboard uses `@Query(sort: \Routine.createdAt)` which fetches ALL routines. There is no filtering by creator. When player-created routines are added, they will immediately appear in the parent's routine list.

The parent's `RoutineEditorView` can edit any routine. The player could create "Estimate my YouTube binge" as a fun self-challenge, and the parent would see it in their dashboard and potentially delete or modify it, breaking the player's sense of ownership.

**Consequences:**
- Parent sees player's personal routines and feels compelled to edit/judge them
- Player sees parent's approval/disapproval of her self-set routines -- destroying the autonomy benefit
- Analytics that compare "routine accuracy" blend two fundamentally different contexts
- If the parent deletes a player-created routine (cascade delete), all associated sessions and estimations vanish

**Warning signs:**
- Parent asks "What's this routine I didn't create?"
- Player stops creating self-set routines after parent comments on them

**Prevention:**
- Add `var createdByPlayer: Bool = false` to `Routine` (lightweight migration safe: new property with default)
- Filter parent dashboard: `#Predicate { !$0.createdByPlayer }` (only show parent-created routines)
- Filter player routine creation UI: show player-created routines as "My Challenges" separate from parent-configured "Quests"
- Prevent parent from editing player-created routines (don't show them in the editor)
- In analytics, separate or clearly label insights from player-created vs. parent-created routines
- Consider whether player-created routines should be visible in the parent dashboard at all. Recommendation: NO. The parent's role is setup, not surveillance

**Phase relevance:** Must be designed before implementing self-set routines. The `createdByPlayer` field should be added in the schema migration alongside other v2.0 model changes.

**Confidence:** HIGH -- this is a direct consequence of the existing data model lacking source attribution. The parent/player separation is a core design principle of this app.

---

### Pitfall 7: Replacing Placeholder Sounds Breaks Audio Session Configuration

**What goes wrong:** The placeholder `.wav` files are tiny silent or minimal files. Real sound assets are larger, possibly different formats (`.m4a`, `.caf`, `.aiff`), and may need different audio session configuration. Replacing the files without updating the audio session setup causes: sounds not playing, sounds cutting off other audio (music, podcasts), or sounds being silent when the ringer switch is off.

**Why it happens with THIS codebase:** `SoundManager` uses `AVAudioPlayer` with hardcoded `.wav` extension in `preload()`. It does NOT configure an `AVAudioSession`. Without explicit session configuration, iOS uses the default `AVAudioSession.Category.soloAmbient`, which:
- Respects the silent/ringer switch (sounds won't play if ringer is off)
- Ducks when the app goes to background
- Does NOT mix with other audio (playing a sound stops the user's music)

For a game sound effect, you want `AVAudioSession.Category.ambient` which:
- Respects the silent switch (appropriate -- if she has her phone on silent in class, sounds should not play)
- Mixes with other audio (she can listen to music while playing)
- Does not interrupt other apps' audio

**Consequences:**
- Replacing placeholder `.wav` with `.m4a` or `.caf` files: the `preload(_ soundName:, ext: "wav")` call silently fails because `Bundle.main.url(forResource:withExtension:)` returns nil for the wrong extension. No crash, but no sound either
- If sounds are louder/longer than placeholders, they may interrupt the player's music (extremely annoying for a teen)
- If not setting the audio session category, the default `soloAmbient` might duck or stop background music on sound playback

**Warning signs:**
- Sounds stop playing after replacing files (wrong extension)
- User's background music pauses when game sounds play
- Sounds don't play when the ringer switch is off (this is actually correct behavior for game sounds, but must be documented)

**Prevention:**
- Use `.caf` format for iOS sound effects (Core Audio Format -- native, lowest latency). Convert all assets to `.caf` during the asset pipeline, not at runtime
- Update `SoundManager.preload()` to accept the actual file extension or auto-detect it
- Add `AVAudioSession` configuration at app launch:
  ```swift
  try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
  try AVAudioSession.sharedInstance().setActive(true)
  ```
- Keep sound effects SHORT (under 3 seconds). Game UX sounds should be 0.1-1.5 seconds
- Test with background music playing (Spotify, Apple Music). Sounds must not interrupt playback
- Test with ringer switch off. Sounds should NOT play (this is correct for a game used by a teen in school/public)
- Update the `soundNames` array and preload logic when adding new sounds for new v2.0 events (pattern insight reveal, weekly reflection, etc.)

**Phase relevance:** Sound replacement should be a contained task. Do it AFTER the data model migrations are stable, as it is lower risk and independent of other features.

**Confidence:** HIGH -- AVAudioSession category behavior is well-documented and stable across iOS versions. The `.wav` extension issue is a direct reading of the current code.

---

### Pitfall 8: Weekly Reflection Feature Creates a Periodic Computation Problem with No Scheduler

**What goes wrong:** Weekly reflections ("This week: 6 quests, accuracy improved 8%") need to be computed at the end of each week. But iOS apps have no guaranteed background execution. The app might not be opened on Sunday when the week ends. If the reflection is computed on-demand when the app opens, you need to determine "which week are we reflecting on?" and handle gaps (what if she didn't open the app for 2 weeks?).

**Why it happens:** iOS aggressively suspends and kills background apps. There is no reliable cron-like scheduler. `BGAppRefreshTask` is best-effort and not guaranteed to run at a specific time. The app must handle arbitrary gaps between opens.

**Consequences:**
- If computed lazily on app open: first launch of the week shows last week's summary, but what if she opens the app on Wednesday? Do you show the partial current week? The previous complete week? Both?
- If the app is not opened for 2 weeks: she sees a stale reflection from 2 weeks ago, or the system tries to generate two reflections at once
- If reflections are tied to a specific day (e.g., "every Sunday"), she might never see them if she doesn't play on Sundays

**Prevention:**
- Compute reflections lazily at app launch, not on a schedule. When the app opens, check: "Is there a completed week since the last reflection was generated?" If yes, generate it
- Store reflections as persisted model objects (`WeeklyReflection` with `weekStartDate`, `weekEndDate`, summary fields). This way they survive app restarts and are queryable
- Handle gaps: if 3 weeks have passed, generate reflections for each missed week (they are all based on historical data, so this is cheap)
- Display the most recent unviewed reflection prominently. Older ones go to a history list
- Define "week" consistently: Monday-Sunday or Sunday-Saturday, using `Calendar.current.dateInterval(of: .weekOfYear, for: date)` to avoid off-by-one day bugs
- Do NOT use `BGAppRefreshTask` for this. It adds complexity for no benefit -- lazy computation on app open is sufficient and reliable

**Phase relevance:** Design the reflection data model and computation trigger before building the UI. The "when to compute" problem must be solved architecturally.

**Confidence:** MEDIUM -- the iOS background execution limitations are well-known. The specific approach of lazy computation is a standard pattern.

---

### Pitfall 9: Contextual Insights Generate Misleading Patterns from Small Sample Sizes

**What goes wrong:** The insights engine detects "You always underestimate Shower by 4 minutes" after 3 sessions. The player takes this as reliable self-knowledge. Then her next 5 sessions show random variation and the insight reverses. The system loses credibility, and the player stops trusting the insights.

**Why it happens:** Pattern detection on small samples produces high-variance results. With 3 data points, the "average underestimation" is dominated by noise. The first few sessions include calibration sessions where estimates are expected to be wildly off. Including calibration data in pattern analysis produces misleadingly negative baselines.

**Consequences:**
- Insights flip-flop: "You underestimate Shower" one week, "You overestimate Shower" the next
- Player acts on unreliable insights and gets worse results
- Player learns to ignore insights because they are not trustworthy
- Calibration session data skews all early insights negatively

**Warning signs:**
- Insights change dramatically week-over-week
- Insights contradict the player's improving accuracy trend
- Insights are generated for tasks with fewer than 5 non-calibration data points

**Prevention:**
- Set a minimum sample size before generating insights: at least 5 non-calibration sessions for a given task before any pattern claim
- Exclude calibration sessions (`isCalibration: true` on `GameSession`) from pattern analysis. Calibration is explicitly "learning your patterns" -- including that data defeats the purpose
- Use confidence language that matches sample size: "Early pattern: you might underestimate..." (5-9 samples) vs. "Strong pattern: you consistently underestimate..." (10+ samples)
- Show the sample size alongside insights: "Based on 12 sessions" -- transparency builds trust
- Implement a simple statistical test: is the mean difference significantly different from zero? A paired t-test on estimated vs. actual for a given task is trivial to implement and prevents noise from being reported as signal
- Never phrase insights as absolute truths. "Tends to" not "always." "About 4 minutes" not "exactly 4 minutes"

**Phase relevance:** Design the statistical thresholds and confidence language before building the insights UI. The insights engine should be a pure domain engine with clear minimum-data-required guards.

**Confidence:** HIGH -- small sample statistics is well-understood. The calibration session exclusion is specific to this codebase's `isCalibration` flag.

---

### Pitfall 10: iCloud Sync Exposes Parent Configuration to a Shared Family iCloud

**What goes wrong:** If the family shares an iCloud account (common with younger kids, less common at 13 but possible), enabling CloudKit sync could expose the parent's routine configuration to the player's other devices, or even to other family members' devices. The "invisible parent" design principle is violated at the data layer.

**Why it happens:** CloudKit's private database syncs across ALL devices signed into the same iCloud account. If the parent configures routines on a shared iPad (signed into the family iCloud), those routines sync to the player's iPhone automatically. The parent's routine names (internal names like "School Morning" that are hidden from the player UI) become visible in the CloudKit data.

**Consequences:**
- Player discovers parent-configured routine names in CloudKit data or through a data export
- If using Family Sharing with separate accounts, this is not an issue -- but must be verified
- If the parent uses the SAME device as the player (setting up routines, then handing the phone back), sync is not the problem -- but the parent's setup session might sync partial state to another device

**Warning signs:**
- Routine names appearing on devices where they shouldn't
- Parent's internal routine names visible in any debug or export UI

**Prevention:**
- Verify the deployment assumption: the parent sets up routines on the SAME device the player uses (this is the current v1.0 design with the hidden PIN). If so, CloudKit sync is only backing up data, not distributing it to other devices. This is the safe case
- If multi-device support is a goal, consider: should routines sync at all? Maybe only `PlayerProfile` and `GameSession`/`TaskEstimation` should sync (the player's data), while `Routine` and `RoutineTask` stay local (the parent's configuration)
- Implement selective sync: use two `ModelConfiguration` instances -- one local-only (for parent-configured routines) and one CloudKit-backed (for player data). SwiftData supports multiple configurations. NOTE: this adds significant complexity
- Simplest safe approach for v2.0: CloudKit syncs ALL data, but the app is designed for single-device use. The backup is for device replacement/restore, not multi-device access. Document this assumption explicitly

**Phase relevance:** Decide the sync scope (backup-only vs. multi-device) before implementing CloudKit. This is an architectural decision, not an implementation detail.

**Confidence:** MEDIUM -- the CloudKit private database behavior is well-documented. The family sharing edge case depends on the specific deployment scenario.

---

## Minor Pitfalls

Mistakes that cause friction or suboptimal outcomes but are fixable without major redesign.

---

### Pitfall 11: New Sound Assets Bloat the App Bundle

**What goes wrong:** Adding real, high-quality sound effects in uncompressed formats (`.wav`, `.aiff`) significantly increases the app bundle size. Five placeholder `.wav` files are tiny, but 10-15 production-quality sound effects at 16-bit 44.1kHz stereo can add 5-15 MB to the bundle. For a simple game, a 50MB+ binary feels wrong.

**Prevention:**
- Use compressed `.caf` (AAC-encoded) or `.m4a` for sound effects. A 1-second sound effect at high quality is under 50KB in AAC
- Keep sounds mono, not stereo. Game UI sounds do not need spatial audio
- Sample rate of 44.1kHz is fine; 48kHz offers no perceptible benefit for short effects
- Target total audio assets under 1 MB for the entire sound library
- Use `afconvert` (macOS command-line tool) to batch-convert: `afconvert input.wav output.caf -d aac -f caff`

**Phase relevance:** Apply during the sound replacement task. Quick optimization, no architectural impact.

**Confidence:** HIGH -- iOS audio format and bundle size behavior is well-documented.

---

### Pitfall 12: Adding Fields to TaskEstimation for Analytics Breaks Lightweight Migration

**What goes wrong:** To support contextual insights, you want to add derived/analytics fields to `TaskEstimation` (e.g., `durationCategory: String`, `timeOfDay: String`, `dayOfWeek: Int`). If these are added as stored properties without defaults, they break lightweight migration for existing records.

**Prevention:**
- For analytics dimensions (time of day, day of week, duration category), compute them from existing data (`recordedAt` for time/day, `actualSeconds` for duration category) rather than storing them as new fields
- If you do add stored fields, always provide defaults: `var durationCategory: String = "uncategorized"`
- Better: create the `AnalyticsEngine` as a pure computation layer that derives these dimensions at query time from `recordedAt` and `actualSeconds`. This requires ZERO model changes and ZERO migration risk
- If pre-computation is needed for performance, store analytics results in a SEPARATE model (`TaskAnalytics`) rather than modifying `TaskEstimation`. New models don't require migration of existing data

**Phase relevance:** Design analytics as a computation layer first. Only add stored fields if profiling proves computation is too slow.

**Confidence:** HIGH -- this is a direct application of SwiftData migration rules to the existing model structure.

---

### Pitfall 13: Self-Set Routine Creation UI Is Too Open or Too Restrictive

**What goes wrong:** If the player can create completely freeform routines, she might create routines that are too short (one 10-second task), too long (a 3-hour routine with 20 tasks), or nonsensical (task names that don't correspond to real activities). The estimation training value degrades. Conversely, if creation is too restrictive (must pick from templates only), it feels like another adult telling her what to do, defeating the autonomy benefit.

**Prevention:**
- Use a guided creation flow: templates as starting points ("After school," "Weekend morning," "Practice prep") that she can customize, rename, add/remove tasks
- Set guardrails, not walls: 1-10 tasks per routine, task names must be non-empty, at least one active day. These are validation rules, not creative restrictions
- Let her name things however she wants. "Estimate my procrastination" is a valid routine if she actually uses it to estimate task durations
- Show a preview of how the routine will look as a "quest" before saving
- The STATE.md already specifies "guided creation with templates + customization" -- stick to this. It is the right balance

**Phase relevance:** Design templates and validation rules alongside the routine creation UI. Not a data model concern -- this is purely UX.

**Confidence:** MEDIUM -- the balance between freedom and guidance is a UX design judgment. The general approach is sound.

---

### Pitfall 14: CloudKit Sync Quota and Rate Limiting

**What goes wrong:** CloudKit has per-app storage quotas and rate limits. If the app syncs aggressively (e.g., saving after every single estimation), it can hit rate limits, causing sync to stall. The free CloudKit tier provides 100MB of asset storage and 10GB of database storage per developer account, which is generous, but rate limiting is more likely to be the issue.

**Prevention:**
- Do not call `modelContext.save()` after every micro-change. Batch saves at natural boundaries: end of task, end of session, end of settings change
- The current codebase already saves at reasonable boundaries (end of task completion, end of session). Keep this pattern
- CloudKit handles sync timing automatically -- do not try to force sync. Let the framework manage push/pull
- Monitor CloudKit errors in a non-intrusive way (log them, don't show alerts to the user). Transient rate limit errors resolve automatically
- For a single-user app with a few sessions per day, CloudKit quotas will never be an issue. This is a "be aware" not "redesign for" concern

**Phase relevance:** No special handling needed. Just maintain the existing save-at-boundaries pattern.

**Confidence:** MEDIUM -- CloudKit quotas and rate limits are documented but the specific thresholds may have changed.

---

### Pitfall 15: The @Query in RoutineListView Bypasses the Repository Pattern

**What goes wrong:** `RoutineListView` uses `@Query(sort: \Routine.createdAt)` directly, bypassing `RoutineRepository`. When you add the `createdByPlayer` filter for Pitfall 6, you need to update BOTH the repository AND the `@Query` in the view. If you update one and forget the other, the parent sees player routines (or vice versa).

**Why it happens with THIS codebase:** The v1.0 codebase has a mixed pattern -- repositories for ViewModels, `@Query` for one SwiftUI view. This is not necessarily wrong (SwiftUI's `@Query` is designed for views), but it creates two code paths that must stay in sync.

**Prevention:**
- Decide on a single data access pattern: either ALL access goes through repositories (remove `@Query` from views) OR accept that views use `@Query` and repositories are for ViewModel logic
- If keeping `@Query`, update it when adding `createdByPlayer`: `@Query(filter: #Predicate { !$0.createdByPlayer }, sort: \Routine.createdAt)`
- Document the pattern choice in the architecture. Future contributors (or future you) need to know "where do I add filters?"
- When adding CloudKit, `@Query` will automatically reflect synced data, which is good. But it also means synced player-created routines will appear in the parent's `@Query` unless filtered

**Phase relevance:** Address alongside the `createdByPlayer` model change. Quick fix, but easy to forget.

**Confidence:** HIGH -- this is a direct code-level observation of the existing pattern.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Severity | Mitigation |
|-------------|---------------|----------|------------|
| Schema migration (do first) | Corrupted v1.0 data (Pitfall 2) | CRITICAL | VersionedSchema + SchemaMigrationPlan before ANY model changes |
| CloudKit enablement | Non-optional properties crash (Pitfall 1) | CRITICAL | Add defaults to all model properties in the versioned migration |
| CloudKit enablement | Duplicate records and merge conflicts (Pitfall 3) | CRITICAL | Stable `cloudID` on all models, deduplication strategy |
| CloudKit enablement | Broken relationship predicates (Pitfall 4) | CRITICAL | Replace `persistentModelID` queries with custom ID queries |
| CloudKit enablement | Parent data exposed via shared iCloud (Pitfall 10) | MODERATE | Decide backup-only vs. multi-device; consider split configurations |
| CloudKit enablement | Rate limiting (Pitfall 14) | LOW | Maintain existing save-at-boundaries pattern |
| Self-set routines | Player/parent data contamination (Pitfall 6) | MODERATE | `createdByPlayer` field, filtered queries, separated UI |
| Self-set routines | Too open/restrictive creation (Pitfall 13) | LOW | Guided templates + validation guardrails |
| Self-set routines | @Query bypass (Pitfall 15) | LOW | Update @Query filter alongside repository changes |
| Contextual insights | UI stutter from analytics queries (Pitfall 5) | MODERATE | Background ModelActor, cached computation, pure analytics engine |
| Contextual insights | Misleading small-sample patterns (Pitfall 9) | MODERATE | Minimum sample sizes, exclude calibration, confidence language |
| Contextual insights | New fields break migration (Pitfall 12) | MODERATE | Compute dimensions at query time, avoid new stored fields |
| Sound replacement | Audio session misconfiguration (Pitfall 7) | MODERATE | Set `.ambient` category, use `.caf` format, test with background music |
| Sound replacement | Bundle bloat (Pitfall 11) | LOW | AAC-encoded `.caf`, mono, target under 1 MB total |
| Weekly reflections | No reliable scheduler (Pitfall 8) | MODERATE | Lazy computation on app open, persisted reflection models |

---

## Recommended Phase Ordering (Based on Pitfall Dependencies)

The pitfalls reveal a clear dependency chain:

1. **Schema migration foundation** -- Pitfalls 1, 2 must be resolved before anything else. Every v2.0 feature needs model changes, and those changes must not corrupt v1.0 data.

2. **iCloud/CloudKit** -- Pitfalls 3, 4, 10, 14 are all CloudKit-specific. Do this as a self-contained phase immediately after migration, while the migration is fresh and before other features add more model complexity.

3. **Self-set routines** -- Pitfalls 6, 13, 15 require the `createdByPlayer` field (which should be in the schema migration) but are otherwise independent. The UI work is contained.

4. **Contextual insights + weekly reflections** -- Pitfalls 5, 8, 9, 12 are all analytics-related. These are read-only features that query existing data. Doing them after CloudKit ensures the analytics engine handles both local and synced data correctly.

5. **Sound replacement** -- Pitfalls 7, 11 are completely independent of all other features. Do this last (or in parallel) as a polish task with zero data model risk.

---

## The Meta-Pitfall: Changing Too Many Things in One Migration

The overarching risk of v2.0 is that CloudKit compatibility, new feature fields, self-set routine support, and analytics fields all require model changes, and they all need to land in a single schema migration (V1 -> V2). If the migration is too complex or any part of it fails, ALL of v2.0 is blocked.

**Mitigation:** Design the V2 schema comprehensively before writing any code. List every field addition, every default value change, and every new model in one place. Validate that every change qualifies as a lightweight migration. Test the migration with real v1.0 data before building any features on top of it.

---

## Confidence Assessment

| Pitfall | Confidence | Basis |
|---------|------------|-------|
| CloudKit optional/default requirements (#1) | HIGH | Fundamental, well-documented CloudKit constraint since 2019 |
| Schema migration data corruption (#2) | HIGH | Standard Core Data/SwiftData migration behavior |
| CloudKit duplicates and merge conflicts (#3) | HIGH | Most commonly reported CloudKit issue in developer community |
| Relationship predicate breakage (#4) | MEDIUM | Known for Core Data + CloudKit; verify behavior in current SwiftData |
| Analytics query performance (#5) | MEDIUM | Architectural analysis of existing @MainActor pattern |
| Player/parent data contamination (#6) | HIGH | Direct code analysis -- @Query has no creator filter |
| Audio session misconfiguration (#7) | HIGH | Well-documented AVAudioSession behavior |
| Weekly reflection scheduling (#8) | MEDIUM | Standard iOS background execution limitation |
| Small-sample misleading insights (#9) | HIGH | Basic statistics -- not platform-specific |
| iCloud shared account exposure (#10) | MEDIUM | Depends on deployment scenario assumptions |
| Sound bundle bloat (#11) | HIGH | Standard iOS asset management |
| Analytics fields migration risk (#12) | HIGH | Direct application of migration rules to existing models |
| Self-set routine UX balance (#13) | MEDIUM | UX design judgment, not technical certainty |
| CloudKit rate limiting (#14) | MEDIUM | Documented but thresholds may have changed |
| @Query bypass of repository pattern (#15) | HIGH | Direct code observation |

**Overall:** The CloudKit integration pitfalls (1-4) are the highest risk and have the highest confidence. They are well-documented failure modes with clear prevention strategies. The analytics pitfalls (5, 9, 12) are architectural concerns that can be prevented with good design. The sound and UX pitfalls (7, 11, 13) are lower risk and well-understood.

---

## Sources

- Apple Developer Documentation: "Syncing Model Data Across a Person's Devices" (SwiftData + CloudKit requirements)
- Apple Developer Documentation: "Mirroring a Core Data Store with CloudKit" (CloudKit record constraints, merge policies)
- Apple Developer Documentation: AVAudioSession Programming Guide (audio session categories and behavior)
- Apple Developer Documentation: SwiftData schema versioning and migration
- WWDC sessions on SwiftData migration and CloudKit integration (2023-2024)
- Core Data + CloudKit community patterns from developer forums and post-mortems

*All sources referenced from training data (May 2025 cutoff). Web search and Context7 were unavailable for verification. Specific API details and thresholds should be verified against current Apple documentation during implementation.*
