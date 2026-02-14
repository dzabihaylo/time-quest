# Project Research Summary

**Project:** TimeQuest v3.0 -- Adaptive & Connected
**Domain:** Educational iOS game -- time perception training for teens with ADHD-related time blindness
**Researched:** 2026-02-14
**Confidence:** MEDIUM (training data through May 2025; Spotify SDK and EventKit iOS 18+ details require verification)

## Executive Summary

TimeQuest v3.0 introduces four coordinated enhancements to an existing SwiftUI/SwiftData iOS app: adaptive difficulty calibration, Spotify music integration, calendar-driven routine scheduling, and a UI/brand refresh. This is NOT a greenfield project -- it's extending a working, production v2.0 codebase (66 files, 6,211 LOC, SchemaV3) with 4 new capabilities that operate independently but complement each other.

The recommended approach builds on the established architecture: pure domain engines (zero framework dependencies) for adaptive difficulty and calendar intelligence, new service-layer wrappers for external APIs (Spotify, EventKit), and a theme system for the UI refresh. All four pillars are technically independent -- they can be built and shipped in any order. The critical success factors are: (1) preserve the ADHD-friendly design principles when adding features (no punishment spirals, graceful degradation everywhere, simplicity over features), (2) use lightweight SchemaV4 migration to avoid CloudKit sync issues for existing users, and (3) keep Spotify and calendar integration strictly optional -- the core time estimation game must work perfectly without them.

The highest risks are ADHD-specific pitfalls in adaptive difficulty (avoid punishment loops by using long adjustment windows and upward-only difficulty ratcheting), Spotify audio session conflicts (use Web API only, not SDK playback control, to preserve the existing .ambient audio session for game sounds), and calendar permission sensitivity (EventKit access feels invasive in a "game" -- frame as player choice, handle denial gracefully). The architecture is well-designed and proven; the execution risk is in honoring the user-centered design constraints that make TimeQuest effective for its ADHD audience.

## Key Findings

### Recommended Stack

**v3.0 adds exactly two framework dependencies and zero third-party libraries to the existing stack.** The base stack (SwiftUI, SwiftData, SpriteKit, Swift Charts, CloudKit, AVFoundation on iOS 17.0+, Swift 6.0, Xcode 16.2) remains unchanged.

**New framework additions:**
- **EventKit.framework** (Apple first-party): Calendar read access for schedule intelligence -- the only way to access calendar data on iOS. Read-only, mature API (stable since iOS 6, `requestFullAccessToEvents()` added in iOS 17 for the target deployment). Privacy-sensitive: requires NSCalendarsUsageDescription and user permission.
- **SpotifyiOS.framework** (Swift Package Manager): OAuth + playback control for Spotify integration. First external dependency in the project. Requires Spotify Developer account, registered redirect URI, and token storage in Keychain. Alternative approach: Spotify Web API with PKCE (no SDK) eliminates SDK dependency but increases implementation complexity.
- **Security.framework** (Apple first-party, implicit): Keychain access for Spotify token storage. Already available, no explicit linking needed. Use raw Keychain API (30 LOC) rather than third-party wrapper.

**New pure domain engines (no dependencies):**
- **AdaptiveDifficultyEngine**: EMA-based dynamic difficulty calibration. Follows exact pattern of existing InsightEngine and WeeklyReflectionEngine -- static methods on structs, EstimationSnapshot value-type inputs, zero framework imports.
- **CalendarIntelligenceEngine**: Schedule context determination from calendar events. Consumes CalendarEvent value types (EventKit bridge), returns ScheduleContext. Pure Swift domain logic.
- **RoutinePlaylistEngine**: Duration-matched playlist assembly. Bin-packing algorithm, value-type inputs, no Spotify dependency.

**Key architectural decision:** Spotify integration via Web API (REST with URLSession) rather than iOS SDK playback control. Web API eliminates audio session conflicts with existing SoundManager, works with Free tier (playlist creation), and keeps the architecture client-only (no backend server needed with PKCE flow). Trade-off: no native in-app playback control, playlist is created and opened in Spotify app.

**Critical version requirements:**
- iOS 17.0+ deployment target (unchanged from v2.0)
- EventKit: `requestFullAccessToEvents()` requires iOS 17.0+
- Spotify iOS SDK: Verify Swift 6.0 strict concurrency compatibility (may need `@preconcurrency import`)
- SwiftUI MeshGradient (UI refresh): iOS 18.0+ with fallback to LinearGradient on iOS 17

**Confidence:** HIGH for EventKit and Security.framework (mature Apple APIs). MEDIUM for Spotify iOS SDK (version and Swift 6 compatibility need verification). HIGH for UI refresh technologies (all built into SwiftUI on iOS 17+).

### Expected Features

**Must ship (table stakes):**
- **Automatic difficulty progression** -- tighter accuracy thresholds as player skill improves. Cannot be "Easy/Medium/Hard" toggle -- must be invisible and algorithmic. ADHD-critical: never DECREASE difficulty (frustration spiral prevention).
- **Spotify account connection** -- one-time OAuth, persistent via Keychain. Free tier and Premium must both work gracefully.
- **Duration-matched playlist** -- routine takes ~25 minutes, playlist is ~25-27 minutes. Music provides audible time cue without checking screen.
- **School day detection** -- calendar intelligence determines "today is a school day" to surface morning routine automatically.
- **Routine auto-surfacing** -- school morning routine appears on school days, skipped on holidays/summer without manual schedule changes.
- **Visual refresh of core screens** -- home screen, quest flow (estimation → active → reveal → summary), patterns. First impression must feel 2026-modern, not prototype.
- **Graceful degradation everywhere** -- Spotify not installed? Calendar denied? App works identically. New features are enhancements, never requirements.

**Should ship (differentiators):**
- **XP scaling with difficulty** -- mastering-level accuracy earns 1.5x XP. Rewards improvement without changing threshold definitions.
- **Post-routine song count** -- "You got through 4.5 songs" as intuitive time unit. Complements time-in-seconds for ADHD time perception building.
- **Holiday awareness** -- detect all-day calendar events (Christmas, school breaks) to suppress school routines automatically.
- **Dark mode as primary** -- design dark-first with light fallback. Player uses phone at night in dim rooms.
- **SF Rounded typography** -- `.fontDesign(.rounded)` for friendly-modern feel, zero bundle size, automatic Dynamic Type.

**Defer (v3.1+):**
- Batch estimation mode (high complexity, unlocks only at max difficulty)
- Activity season awareness (requires weeks of calendar pattern analysis)
- Per-routine music preferences (nice-to-have on basic Spotify)
- Smart notification timing from calendar (complex, marginal value)
- Challenge mode for mastered tasks (v4.0 stretch goal)

**Anti-features (explicitly do NOT build):**
- Visible difficulty level display ("Level 4 - Expert!") -- creates anxiety, externalizes difficulty
- Player-selectable difficulty -- she'll game the system or feel pressured
- Music during estimation phase -- distracts from cognitive estimation task
- Spotify Premium gate -- features requiring Premium exclude Free users
- Forced Spotify connection -- blocks gameplay, violates simplicity principle
- Calendar write access -- feels like surveillance
- Full calendar display -- TimeQuest is not a calendar app
- Avatar system / animated backgrounds / skeuomorphic gamification -- scope creep, childish feel

**Feature sizing estimate:**
- Adaptive Difficulty: ~330 LOC, 3 new files, 5 modified files, LOW risk
- Spotify Integration: ~680 LOC, 4 new files, 5 modified files, HIGH risk (external dependency)
- Calendar Intelligence: ~470 LOC, 3 new files, 5 modified files, MEDIUM risk (privacy/permissions)
- UI/Brand Refresh: ~1,190 LOC, 7 new files, 13 modified files, LOW risk (visual only)
- **Total:** ~2,670 LOC added (43% growth), ~17 new files, ~28 modified files

**Confidence:** HIGH (based on v2.0 codebase analysis and domain research). Feature prioritization aligns with ADHD-friendly design principles.

### Architecture Approach

**v3.0 extends the existing architecture without structural changes.** The established patterns (pure domain engines, EstimationSnapshot value-type bridge, repository protocols, composition root AppDependencies, QuestPhase state machine) are proven and continue. New features follow these patterns exactly.

**Major architectural additions:**

1. **AdaptiveDifficultyEngine (Domain layer)** -- Pure struct with static methods. Inputs: `[EstimationSnapshot]`. Outputs: `DifficultyParameters` (hint visibility, accuracy band multiplier, XP multiplier). Algorithm: exponential moving average (EMA) over last 10 sessions per task, 4 difficulty levels (learning/practicing/confident/mastering). Integration point: `GameSessionViewModel.startQuest()` computes difficulty per task, applies parameters during estimation and scoring. **No new dependencies.**

2. **SpotifyService + SpotifyAuthManager (Services layer)** -- `@Observable @MainActor` service managing OAuth (ASWebAuthenticationSession), token storage (Keychain via Security.framework), and Web API calls (URLSession). Integration: added to AppDependencies, consumed by parent setup (playlist selection) and GameSessionViewModel (playback on quest start). **Critical decision:** Web API only, no SDK playback control -- avoids audio session conflict with existing SoundManager's `.ambient` category.

3. **CalendarService + CalendarIntelligenceEngine (Services + Domain)** -- CalendarService wraps EventKit (permission request, event fetching), bridges to CalendarEvent value types. CalendarIntelligenceEngine analyzes events to determine ScheduleContext (isSchoolDay, isHoliday, activeActivities). Integration: PlayerHomeView loads calendar context on appear, filters routines based on schedule. **Read-only, never writes to calendar. Permissions handled gracefully.**

4. **Theme system (Design layer, new folder)** -- Environment-based theme (Theme struct injected via `.environment()`, same pattern as AppDependencies). ThemeColors, ThemeTypography, ThemeSpacing, ThemeIcons, ThemeAnimation define design tokens. ThemedCard and ThemedButton reusable components consume theme. Migration: incremental, one view at a time, starting with low-risk views. **Zero schema impact, zero model changes.**

**Schema evolution:** SchemaV4 adds 4 fields across 3 models (all optional or defaulted for lightweight migration):
- `GameSession.difficultyLevelRawValue: String = "learning"` (track which difficulty was active)
- `TaskEstimation.accuracyBandMultiplier: Double = 1.0` (track threshold adjustment for fair comparisons)
- `Routine.spotifyPlaylistURI: String?` (linked Spotify playlist)
- `Routine.spotifyPlaylistName: String?` (cached for display, avoid API call)

**Data flow examples:**
- **Adaptive difficulty:** `startQuest()` → fetch snapshots → `AdaptiveDifficultyEngine.computeDifficulty(taskName:, snapshots:)` → apply hint visibility + threshold multiplier → score with adjusted bands → apply XP multiplier.
- **Spotify:** Parent dashboard → connect OAuth → store tokens in Keychain → select playlist → save URI to Routine → quest start → `spotifyService.play(playlistURI:)` → music in Spotify app.
- **Calendar:** App open → `CalendarService.fetchTodayEvents()` → `CalendarIntelligenceEngine.analyzeDay(events:)` → filter routines → surface school morning on school days, hide on holidays.

**Build system impact:** generate-xcodeproj.js requires updates for EventKit.framework linkage and SPM package reference (first SPM dependency). The pbxproj needs new sections: XCRemoteSwiftPackageReference + XCSwiftPackageProductDependency for SpotifyiOS.

**Confidence:** HIGH for adaptive difficulty and theme system (pure domain, proven patterns). MEDIUM for Spotify and calendar (external APIs, privacy/permissions add complexity).

### Critical Pitfalls

Research identified 18 pitfalls (6 critical, 6 moderate, 6 minor) plus 3 ADHD-specific pitfalls and 3 cross-feature integration pitfalls. Top 5 by impact:

1. **Adaptive difficulty creates punishment loop for ADHD players (CRITICAL)** -- If difficulty drops on bad days (ADHD executive function fluctuates randomly day-to-day), the player interprets it as "the game thinks I failed." Prevention: (a) LONG adjustment window (10-15 sessions, not 3-5) to smooth out fluctuation, (b) UPWARD-ONLY ratchet -- never decrease difficulty, only pause during declining trends, (c) PER-TASK adjustment (not global), (d) INVISIBLE -- no UI indication of difficulty level, only internal threshold adjustments. This is the highest UX risk in v3.0.

2. **Spotify audio session conflict destroys existing sound effects (CRITICAL)** -- If Spotify playback changes AVAudioSession category, SoundManager's `.ambient` session for game sounds fails. Prevention: Use Spotify Web API ONLY (create/manage playlists), do NOT use Spotify iOS SDK's SPTAppRemote for playback control. Music plays in Spotify app (separate process, separate audio session). TimeQuest keeps `.ambient` for its 5 game sounds. No conflict because `.ambient` explicitly mixes with other apps' audio.

3. **SchemaV4 migration breaks CloudKit sync for existing users (CRITICAL)** -- If migration is not lightweight, store fails to open or data is lost. If two devices have different schema versions (one updated, one not), CloudKit sync can corrupt data. Prevention: (a) EVERY new field has a default value, (b) NO custom migration logic -- lightweight only, (c) test with real V3 store file before shipping, (d) consider device-local ModelConfiguration for Spotify/Calendar metadata (don't sync tokens or EventKit IDs).

4. **EventKit calendar access contradicts "invisible parent" and requires privacy justification (CRITICAL)** -- Permission prompt appears to PLAYER ("TimeQuest wants your calendar"), not parent. If denied, feature fails permanently. Calendar data is sensitive (family schedule, appointments). COPPA concerns for under-13 users. Prevention: (a) frame as PLAYER CHOICE, not requirement -- "Want TimeQuest to know your schedule?" with clear value prop and easy decline, (b) read-only access only, never write, (c) query narrow time window (today only), never store event details in SwiftData, (d) handle denial gracefully -- app works identically, calendar is purely additive, (e) consider ALTERNATIVE: parent-configured schedule (no EventKit, no permission prompt, simpler architecture).

5. **Spotify OAuth token management in a teen's app (expiry, account sharing, under-13 complications) (CRITICAL)** -- Access tokens expire every 60 minutes. If not refreshed, music stops mid-routine. If tokens stored in UserDefaults (not Keychain), security vulnerability. If OAuth flow fails (multi-step task abandonment), Spotify feature never works but player doesn't know why. Prevention: (a) store tokens in KEYCHAIN (not UserDefaults, not SwiftData), (b) auto-refresh before expiry (check on every API call, refresh if <5 min remaining), (c) make Spotify OPTIONAL everywhere -- no forced login, no blocking gameplay, (d) one-tap OAuth via ASWebAuthenticationSession with `prefersEphemeralWebBrowserSession: false` (uses existing Safari session), (e) handle Free vs Premium tier gracefully (Free tier cannot play on-demand tracks via API -- suggest "open playlist in Spotify" instead of API-controlled playback).

**Additional critical pitfalls:**
- **Adaptive difficulty destabilizes XP/leveling economy** -- tighter thresholds reduce spot_on frequency, slowing progression. Mitigation: decouple difficulty from XP, use accuracy-proportional XP.
- **Adaptive difficulty corrupts InsightEngine trend analysis** -- stored accuracyPercent based on fixed thresholds becomes incomparable after difficulty adjusts. Mitigation: store absolute accuracy, use difficulty-adjusted ratings only for display.
- **Spotify Web API requires backend server** -- Mitigation: PKCE flow eliminates client secret, no server needed for mobile apps.
- **UI theme retrofit touches 20+ views with regression risk** -- Mitigation: incremental migration, theme tokens, UI refresh LAST phase.
- **EventKit main thread queries freeze UI** -- Mitigation: async queries, cached results, narrow date range.

**ADHD-specific pitfalls:**
- **Too many settings cause decision paralysis** -- Mitigation: minimal settings (2 toggles max), automatic behavior everywhere else.
- **Spotify OAuth multi-step flow will be abandoned** -- Mitigation: no persistent "in progress" state, no nagging after abandonment.
- **Calendar-suggested routines feel like nagging** -- Mitigation: passive context ("Free afternoon today"), never suggest actions ("Time for a quest!").

**Confidence:** HIGH for all identified pitfalls. These are derived from codebase analysis (ADHD design principles, existing audio session config, SwiftData migration history) and standard iOS/Spotify API behavior.

## Implications for Roadmap

Based on combined research, v3.0 should be structured as **4 independent phases in series** (not parallel, to minimize merge conflicts and integration complexity). Each phase delivers a shippable increment. If any phase blocks or is cut, the others still ship.

### Suggested Phase Structure

**Phase 1: Schema Evolution + Adaptive Difficulty**

**Rationale:** Schema changes must come first (both Adaptive Difficulty and Spotify need new fields). Adaptive Difficulty is pure domain logic with zero external dependencies -- lowest risk, highest testability. It follows the exact pattern of InsightEngine (pure engine consuming EstimationSnapshot).

**Delivers:**
- TimeQuestSchemaV4 with all new fields (from all 4 pillars)
- TimeQuestMigrationPlan updated with v3ToV4 lightweight stage
- AdaptiveDifficultyEngine (pure domain, comprehensive tests)
- Modified TimeEstimationScorer (accepts accuracyBandMultiplier param)
- Modified GameSessionViewModel (computes and applies difficulty per task)
- Updated EstimationInputView (conditionally shows/hides hints based on difficulty)
- Updated AccuracyRevealView (difficulty-adjusted feedback, mastery XP bonus indicator)

**Features from FEATURES.md:**
- Automatic difficulty progression (table stakes)
- XP scaling with difficulty (differentiator)
- Difficulty floor / frustration prevention (ADHD-critical)

**Avoids pitfalls:**
- Pitfall #1 (ADHD punishment loop): long window, upward-only, per-task, invisible
- Pitfall #2 (XP economy destabilization): accuracy-proportional XP, not rating-based
- Pitfall #3 (SchemaV4 migration): lightweight, all defaults, tested with V3 store
- Pitfall #4 (difficulty/insights interaction): store absolute accuracy, display difficulty-adjusted ratings

**Research flag:** NO -- adaptive difficulty is well-understood game design. EMA algorithm is textbook. Integration points are clear from codebase analysis.

**Estimated effort:** ~330 LOC, 3 new files, 5 modified files. 3-5 days implementation + testing.

---

**Phase 2: Calendar Intelligence**

**Rationale:** System framework integration (EventKit) with well-established patterns. No external third-party dependency. Lower risk than Spotify. Permission flow is the main UX challenge but it's a solved problem. Builds on existing RoutineRepository patterns.

**Delivers:**
- CalendarService (EventKit wrapper, permission handling)
- CalendarEvent value type + EventKit bridge extension
- ScheduleSuggestionEngine (pure domain, keyword matching heuristics)
- CalendarPermissionView (pre-permission explanation UI)
- ScheduleSuggestionsView (calendar suggestion cards on home screen)
- Integration into PlayerHomeView (fetch events on appear, filter routines by schedule)

**Features from FEATURES.md:**
- School day detection (table stakes)
- Routine auto-surfacing (table stakes)
- Holiday awareness (differentiator)

**Avoids pitfalls:**
- Pitfall #5 (EventKit privacy/consent): optional, graceful denial, teen-friendly description
- Pitfall #6 (main thread EventKit queries): async, cached, narrow date range
- Pitfall #7 (EventKit IDs don't sync): store derived schedule, not EventKit refs
- ADHD Pitfall #3 (calendar nagging): passive context, never suggest actions
- Integration Pitfall B (calendar vs parent authority): read-only, advisory, never modify routines

**Research flag:** LOW -- if parent-configured schedule is chosen over EventKit, this becomes trivial (just UI for schedule config, no framework integration). If EventKit is chosen, permission flow UX needs design attention but technical implementation is straightforward.

**Estimated effort:** ~470 LOC, 3 new files, 5 modified files. 4-6 days implementation + testing.

---

**Phase 3: Spotify Integration**

**Rationale:** Highest-risk pillar (external dependency, OAuth complexity, audio session concerns, Free vs Premium tiers). Build after simpler pillars to avoid blocking progress on external issues. Well-defined from research: Web API with PKCE, Keychain tokens, playlist creation only (no playback control).

**Delivers:**
- SpotifyConfiguration (client ID, redirect URI, scopes -- config file, not hardcoded)
- SpotifyAuthManager (Keychain-backed token storage, auto-refresh logic)
- SpotifyService (OAuth flow via ASWebAuthenticationSession, Web API playlist CRUD)
- KeychainHelper (minimal Keychain read/write, ~30 LOC, no third-party wrapper)
- SpotifyConnectView (parent dashboard OAuth UI)
- SpotifyPlaylistPickerView (parent dashboard playlist selection)
- QuestMusicBannerView (player quest "Now Playing" indicator)
- Integration into GameSessionViewModel (playlist creation on quest start, pause on finish)
- TimeQuestApp.onOpenURL handler (OAuth redirect callback)
- generate-xcodeproj.js updates (EventKit linkage, SPM package reference)

**Features from FEATURES.md:**
- Spotify account connection (table stakes)
- Duration-matched playlist (table stakes)
- Post-routine song count (differentiator)

**Avoids pitfalls:**
- Pitfall #8 (audio session conflict): Web API only, no SDK playback, SoundManager keeps .ambient
- Pitfall #9 (token management): Keychain, auto-refresh, graceful degradation
- Pitfall #10 (no backend server): PKCE flow, no client secret needed
- Pitfall #11 (playlist duration mismatch): use actual duration history, 10-15% buffer, set expectations
- Pitfall #12 (Free tier playback): suggest playlist approach, not API-controlled playback
- Pitfall #13 (login complexity): hide in settings, interruptible, minimal branding
- ADHD Pitfall #2 (OAuth abandonment): no persistent "in progress" state, no nagging

**Research flag:** MEDIUM -- Spotify iOS SDK version, PKCE support, Free tier restrictions need verification against current Spotify Developer docs before implementation. OAuth flow UX should be prototyped early.

**Estimated effort:** ~680 LOC, 4 new files, 5 modified files, plus generate-xcodeproj.js updates. 6-8 days implementation + testing.

---

**Phase 4: UI/Brand Refresh**

**Rationale:** Purely visual, zero functional impact. Should be LAST because (a) new views from Phases 1-3 exist and can be themed in a single pass, (b) theme migration while other work is in-flight creates merge conflicts, (c) incremental migration (one view at a time) is safest when all features are stable.

**Delivers:**
- Design/ folder with Theme system (Theme struct, ThemeColors, ThemeTypography, ThemeSpacing, ThemeIcons, ThemeAnimation)
- View+Theme extension (`.themed()` modifier, environment key)
- ThemedCard and ThemedButton reusable components
- `.themed()` injected at ContentView root
- Incremental migration of all views (PlayerHomeView → QuestView chain → ParentDashboard → remaining views)
- AccuracyRevealScene and CelebrationScene color updates
- Asset catalog additions (AccentPrimary, AccentSecondary color sets with light/dark variants)

**Features from FEATURES.md:**
- Visual refresh of all screens (table stakes)
- Dark mode as primary (differentiator)
- SF Rounded typography (differentiator)

**Avoids pitfalls:**
- Pitfall #14 (20+ view regression risk): incremental, low-risk views first, use previews
- Pitfall #15 (alienating existing player): evolutionary not revolutionary, preserve layout hierarchy
- Integration Pitfall C (Spotify branding conflict): minimal Spotify branding, game identity dominates

**Research flag:** NO -- SwiftUI theme patterns are well-understood. All APIs are built into iOS 17+. This is execution risk (careful migration), not technical risk.

**Estimated effort:** ~1,190 LOC, 7 new files, 13 modified files. 5-7 days implementation + visual QA.

---

### Phase Ordering Rationale

**Why this order:**
1. **Schema first** (foundational, everything depends on stable schema)
2. **Adaptive difficulty second** (pure domain, highest design risk but no external blockers -- can be fully tested in isolation)
3. **Calendar third** (system framework, lower complexity than Spotify, permission flow is solved problem)
4. **Spotify fourth** (external dependency with most unknowns -- API changes, auth flow issues, SDK compatibility)
5. **UI refresh last** (applies to final feature set including new views from phases 1-4)

**Dependency logic:**
- Schema V4 blocks both Adaptive Difficulty and Spotify (they need new fields)
- Adaptive Difficulty blocks nothing (pure domain)
- Calendar blocks nothing (independent feature)
- Spotify blocks nothing (independent feature)
- UI refresh should be last to theme final view set

**Alternative ordering:** Calendar and Spotify could be swapped (Spotify before Calendar). Rationale for Calendar first: EventKit is lower-risk than external API, privacy prompt is the main UX concern (well-understood), parent-configured schedule is a viable fallback if EventKit proves problematic.

**If scope pressure:** Cut Spotify entirely. Phases 1 (adaptive), 2 (calendar), and 4 (UI) deliver a complete v3.0 without external dependencies. Spotify can ship as standalone v3.1.

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 3 (Spotify):** Verify Spotify iOS SDK current version, PKCE support, Swift 6 compatibility, Free vs Premium tier API restrictions, rate limits. Prototype OAuth flow early to validate UX. Check Spotify brand guidelines for minimal integration. **Estimated research:** 2-4 hours before implementation.
- **Phase 2 (Calendar):** Verify iOS 18 EventKit privacy changes (if any). Decision: EventKit vs parent-configured schedule needs UX validation. **Estimated research:** 30 minutes verification before implementation.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Adaptive Difficulty):** Pure domain logic, EMA algorithm is textbook, integration points are clear from codebase.
- **Phase 4 (UI Refresh):** SwiftUI theme patterns are well-documented, no framework uncertainty.

**Overall research confidence by phase:**
1. Schema + Adaptive Difficulty: HIGH (codebase patterns proven, algorithm well-understood)
2. Calendar Intelligence: HIGH (EventKit API mature, integration pattern established)
3. Spotify Integration: MEDIUM (external API, verification needed)
4. UI/Brand Refresh: HIGH (SwiftUI built-in capabilities, zero external deps)

### Recommended Milestone Tracking

**Milestone: v3.0 Adaptive & Connected**
- Target: 4 independent shippable phases
- Estimated total effort: 18-26 days (implementation + testing across 4 phases)
- Success criteria: Each phase passes independent QA, can ship without other phases
- Descope trigger: If any phase takes >150% estimated time, evaluate cutting to ship remaining phases

**Phase completion criteria:**
1. Schema + Adaptive Difficulty: Difficulty adjusts per-task, XP economy stable, no schema migration issues on test device
2. Calendar Intelligence: Permission flow works, routines auto-surface on school days, calendar denial handled gracefully
3. Spotify Integration: OAuth flow completes, playlist creates successfully, Free and Premium tiers both work, audio session conflict verified absent
4. UI/Brand Refresh: All views themed, no visual regressions, dark mode looks correct, previews validate changes

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| **Stack** | MEDIUM | EventKit and Security.framework HIGH (Apple first-party, mature). Spotify iOS SDK MEDIUM (version/compatibility need verification). UI tech HIGH (SwiftUI built-in). |
| **Features** | HIGH | Feature prioritization aligned with ADHD design principles. Sizing estimates based on codebase analysis. Table stakes vs differentiators well-justified. |
| **Architecture** | HIGH | All four pillars extend existing patterns exactly (pure domain engines, service-layer wrappers, environment-based theme). SchemaV4 follows proven V1→V2→V3 lightweight migration pattern. |
| **Pitfalls** | HIGH | ADHD-specific pitfalls derived from design principles. Audio session, schema migration, EventKit privacy are iOS fundamentals. Spotify pitfalls well-documented (OAuth, Free tier, token expiry). |

**Overall confidence:** MEDIUM

**Reasoning:** Technical architecture is sound and proven. The execution risk is in: (1) honoring ADHD-friendly design constraints when adding features (this is UX judgment, not technical certainty), (2) Spotify iOS SDK details that require verification against current docs, (3) EventKit iOS 18+ privacy changes (if any). All four research files flag these same uncertainties consistently.

### Gaps to Address

**Spotify iOS SDK specifics (Phase 3 pre-work):**
- Current version and distribution method (SPM confirmed, but version unknown)
- Swift 6 strict concurrency compatibility (may require `@preconcurrency import`)
- PKCE flow support and implementation details (documented as of 2019, verify current)
- Free tier vs Premium tier API endpoint restrictions (Web API playback control may be Premium-only)
- Rate limits for playlist creation endpoints (undocumented, need testing)
- **Mitigation:** 2-4 hour research-phase at Phase 3 start. Web search Spotify Developer docs, verify SDK GitHub repo, test OAuth flow in prototype app before integrating into TimeQuest.

**EventKit iOS 18 changes (Phase 2 pre-work):**
- Verify `requestFullAccessToEvents()` API stability on iOS 17-18
- Check for any new privacy restrictions in iOS 18
- Confirm EventKit identifier portability across devices (documented as device-local, verify)
- **Mitigation:** 30-minute verification before Phase 2 implementation. Quick check Apple Developer docs, EventKit Release Notes.

**ADHD UX validation (ongoing during phases):**
- Adaptive difficulty "feels invisible" -- needs playtesting with actual player (Phase 1)
- Spotify OAuth flow completion rate (multi-step task abandonment risk) (Phase 3)
- Calendar permission acceptance rate (privacy concern in "game" context) (Phase 2)
- UI refresh "feels evolutionary, not jarring" -- subjective, needs player reaction (Phase 4)
- **Mitigation:** Build with configurable parameters (adaptive difficulty thresholds, OAuth retry logic, permission prompt copy). Test incrementally. Adjust based on actual player feedback post-Phase completion.

**generate-xcodeproj.js SPM support (Phase 3 blocker):**
- pbxproj format for XCRemoteSwiftPackageReference and XCSwiftPackageProductDependency
- How to register SPM packages in project.pbxproj correctly
- **Mitigation:** Study existing pbxproj files from other projects with SPM dependencies. Add SPM section to generate-xcodeproj.js template. Test with minimal "hello world" SPM package before adding SpotifyiOS.

## Sources

### Primary (HIGH confidence)
- **TimeQuest v2.0 codebase** (66 Swift files, 6,211 LOC, analyzed directly from `/Users/davezabihaylo/Desktop/Claude Cowork/GSD/TimeQuest/`) -- existing architecture patterns, AppDependencies composition root, pure domain engines (InsightEngine, CalibrationTracker, XPEngine), EstimationSnapshot bridge, SchemaV1→V2→V3 migration history, SoundManager .ambient audio session config, GameSessionViewModel QuestPhase state machine, PROJECT.md player context and ADHD design principles
- **Apple Developer Documentation** (training data through May 2025) -- EventKit framework (EKEventStore, authorization model, event queries, identifier portability), AVAudioSession (categories, interruption handling, .ambient mixing behavior), Security.framework Keychain API, SwiftUI environment-based theming (.environment(), EnvironmentKey pattern), ASWebAuthenticationSession OAuth flow, SwiftData lightweight migration constraints, CloudKit sync behavior with schema changes

### Secondary (MEDIUM confidence)
- **Spotify Developer Documentation** (training data through May 2025) -- Web API Authorization Code Flow with PKCE (no client secret needed for mobile), playlist endpoints (create, add tracks, metadata), player endpoints (playback control, premium-only restrictions), user profile endpoint (product tier detection), iOS SDK SPTAppRemote architecture (playback control, requires installed app), brand guidelines (logo usage, color requirements). **Needs verification:** current SDK version (was ~2.x as of mid-2025), Swift 6 compatibility, exact PKCE implementation details, Free tier limitations as of 2026.
- **Game design research** (training data) -- Dynamic difficulty adjustment (DDA) patterns in educational games, exponential moving average (EMA) for skill tracking, flow theory (Csikszentmihalyi), engagement curves, anti-frustration mechanics. Standard algorithms, high confidence in concept, MEDIUM confidence in ADHD-specific parameter tuning (10-15 session window, upward-only ratchet) which requires playtesting validation.
- **ADHD research** (training data) -- Executive function variability (well-documented in clinical literature), decision paralysis with too many options (well-documented), task abandonment in multi-step processes (well-documented), sensitivity to perceived failure and punishment framing (well-documented). Application to adaptive difficulty thresholds and OAuth flow UX is design judgment derived from established ADHD principles (MEDIUM confidence -- needs validation with actual player).

### Tertiary (LOW confidence, needs validation)
- **Spotify iOS SDK current version and distribution** -- SPM confirmed in training data as of 2024, exact current version unknown (was ~2.1.x in mid-2025), verify GitHub repo `https://github.com/spotify/ios-sdk` before Phase 3.
- **EventKit iOS 18 privacy changes** -- iOS 17 added `requestFullAccessToEvents()` (replacing deprecated `requestAccess(to:)`), iOS 18 may have introduced new permission categories (writeOnly/readOnly distinction refinement), verify Apple EventKit Release Notes before Phase 2.
- **Spotify rate limits** -- documented as existing but exact thresholds undisclosed and vary by endpoint, test during Phase 3 implementation with actual API calls.
- **SwiftUI MeshGradient availability** -- announced for iOS 18 at WWDC 2024, verify shipped in iOS 18.0 final release and works as documented (used in Phase 4 for background depth effects with LinearGradient fallback on iOS 17).

---

**Research completed:** 2026-02-14
**Ready for roadmap:** Yes

All four research files (STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md) synthesized. Phase suggestions provide clear starting point for roadmap creation with explicit deliverables, feature mappings, and pitfall mitigations per phase. Research flags identify which phases need deeper investigation during planning with estimated research time. Confidence assessment honest about uncertainties (Spotify SDK verification, EventKit iOS 18 changes, ADHD UX parameters) and provides concrete mitigation strategies. Effort estimates enable milestone tracking.
