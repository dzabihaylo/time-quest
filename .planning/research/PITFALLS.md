# Domain Pitfalls: v3.0 Adaptive & Connected

**Domain:** Adding adaptive difficulty, Spotify integration, EventKit calendar intelligence, and UI/brand refresh to existing SwiftUI/SwiftData iOS app (66 files, 6,211 LOC, SchemaV3, CloudKit sync, Swift 6.0 strict concurrency)
**Researched:** 2026-02-14
**Overall confidence:** MEDIUM (training data only -- web search and Context7 unavailable for verification)
**Source basis:** Spotify Web API documentation, Spotify iOS SDK documentation, Apple EventKit/EventKitUI framework docs, Apple AVAudioSession programming guide, adaptive difficulty research in game design, SwiftData migration behavior -- all from training data (May 2025 cutoff). All claims should be verified against current documentation during implementation.

---

## Critical Pitfalls

Mistakes that cause data loss, require architectural rework, break existing v2.0 functionality, or violate the app's core design principles for its ADHD-target audience.

---

### Pitfall 1: Spotify Audio Session Category Conflict Destroys Existing Sound Effects

**What goes wrong:** Spotify playback requires an active audio session with a category that supports media playback (`.playback`). The existing `SoundManager` configures `AVAudioSession` as `.ambient`. When Spotify starts playback, it takes ownership of the audio session and changes the category. The app's game sound effects (estimate lock, reveal, level up, personal best, session complete) stop working or become inaudible because the audio session is now configured for Spotify's needs, not the app's. When the routine ends and Spotify stops, the audio session may not be restored to `.ambient`, leaving sound effects broken for subsequent non-Spotify sessions.

**Why it happens with THIS codebase:** `SoundManager.configureAudioSession()` sets `.ambient` once at init time and never rechecks. It uses `AVAudioSession.sharedInstance()` -- there is only ONE audio session per app. Spotify's iOS SDK (or the Web API controlling Spotify playback via Spotify Connect) doesn't directly touch the app's audio session, BUT if using the Spotify iOS SDK's `SPTAppRemote` to control playback within the app, the interaction between the SDK's audio expectations and the app's `.ambient` session is undefined and platform-version dependent.

The deeper issue: if TimeQuest plays a Spotify playlist through Spotify's own app (via deep link or App Remote), Spotify takes the audio session. When the user returns to TimeQuest, the app's `.ambient` session may fail to reactivate because Spotify is still playing. `AVAudioSession.setActive(true)` can throw when another app holds the session.

**Consequences:**
- Game sounds stop playing mid-routine (confusing -- "did my phone break?")
- After a Spotify-enhanced routine, all subsequent non-Spotify routines are silent
- If sound effects play OVER Spotify music (both trying to use the session), the teen hears a jarring audio collision
- The `.ambient` category is designed to mix with other audio -- but only when the OTHER app is the one playing. When TimeQuest is the one that triggered Spotify, the ownership semantics are reversed

**Warning signs:**
- `AVAudioSession.setActive(true)` throws after Spotify playback
- Sound effects work before first Spotify routine but not after
- Console shows "AVAudioSession deactivation failed" or "session interrupted"

**Prevention:**
- Do NOT use the Spotify iOS SDK for playback control. Use the Spotify Web API exclusively. The Web API creates/manages playlists and controls playback on the user's Spotify app via Connect -- TimeQuest never touches the audio session for music. Spotify plays in its own process with its own audio session. TimeQuest keeps `.ambient` for its sound effects. The two coexist naturally because `.ambient` is specifically designed to mix with other apps' audio
- Register for `AVAudioSession.interruptionNotification` to detect when another app (Spotify) takes audio focus. When interrupted, pause sound effects. When interruption ends, re-activate the session
- After returning from Spotify (via `SPTAppRemote` or URL scheme callback), explicitly re-configure the audio session: `try AVAudioSession.sharedInstance().setCategory(.ambient)` then `setActive(true)`
- Add an integration test: start a Spotify routine, play all 5 game sounds during the routine, end the routine, verify sounds still work in the next routine
- Consider adding a brief delay (0.5s) before playing game sounds after Spotify interaction to let the audio session settle

**Detection:** Test on a physical device with Spotify installed and playing. The Simulator does not have Spotify and cannot reproduce audio session conflicts.

**Phase relevance:** Must be resolved in the Spotify integration phase. The audio session architecture needs to be decided before writing any Spotify code.

**Confidence:** HIGH -- AVAudioSession being a singleton per-app and the `.ambient` mixing behavior are fundamental, well-documented iOS audio facts. The specific interaction with Spotify SDK vs Web API is MEDIUM confidence.

---

### Pitfall 2: Spotify OAuth Token Management in a Teen's App (Under-13 Complications, Token Expiry, Account Sharing)

**What goes wrong:** Spotify OAuth requires the user to log in via a web view or redirect to the Spotify app, grant permissions, and return with an authorization code that's exchanged for access + refresh tokens. For a 13-year-old:
1. She may have a Spotify account under a Family plan managed by a parent -- Spotify Family accounts for under-18s have restricted API scopes
2. Spotify access tokens expire every 60 minutes. If the app stores only the access token, every session after the first hour requires re-authentication. Re-auth means opening a web view mid-gameplay, which is jarring and breaks flow
3. If she shares the phone with a sibling, the Spotify account link is per-device, not per-TimeQuest-role. The parent role has no business seeing or managing Spotify tokens
4. Spotify's Terms of Service require users to be 13+ (or have parental consent in some jurisdictions). The app cannot silently handle a younger user's account

**Why it happens with THIS codebase:** The app currently has ZERO third-party authentication. Everything is local (SwiftData) or Apple-managed (CloudKit/iCloud -- automatic, no login). Adding Spotify OAuth introduces the first manual login flow, the first token storage requirement, and the first external service dependency. The codebase has no Keychain wrapper, no token refresh logic, no "connected accounts" UI pattern.

**Consequences:**
- Token expires mid-routine: the playlist stops, the "time cue" function fails, the player is confused and potentially stressed (ADHD: unexpected interruptions cause disproportionate frustration)
- Parent is confused by a Spotify login screen appearing in what they set up as a "time game"
- If tokens are stored in UserDefaults (not Keychain), they are unencrypted and visible in device backups
- If the token refresh silently fails (network issue), the app must gracefully degrade to no-Spotify mode without crashing or showing errors

**Warning signs:**
- `401 Unauthorized` from Spotify API after ~60 minutes
- User sees "Connect to Spotify" prompt every time they open the app
- Spotify connection works on setup but fails days later (refresh token expired or revoked)

**Prevention:**
- Store tokens in Keychain (not UserDefaults, not SwiftData). Use a simple Keychain wrapper -- do NOT add a heavy dependency like KeychainAccess for 2 keys
- Implement token refresh BEFORE the access token expires. On every Spotify API call, check token expiry. If expired or within 5 minutes of expiry, refresh first. The Spotify refresh token does not expire unless the user explicitly revokes access
- Make Spotify connection OPTIONAL. The entire Spotify feature is an enhancement, not a core game mechanic. The app must work perfectly without Spotify. Design the UI as "Connect Spotify for music cues" not "Set up Spotify to play"
- Put the Spotify connection in the PLAYER settings, not the parent setup. The player owns her Spotify account. The parent should not be involved in Spotify configuration
- Handle Spotify unavailability gracefully everywhere: no Spotify app installed, no Spotify account, free tier (limited API access), token expired, network down. Every Spotify code path needs a `else { /* play without music */ }` branch
- NEVER block gameplay on Spotify. If the API call to create a playlist takes 3 seconds, start the routine immediately and add the playlist asynchronously. If the playlist fails to create, the routine runs without music -- no error shown to the player

**Detection:** Test with: (a) no Spotify app installed, (b) Spotify app installed but not logged in, (c) Spotify Free account (no on-demand playback), (d) Spotify Premium account, (e) token that expired 2 hours ago, (f) airplane mode. All six must result in a working app.

**Phase relevance:** Token management architecture must be designed before building any Spotify feature. This is the foundation that playlist creation and playback control build on.

**Confidence:** MEDIUM -- Spotify OAuth flow and token expiry behavior (60-minute access tokens, long-lived refresh tokens) are well-documented. The specific SDK vs Web API decision and Spotify Family restrictions may have changed since May 2025.

---

### Pitfall 3: Adaptive Difficulty Creates a Punishment Loop for ADHD Players

**What goes wrong:** Adaptive difficulty adjusts the challenge level based on accuracy trends. The natural implementation is: player does well -> difficulty increases. Player does poorly -> difficulty decreases. For a neurotypical player, this feels balanced. For a player with ADHD-related time blindness:
1. **Bad days are MORE common and MORE random.** ADHD executive function fluctuates dramatically day-to-day and even hour-to-hour. Monday she might nail every estimate; Tuesday she can't focus and misses by 200%. If the system interprets Tuesday as "difficulty too high" and drops difficulty, it is responding to neurological fluctuation, not skill regression
2. **Dropping difficulty feels like punishment.** She knows the game is "easier now." She knows it's because she did badly. This is exactly the "You failed" framing the app was built to avoid. The curiosity-framed language ("Interesting!") becomes hollow when the GAME ITSELF is telling her she got worse by making things easier
3. **Oscillation trap:** Good day -> difficulty up. Bad day (ADHD fluctuation) -> difficulty down. Good day -> difficulty up. She never stabilizes, and the constant adjustment feels unsettling and unpredictable

**Why it happens with THIS codebase:** The existing scoring system (`TimeEstimationScorer`) uses fixed thresholds: spot_on (10%/15s), close (25%), off (50%), way_off (50%+). The `InsightEngine` detects trends via linear regression. If adaptive difficulty simply adjusts these thresholds based on trend direction (improving -> tighten thresholds, declining -> loosen), it directly creates the punishment loop described above.

The existing `CalibrationTracker` (3-session minimum before insights) is the right instinct but is too coarse for adaptive difficulty. Three sessions is not enough to distinguish skill change from ADHD fluctuation.

**Consequences:**
- Player feels the game is "babying" her on bad days -- infantilizing, the opposite of the "grown-up" feeling she values
- Player feels the game is punishing her on bad days -- "even my game thinks I can't do this"
- XP earning rate oscillates with difficulty, making progression feel random and unearned
- The game-first design principle is violated: the game is now reacting to her disability, not her skill

**Warning signs:**
- Difficulty level changes every 1-2 sessions
- Player comments "it got easier" or "it got harder" (she should not notice)
- Difficulty decreases correlate with days, not with specific task types
- The player stops playing after a difficulty decrease (she interprets it as the game judging her)

**Prevention:**
- Use a LONG WINDOW for difficulty adjustment: 10-15 sessions minimum, not 3-5. This smooths out ADHD day-to-day fluctuation and only responds to genuine skill change
- Make difficulty adjustment INVISIBLE. Never show "Level 3 difficulty" or "Easy mode." Adjust the internal thresholds for rating bands (spot_on, close, off, way_off) without any UI indication. The player should feel like she's getting better, not that the game got easier
- ONLY adjust upward. Do not decrease difficulty when accuracy drops. Instead, PAUSE at the current difficulty during declining trends. Rationale: difficulty should ratchet up as she masters each level, but never drop back. A bad week is a bad week -- the game waits patiently, it does not retreat
- Adjust PER TASK, not globally. She might be spot-on for "Brush teeth" (short, familiar) but way_off for "Pack backpack" (variable, executive-function-dependent). A single global difficulty slider would tighten "Brush teeth" too much while being too loose for "Pack backpack"
- Tie difficulty to the estimation threshold bands in `TimeEstimationScorer`, not to XP. Difficulty affects what counts as "spot_on" (e.g., tightening from 15s/10% to 12s/8%), not how much XP she earns. This preserves the feeling of "I'm getting more precise" without changing the reward structure
- Add a floor: difficulty never drops below the initial calibration thresholds. Even after 100 sessions, "within 15 seconds or 10%" is still spot_on at minimum

**Detection:** Simulate 30 sessions with realistic ADHD-pattern accuracy (high variance, clustered bad days). Verify that difficulty changes fewer than 3 times in 30 sessions and never decreases.

**Phase relevance:** The adaptive difficulty algorithm design must be finalized before implementation. Getting this wrong requires redesigning the core game feel. Build it as a pure domain engine (`DifficultyEngine`) with comprehensive tests before wiring it to the UI.

**Confidence:** HIGH for the ADHD-specific concerns (well-documented executive function variability). MEDIUM for the specific prevention strategies (game design judgment, not technical certainty).

---

### Pitfall 4: Adaptive Difficulty Destabilizes the XP/Leveling Economy

**What goes wrong:** If tighter thresholds make spot_on harder to achieve, the player earns fewer spot_on ratings, and therefore less XP per session. If the XP curve was tuned for the initial thresholds, tightening them without adjusting XP rewards means leveling slows down as the player improves. She goes from leveling up every few days to leveling up once a week, and engagement drops because the progression feels stalled.

Conversely, if XP is adjusted upward to compensate for harder thresholds, existing players who haven't triggered difficulty increases yet earn XP at the old rate while advanced players earn more -- creating an inconsistent progression feel.

**Why it happens with THIS codebase:** `XPEngine.xpForEstimation(rating:)` returns fixed XP per rating: spot_on=100, close=60, off=25, way_off=10. `LevelCalculator` uses `baseXP * level^1.5` for the level curve. These are tuned together. If adaptive difficulty changes the PROBABILITY of each rating (by tightening thresholds), it changes the expected XP per session without changing the level curve. The math breaks.

Example: At initial thresholds, average session earns ~280 XP (mix of ratings). At tightened thresholds, average session earns ~180 XP (fewer spot_on, more close/off). Level 10 requires 3,162 XP. At 280 XP/session, that is ~11 sessions. At 180 XP/session, that is ~18 sessions. The player's leveling rate drops 40% just because she got better.

**Consequences:**
- Player improves but leveling SLOWS -- exactly backwards from what game feel requires
- Player feels punished for getting better (the opposite of positive reinforcement)
- XP earned per session becomes unpredictable, making weekly reflections' accuracy comparisons misleading
- If XP is adjusted per-difficulty, the XP history becomes incomparable across difficulty levels (insight: "Your accuracy improved 20%!" but XP went down)

**Warning signs:**
- Sessions per level increases as player advances (should stay roughly constant)
- Player level plateaus despite playing regularly
- XP variance per session increases as difficulty adjusts

**Prevention:**
- Decouple difficulty from XP calculation entirely. Difficulty adjusts THRESHOLDS for rating bands, but XP is based on ACCURACY PERCENT, not on rating. Example: XP = accuracyPercent * multiplier. This way, a player who scores 92% accuracy always gets ~92 XP regardless of whether 92% is "spot_on" (at initial thresholds) or "close" (at tightened thresholds)
- Alternative: keep rating-based XP but add a difficulty multiplier. If thresholds are tighter, multiply XP by 1.2x. This explicitly rewards the harder challenge. But this adds complexity and may feel opaque to the player
- Preferred approach: ratings (spot_on, close, off, way_off) are for FEEDBACK (the emoji, the celebration, the language). XP is for PROGRESSION (the level bar). Ratings can tighten with difficulty; XP is always proportional to accuracy. These are two separate systems that happen to share the accuracy input
- If changing the XP formula, recalculate the expected sessions-to-level across the difficulty range. The player should level up at roughly the same rate regardless of difficulty. Difficulty affects the QUALITY of the game experience (tighter challenge, more satisfying spot_on), not the SPEED of progression
- Test the economy with a spreadsheet simulation before implementing. Model 100 sessions across 5 difficulty adjustments. Verify leveling rate stays within +/- 20% of the initial rate

**Phase relevance:** The adaptive difficulty engine and XP engine must be redesigned together. Do not implement difficulty adjustments without simultaneously verifying the XP economy. This is the same phase.

**Confidence:** HIGH -- this is basic game economy math. The specific numbers are from the existing `XPConfiguration`.

---

### Pitfall 5: SchemaV4 Migration Breaks CloudKit Sync for Existing Users

**What goes wrong:** v3.0 needs new model fields for adaptive difficulty (per-task difficulty level, historical threshold data), Spotify integration (access token metadata, playlist preferences, linked account flag), and calendar intelligence (EventKit event IDs, schedule-aware activation flags). These require a SchemaV4. If the migration is not lightweight, it corrupts the existing CloudKit-synced data or fails to open the store on devices that haven't updated yet.

**Why it happens with THIS codebase:** The migration history is already V1 -> V2 -> V3, all lightweight. CloudKit-backed SwiftData stores have stricter migration requirements than local-only stores because the CKRecord schema in iCloud must remain compatible. Adding new fields with defaults is safe (lightweight). Adding new models is usually safe. But:
- If a user has two devices, updates one to v3.0 (SchemaV4) and the other is still on v2.0 (SchemaV3), CloudKit will attempt to sync V4 records to the V3 device. The V3 device will see unknown fields and may ignore them, misinterpret them, or crash depending on the SwiftData version
- If any V3->V4 change is NOT lightweight (property rename, type change, relationship restructuring), the migration fails and the store cannot be opened

**Consequences:**
- App crashes on launch after update (store can't open with new schema)
- Data synced from updated device to non-updated device causes the non-updated device to crash or lose data
- If the migration creates a new store file, all v2.0 data (XP, sessions, routines, insights history) is lost

**Warning signs:**
- Console shows "The model used to open the store is incompatible with the one used to create the store"
- App opens to empty state after update
- CloudKit sync errors on devices with different schema versions

**Prevention:**
- EVERY new field must have a default value. No exceptions. Review the v3.0 model changes as a complete list before writing any code
- Do NOT store Spotify tokens in SwiftData. Use Keychain. This avoids adding sensitive fields to the CloudKit-synced schema entirely
- For adaptive difficulty data, add fields to existing models rather than creating new relationship-heavy models when possible. Example: `var difficultyLevel: Int = 1` on the existing `Routine` or a new flat `DifficultyState` model with no relationships
- For calendar integration, store EventKit identifiers as simple String properties, not as new models with relationships to Routine
- Test migration with a real V3 store file: build the current app, populate data, then install the V4 build on top. Verify all data survives
- Keep the migration lightweight. If any change requires a custom migration stage, reconsider the model design. Custom migrations with CloudKit are fragile and undertested in SwiftData
- Add the V4 schema and migration stage to `TimeQuestMigrationPlan` with a new `v3ToV4` stage
- Consider whether calendar/Spotify metadata even NEEDS to sync via CloudKit. If these are device-local preferences (the Spotify account on this phone, the calendar on this phone), they should be in a separate local-only `ModelConfiguration`, not in the CloudKit-backed configuration

**Detection:** Write a migration test that opens a V3 store with V4 schemas. Run it before implementing any features.

**Phase relevance:** Schema migration must be the FIRST task of v3.0, before any feature implementation. Same pattern as v2.0.

**Confidence:** HIGH -- same migration constraints as v2.0, validated by the successful V1->V2->V3 migration history.

---

### Pitfall 6: EventKit Calendar Access Requires Parental Consent and Privacy Justification That Contradicts "Invisible Parent"

**What goes wrong:** EventKit requires `NSCalendarsUsageDescription` in Info.plist and an explicit permission prompt: "TimeQuest would like to access your calendar." For a 13-year-old's phone:
1. The permission prompt appears to the PLAYER, not the parent. The player must tap "Allow." If she doesn't understand why a game needs her calendar, she'll tap "Don't Allow" and the feature silently fails forever (iOS doesn't re-prompt after denial)
2. The calendar on her phone may be a shared family calendar managed by a parent. Accessing it reveals the parent's schedule, appointments, and potentially sensitive information to the app
3. Under COPPA / Apple's age-gating guidelines, accessing calendar data for a user under 13 requires verifiable parental consent. At 13, this may or may not apply depending on jurisdiction, but the App Store reviewer will scrutinize calendar access in a teen app
4. The permission prompt says "TimeQuest" -- the parent sees this and wonders "why does her game need calendar access?" This makes the parent suspicious, potentially revealing the parent's involvement ("did you set this up to spy on me?")

**Why it happens with THIS codebase:** The app currently requests ZERO permissions beyond CloudKit (which is silent/automatic) and optional notification permission (which the player understands: "game wants to send reminders"). Calendar access is a categorically different permission -- it's access to personal schedule data, which is sensitive and unusual for a game.

The "invisible parent" design principle creates a tension: the parent configured routines but the player doesn't know. If the app accesses the calendar to "know about school schedule," the player might wonder HOW the app knows her schedule. If calendar events are named "School" and the routine is also named "School Morning," the connection between parent-configured routine and real-world calendar becomes visible.

**Consequences:**
- Player denies calendar access -> feature is permanently disabled -> all calendar intelligence code is dead weight
- Player's calendar reveals information the app should not have (medical appointments, family events, school disciplinary meetings)
- App Store rejection for insufficient privacy justification ("why does a time estimation game need calendar access?")
- The "game" illusion breaks when a game starts asking about her schedule

**Warning signs:**
- High percentage of users deny calendar permission (>50% for a game is expected)
- App Store reviewer asks for a video demo showing why calendar access is needed
- Player asks "Why does my game need my calendar?"

**Prevention:**
- Frame calendar access as a PLAYER CHOICE, not a requirement. "Want TimeQuest to know your schedule? It can suggest quests when you have time." Never force or nag
- Use READ-ONLY access (`EKAuthorizationStatus` with `.fullAccess` or `.writeOnly` -- read-only is sufficient). The app should never modify calendar events
- Do NOT access all calendar events. Only query for events in a specific time window (today, this week). Do not store event details in SwiftData. Use EventKit data transiently to determine "is there a gap in the schedule?" and discard the event details immediately
- Write a clear, teenager-friendly `NSCalendarsUsageDescription`: "TimeQuest can check your schedule to suggest the best time for quests. Your calendar data stays on your phone and is never stored or shared."
- Handle denial gracefully: the app works identically without calendar access. Calendar intelligence is a NICE-TO-HAVE enhancement to routine scheduling, not a core feature
- Consider an alternative that avoids EventKit entirely: let the PARENT configure schedule awareness in the parent setup ("She has school Mon-Fri 8am-3pm, activity Tuesdays and Thursdays"). This keeps the schedule data in TimeQuest's own data model, avoids the permission prompt, and is architecturally simpler. The parent already knows her schedule -- that's why they set up routines for specific days. Calendar integration adds convenience but also adds privacy risk
- If using EventKit, put the connection setup in PLAYER settings (she controls it), not in parent setup (avoids the "parent is watching" feeling)

**Detection:** Test with calendar permission denied. Every screen, every feature must work. Calendar intelligence is purely additive.

**Phase relevance:** The calendar access strategy (EventKit vs parent-configured schedule) is an architectural decision that must be made before implementation. If choosing EventKit, the permission flow UX must be designed alongside the feature.

**Confidence:** HIGH for the permission mechanics and privacy implications. MEDIUM for App Store review risk (depends on reviewer interpretation).

---

## Moderate Pitfalls

Mistakes that cause significant friction, rework of a subsystem, or degraded user experience.

---

### Pitfall 7: UI Theme System Retrofit Creates a 20+ View Refactor with High Regression Risk

**What goes wrong:** Retrofitting a theme/design system across 20+ existing views means touching every file that uses hardcoded colors, font sizes, spacing, and corner radii. Each touched file is a regression risk -- a misplaced `.padding()`, a wrong color, a broken layout. The refactor touches files that have been stable since v1.0, introducing bugs in working features.

**Why it happens with THIS codebase:** The current views use SwiftUI's default styling with minimal customization:
- Colors: `.tint`, `.secondary`, `.tertiary`, `Color(.systemGray6)` -- system defaults
- Fonts: `.largeTitle`, `.headline`, `.caption` -- system text styles
- Spacing: hardcoded values (24, 16, 12, 8) sprinkled across views
- Corner radii: `RoundedRectangle(cornerRadius: 12)` hardcoded in each view

There is no design token system, no shared style constants, no theme-aware color definitions. Moving to a theme system means either:
(a) Creating a global `Theme` environment object and updating every view to read from it -- high touch count
(b) Using SwiftUI's `.tint()` and asset catalog colors -- lower touch count but less flexible

**Consequences:**
- Touching 20+ views risks introducing layout bugs in stable features (PlayerHomeView, QuestView, EstimationInputView, AccuracyRevealView, etc.)
- If the theme is not comprehensive, some views use old colors and some use new ones, creating a jarring visual inconsistency
- The refactor blocks other v3.0 work because every view is "in progress" simultaneously
- Merge conflicts if other features (Spotify UI, Calendar UI, Difficulty UI) are developed in parallel

**Warning signs:**
- PR has 20+ files changed for "just colors and fonts"
- Visual inconsistencies between themed and unthemed views
- Layout regressions in estimation flow (the most critical UX path)

**Prevention:**
- Define theme tokens as a lightweight struct, not a heavy framework: `enum AppTheme { static let cardBackground = Color(.systemGray6); static let cornerRadius: CGFloat = 12 }` -- this is a find-and-replace refactor, not an architecture change
- Do the UI refresh in a SINGLE focused phase with no other feature work. Do not interleave theme changes with Spotify or Calendar work
- Refactor views in order of risk: start with low-risk views (settings, stats, patterns) and end with high-risk views (estimation input, accuracy reveal, session summary). This way, if the approach needs adjustment, it's discovered on low-stakes views
- Use SwiftUI previews aggressively during the refactor. Every view that's touched must have a preview that visually validates the change
- Do NOT change layout/spacing in the same PR as color/font changes. Separate "new colors" from "new layout" into distinct passes. Colors are low-risk; layout changes are high-risk
- Consider whether the "brand refresh" actually requires touching existing views at all. If the refresh is primarily about: new app icon, new accent color (set in asset catalog), new fonts (set via `UIFont` configuration or `.font(.custom()))`, and new onboarding/splash -- most existing views automatically pick up the new accent color via `.tint` without code changes

**Phase relevance:** UI refresh should be the LAST phase of v3.0, after all features are working. This minimizes merge conflicts and ensures the theme is applied to the final set of views (including new Spotify and Calendar views).

**Confidence:** HIGH -- this is a standard refactoring risk analysis based on the current codebase's styling approach.

---

### Pitfall 8: Spotify Web API Requires a Backend Server That Does Not Exist

**What goes wrong:** The Spotify Web API's Authorization Code Flow requires a client secret to exchange the authorization code for tokens. The client secret MUST NOT be embedded in the iOS app binary (it would be trivially extractable). The standard architecture is: iOS app -> your backend server (holds client secret) -> Spotify API. TimeQuest has no backend server.

Alternatives:
1. **Authorization Code Flow with PKCE** -- does NOT require a client secret. Supported by Spotify since 2019. This is the correct approach for mobile apps. But it has caveats: you still need a registered redirect URI, and the token refresh endpoint is public (no secret), which is accepted security practice for mobile
2. **Spotify iOS SDK (SPTAppRemote)** -- handles auth and playback control but requires the Spotify app to be installed. If the teen doesn't have Spotify installed (uses a web player), the SDK fails
3. **Implicit Grant** -- returns an access token directly (no server needed) but tokens expire in 60 minutes and there is NO refresh token. Every hour requires re-authentication. Unusable for a daily-use app

**Why it happens with THIS codebase:** No backend, no server infrastructure, no API keys managed server-side. The app is pure client-side iOS. This is a strength for simplicity but a constraint for third-party API integration.

**Consequences:**
- If you embed the client secret in the app: security vulnerability, Spotify can revoke your API key, App Store review may flag it
- If you use Implicit Grant: hourly re-authentication destroys UX
- If you build a backend just for Spotify: massive scope increase, ongoing maintenance, server costs, deployment complexity

**Warning signs:**
- Stack Overflow answers suggesting "just put the client secret in the app" (wrong, insecure)
- Spotify API returning `invalid_client` because the secret-less flow is misconfigured
- Token refresh failing because Implicit Grant was used (no refresh token)

**Prevention:**
- Use Authorization Code Flow with PKCE. This is the Spotify-recommended flow for mobile apps. It does NOT require a backend server. The iOS app:
  1. Generates a code_verifier and code_challenge (PKCE)
  2. Opens `accounts.spotify.com/authorize` with the code_challenge in ASWebAuthenticationSession
  3. Receives the authorization code via redirect URI
  4. Exchanges the code + code_verifier for access + refresh tokens directly with `accounts.spotify.com/api/token` (no client secret needed with PKCE)
  5. Stores tokens in Keychain
  6. Refreshes access tokens using the refresh token when they expire
- Register a custom URL scheme or Universal Link as the redirect URI in the Spotify Developer Dashboard
- Use `ASWebAuthenticationSession` for the OAuth flow -- it handles the web view, is secure (no cookie theft), and returns the authorization code via the redirect
- Do NOT use `SFSafariViewController` or `WKWebView` for OAuth -- `ASWebAuthenticationSession` is the Apple-recommended approach and is required for App Store compliance
- Test with Spotify Free accounts. Some Web API endpoints (playback control, playlist creation) require Premium. Determine which endpoints you need and verify they work with Free tier. If Premium is required, handle Free accounts gracefully ("Connect Spotify Premium for music cues during quests")

**Detection:** Implement the full auth flow end-to-end as the first Spotify task. Do not build playlist/playback features until auth is working.

**Phase relevance:** Auth flow is the prerequisite for ALL Spotify features. Build and test it first.

**Confidence:** MEDIUM -- Spotify's PKCE support was added in 2019 and is documented. The specific API scopes and Free vs Premium restrictions may have changed since May 2025. Verify against current Spotify developer docs.

---

### Pitfall 9: Spotify Playlist Duration Matching Is Imprecise and Unreliable

**What goes wrong:** The core Spotify concept is: "routine takes ~25 minutes, create a playlist that's ~25 minutes long, songs serve as progress markers." But:
1. Spotify's Web API returns track durations in milliseconds, but you can't guarantee a playlist will be EXACTLY 25 minutes. You'll get 23:47 or 26:12. The mismatch means "I finished but music is still playing" or "music ended but I'm not done"
2. If using the player's own library/liked songs, there may not be enough tracks to fill 25 minutes, or the tracks may vary wildly in length (2-minute pop songs vs 8-minute progressive rock)
3. The routine's total estimated time is the PLAYER'S estimate, not the actual time. If she estimates 20 minutes but it takes 35, the playlist ends 15 minutes early. If she estimates 40 minutes, the playlist has 15 minutes of silence at the end
4. Song transitions (crossfade, gaps between tracks) affect perceived timing. "I'm on my 3rd song" is a rough progress marker, not a precise one

**Why it happens with THIS codebase:** The routine's time is not fixed -- it's the SUM of the player's per-task estimates (which are the whole point of the game: she's learning to estimate). The playlist is created based on estimates that are, by definition, probably wrong. The better she gets at estimating, the more accurate the playlist. But early on, the playlist will be wildly mismatched.

**Consequences:**
- Music ends mid-routine -> player loses her audible time cue -> ADHD: losing structure mid-task causes anxiety/disorientation
- Music plays long after routine ends -> confusing, feels broken
- "I'm on my 3rd song" tells her nothing if songs are 2-7 minutes long
- If playlist creation fails (API error, no matching tracks), the routine starts in silence and the player expected music

**Warning signs:**
- Player complains "the music ended early" or "music kept playing after I was done"
- Playlist total is >20% off from routine estimate
- Player cannot use songs as time markers because song lengths vary too much

**Prevention:**
- Do NOT try to match playlist duration exactly to routine estimate. Instead, create a playlist that is 10-15% LONGER than the estimate. "Music runs a few minutes past the end" is better than "music stops before you're done." If the routine ends early, the player just pauses/stops Spotify
- Use a simple algorithm: sum track durations, add tracks until you exceed the target + buffer. Prefer tracks in a consistent length range (3-5 minutes) so "each song is roughly one task's worth of time" holds approximately
- Clearly communicate to the player: "Music will play during your quest. It might end a bit before or after you finish -- that's normal!" Set expectations, don't promise precision
- Use the ACTUAL cumulative time (not estimates) from previous sessions to size the playlist for returning routines. After calibration, the actual total time is a better predictor than the estimate. The `InsightEngine` already tracks `recentActualSeconds` per task -- sum them for the routine's expected duration
- Handle playlist creation failure gracefully: "Couldn't create your playlist this time. Your quest will work without music." No error dialogs, no retry prompts. Just skip music
- Consider offering the player a choice: "Use your playlist" (existing Spotify playlist she made) vs "Auto-create a playlist." Teens often have curated playlists they prefer over algorithmic ones

**Phase relevance:** Playlist duration matching is a design problem, not just an implementation problem. The algorithm and UX expectations should be defined before building the playlist creation API calls.

**Confidence:** HIGH for the duration mismatch problem (inherent in the concept). MEDIUM for specific prevention strategies (UX design judgment).

---

### Pitfall 10: EventKit Queries on Main Thread Cause UI Freeze

**What goes wrong:** EventKit's `EKEventStore` is not thread-safe in the way you might expect. `events(matching:)` is a synchronous call that can take 100ms-2s depending on calendar data volume. If called on the main thread during view appearance (the same pattern as the current `loadTodayQuests()`), it blocks the UI.

**Why it happens with THIS codebase:** The current data loading pattern is synchronous on `@MainActor`:
```swift
.onAppear {
    loadTodayQuests()
    loadProgression()
    loadReflection()
}
```
Adding `loadCalendarEvents()` to this pattern would add another synchronous main-thread call. With SwiftData queries + EventKit queries + weekly reflection computation all running on appear, the home screen could freeze for 1-2 seconds on older devices.

**Consequences:**
- Home screen takes noticeably longer to appear (every app open, not just first time)
- On devices with large calendars (shared family calendar with years of events), the freeze can be 2+ seconds
- The player opens the app, sees a frozen UI, and assumes it's broken

**Prevention:**
- Wrap EventKit queries in a `Task` with `async`/`await`. `EKEventStore.requestFullAccessToEvents()` already returns async. The event query itself is synchronous but should be dispatched to a background thread
- Cache calendar-derived data (e.g., "is today a school day?", "next event starts in 45 minutes") at app launch and refresh only when the app returns from background
- Set a tight date range: only query today's events + tomorrow morning. Do not query a full week or month of calendar data
- Use EventKit's `EKEventStoreChanged` notification to refresh cached data when the calendar changes, rather than re-querying on every view appear

**Phase relevance:** Address during calendar intelligence implementation. Standard async pattern.

**Confidence:** HIGH -- EventKit synchronous query behavior is well-documented.

---

### Pitfall 11: Spotify Free Tier Cannot Play On-Demand Tracks

**What goes wrong:** Spotify Free users cannot play specific tracks on-demand on mobile. They can only shuffle-play within playlists or albums. The Web API's `PUT /me/player/play` endpoint with specific track URIs returns a `403 Forbidden` for Free accounts. If TimeQuest creates a carefully sequenced playlist and tries to start playback, it fails for Free users.

**Why it happens:** Spotify's business model reserves on-demand mobile playback for Premium subscribers. The Web API playback control endpoints reflect this restriction. Creating a playlist works (that's just metadata), but controlling playback of that playlist may not work as expected for Free users.

**Consequences:**
- Free-tier user connects Spotify, sees "playlist created!" but music doesn't play or shuffles randomly
- The carefully ordered playlist (songs chosen for duration matching) plays in random order, destroying the "progress marker" concept
- The player's parents may not want to pay for Spotify Premium just for this game feature

**Prevention:**
- During Spotify connection setup, detect the user's subscription tier via `GET /me` endpoint (the `product` field: "premium", "free", "open")
- If Free tier: show a clear, non-judgmental message: "Spotify music cues work best with Spotify Premium. You can still play your own music in the background while doing quests!" Do NOT show "Upgrade to Premium" -- that's a Spotify sales pitch in a teen's game
- Consider an alternative approach that works for ALL users: instead of controlling Spotify playback via API, simply SUGGEST a playlist. "We made you a playlist for this quest! Open it in Spotify when you're ready." The player opens Spotify, hits play, returns to TimeQuest. No API playback control needed. This works with Free AND Premium and avoids the entire playback API complexity
- If the "suggest, don't control" approach is used, the only API needed is playlist creation (`POST /users/{user_id}/playlists` and `POST /playlists/{playlist_id}/tracks`), which works for all tiers
- This "suggest" approach also avoids the audio session conflict (Pitfall 1) entirely because TimeQuest never controls Spotify playback -- Spotify controls its own playback in its own app

**Phase relevance:** The Free vs Premium tier decision drives the entire Spotify architecture. Decide "control playback" vs "suggest playlist" before writing any Spotify code.

**Confidence:** MEDIUM -- Spotify Free tier restrictions are well-known but the specific API endpoint restrictions may have changed. Verify against current Spotify Web API documentation.

---

### Pitfall 12: Adaptive Difficulty Interacts Badly with Calibration and Insights

**What goes wrong:** The existing `CalibrationTracker` (3 sessions before insights) and `InsightEngine` (5 sessions minimum, linear regression for trends) both assume FIXED accuracy thresholds. If adaptive difficulty changes the thresholds mid-history, the trend analysis becomes meaningless:
- InsightEngine detects "improving trend" because accuracy percent went from 60% to 80%. But the thresholds also tightened, so 80% at the new thresholds is equivalent to 70% at the old thresholds. The "improvement" is partly real skill gain and partly an artifact of threshold changes
- `CalibrationTracker` says "calibration complete after 3 sessions" but if thresholds adjust on session 4, the player is effectively recalibrated -- but the UI doesn't show the "Calibrating" badge again

**Why it happens with THIS codebase:** `TimeEstimationScorer.score()` uses absolute thresholds (10%/15s, 25%, 50%) to produce ratings. `InsightEngine.detectTrend()` uses `accuracyPercent` which is computed by `TimeEstimationScorer` with those fixed thresholds. If thresholds change, `accuracyPercent` from old sessions and new sessions are computed on different scales. Comparing them is comparing apples to oranges.

**Consequences:**
- Trend analysis becomes unreliable after any difficulty adjustment
- Weekly reflections show "accuracy improved 15%!" when it actually held steady (the improvement is from loosening thresholds) or vice versa
- The player loses trust in insights because they don't match her subjective experience

**Prevention:**
- Store the RAW data (estimated seconds, actual seconds, difference seconds) and compute derived metrics (accuracy percent, rating) at QUERY TIME, not at storage time. Currently, `TaskEstimation` stores both raw data AND computed metrics (`accuracyPercent`, `ratingRawValue`). For trend analysis, recompute accuracy from raw data using CURRENT thresholds so all data points are on the same scale
- Alternative: store the difficulty level / threshold values alongside each estimation. Then `InsightEngine` can normalize across difficulty levels when computing trends
- Preferred: keep `accuracyPercent` based on absolute (not difficulty-adjusted) thresholds in the stored data. Use difficulty-adjusted thresholds ONLY for the immediate feedback (spot_on/close/off/way_off rating and feedback message). This way, trend analysis always uses the absolute accuracy, which is the true measure of skill improvement. Difficulty affects game feel; absolute accuracy measures real learning
- The `TimeEstimationScorer.score()` should take thresholds as a parameter, not use hardcoded constants. The caller decides which thresholds to use: absolute for storage, difficulty-adjusted for display

**Phase relevance:** The separation between "absolute accuracy for storage/analysis" and "difficulty-adjusted rating for display" must be designed before implementing either adaptive difficulty or insight modifications.

**Confidence:** HIGH -- this is a direct analysis of the existing `accuracyPercent` storage and `InsightEngine` query patterns.

---

### Pitfall 13: Spotify Connection Breaks the "No Login Required" Simplicity

**What goes wrong:** TimeQuest currently requires ZERO logins. The player opens the app and plays. The parent accesses setup via a hidden PIN. Adding Spotify OAuth introduces a login flow, a "connected accounts" concept, and a "what if I'm not logged in?" state. This complexity is at odds with the app's simplicity and the ADHD-friendly design principle of "no overwhelming options."

For a 13-year-old with ADHD, a multi-step OAuth flow (open web view -> log in to Spotify -> grant permissions -> wait for redirect -> see "connected!" -> return to game) is exactly the kind of multi-step process she struggles with. If the flow fails at any point (wrong password, captcha, Spotify app not installed, redirect fails), the experience is frustrating and she may never try again.

**Consequences:**
- OAuth flow fails and player doesn't know why (just sees a web view that didn't work)
- Player gets stuck in the OAuth flow and can't get back to the game
- "Connect to Spotify" button persists on the home screen, adding visual noise for a player who chose not to connect
- The app feels more complex with a "connected accounts" section in settings

**Prevention:**
- Hide Spotify connection deep in settings, not on the home screen or quest start. It should be discoverable but not prominent. "Settings -> Music -> Connect Spotify"
- Make the OAuth flow INTERRUPTIBLE. If she taps away from the web view, return to the game with no error. She can try again later
- After successful connection, never mention Spotify again unless she goes to settings. The playlist creation happens silently. "Your quest has a playlist" appears as a subtle note, not a Spotify-branded takeover
- Do NOT show Spotify branding prominently in the app. "Music" not "Spotify." If she switches to Apple Music later, the branding should be abstract
- One-tap connection ideal: if the Spotify app is installed, use `ASWebAuthenticationSession` with `prefersEphemeralWebBrowserSession: false` so her existing Spotify login session in Safari carries over and she just taps "Agree" instead of typing credentials
- Provide a "Disconnect Spotify" button that is equally easy to find and use. Disconnecting should immediately and completely remove all Spotify integration with no residual UI

**Phase relevance:** OAuth flow UX should be designed alongside the technical auth implementation. The technical flow and the UX flow are the same thing.

**Confidence:** MEDIUM -- the OAuth flow mechanics are well-understood. The ADHD UX judgment is based on the app's design principles, not clinical research.

---

## Minor Pitfalls

Mistakes that cause friction or suboptimal outcomes but are fixable without major redesign.

---

### Pitfall 14: EventKit Calendar Data Does Not Sync Across Devices the Same Way

**What goes wrong:** EventKit data (calendar events) is device-local and syncs via the user's calendar account (iCloud Calendar, Google Calendar, etc.), not via TimeQuest's CloudKit container. If TimeQuest stores EventKit identifiers (`EKEvent.eventIdentifier`) in SwiftData models and those models sync via CloudKit to another device, the event identifiers are invalid on the other device (different EventKit store, potentially different calendar accounts).

**Prevention:**
- Never store EventKit identifiers in CloudKit-synced models. Use them transiently at query time only
- If calendar-derived data needs persistence (e.g., "school days are Mon-Fri"), store the DERIVED schedule (days and times) as simple values, not EventKit references
- Better: store schedule configuration as user-entered data (parent configures "school Mon-Fri 8am-3pm") and use EventKit only to SUGGEST schedule updates, not as the source of truth

**Phase relevance:** Calendar architecture decision.

**Confidence:** HIGH -- EventKit identifier portability is well-documented as device-local.

---

### Pitfall 15: UI Brand Refresh Alienates the Existing Player

**What goes wrong:** The app has been building familiarity and comfort over weeks of use. A dramatic visual change (new colors, new fonts, new layout, new app name) can feel disorienting, especially for a player with ADHD who may rely on visual consistency for app navigation. "My game changed and I don't know where things are" triggers frustration, not delight.

**Prevention:**
- Make changes evolutionary, not revolutionary. New accent color: fine. Entirely new layout: risky
- Keep the core game flow (estimate -> active -> reveal -> summary) visually recognizable. New skin, same skeleton
- Keep the app name if the player has emotional attachment to "TimeQuest." A name change risks breaking the association with her progress
- If renaming, introduce it gradually: "TimeQuest is now [NewName]" on first launch, not a silent switch
- Preserve the information hierarchy: XP bar, level badge, streak badge should stay in the same relative positions. The player has built muscle memory for where to look
- Test with the actual player if possible. A 13-year-old's reaction to "they changed my game" is unpredictable and important

**Phase relevance:** UI refresh should be the last phase so the player has maximum time with the current design and the refresh applies to the final feature set.

**Confidence:** MEDIUM -- UX design judgment for ADHD users. The specific impact depends on the degree of visual change.

---

### Pitfall 16: Spotify API Rate Limiting During Playlist Creation

**What goes wrong:** Spotify's Web API has rate limits (documented as "requests per 30 seconds" but the exact numbers are undisclosed and vary by endpoint). If the app creates a playlist on every routine start, and the player does 2-3 routines per day, this is not a rate limiting risk. But during development and testing, rapid iteration (creating 50 playlists in a testing session) will hit rate limits, producing `429 Too Many Requests` responses.

**Prevention:**
- Cache created playlists. If the player starts the same routine with similar duration, reuse the existing playlist rather than creating a new one each time
- Implement exponential backoff for 429 responses: wait 1s, 2s, 4s, retry. Do not retry immediately
- In development, use Spotify's rate limit headers (`Retry-After`) to respect limits
- Consider creating playlists asynchronously (at routine save time or scheduling time, not at routine start time) to avoid delaying routine start

**Phase relevance:** Standard API integration concern. Handle during Spotify implementation.

**Confidence:** MEDIUM -- Spotify rate limits exist but thresholds are undocumented and may vary.

---

### Pitfall 17: Swift 6.0 Strict Concurrency Clashes with Spotify/EventKit Callbacks

**What goes wrong:** The codebase uses Swift 6.0 strict concurrency with `@MainActor` annotations on all ViewModels, repositories, and services. Spotify Web API calls and EventKit queries need to happen off the main thread. The strict concurrency model will flag any callback-based API that crosses actor boundaries without explicit handling. `EKEventStore.requestFullAccessToEvents(completion:)` and URL session callbacks from Spotify API calls will produce warnings or errors under strict concurrency.

**Prevention:**
- Use `async`/`await` wrappers for all Spotify API calls (URLSession already supports `async` via `data(for:)`)
- Use `withCheckedContinuation` to bridge EventKit's callback-based `requestFullAccessToEvents` to `async`/`await`
- Create Spotify and EventKit service classes as actors (not `@MainActor`) to isolate their concurrent work. Only publish results to `@MainActor` ViewModels via `@MainActor`-isolated properties
- The existing pattern of `@preconcurrency import SwiftData` and `nonisolated(unsafe)` shows the codebase already manages concurrency boundaries. Follow the same pattern for new services
- Test with strict concurrency enabled (it already is) -- the compiler will catch most issues

**Phase relevance:** Applies to both Spotify and EventKit implementation. Standard Swift 6.0 pattern.

**Confidence:** HIGH -- Swift 6.0 strict concurrency behavior is well-documented.

---

### Pitfall 18: generate-xcodeproj.js Must Be Updated for New Frameworks and Files

**What goes wrong:** The project uses a custom `generate-xcodeproj.js` Node script to generate the `.xcodeproj` file. Adding new frameworks (EventKit, AuthenticationServices for `ASWebAuthenticationSession`) and new source files requires updating this script. If the script is not updated, new files won't be compiled, new frameworks won't be linked, and the build fails with missing symbol errors.

**Prevention:**
- Every plan that adds new files must include "update generate-xcodeproj.js" as a task
- Add EventKit.framework and AuthenticationServices.framework to the script's linked frameworks list
- Follow the existing pattern: the script already handles AVFoundation, SpriteKit, CloudKit, CoreData, UserNotifications, Charts -- adding EventKit and AuthenticationServices is the same pattern
- Run `node generate-xcodeproj.js && xcodebuild build` after every file addition to verify compilation

**Phase relevance:** Every phase. This is a process concern, not a one-time fix.

**Confidence:** HIGH -- direct observation of the existing build system constraint.

---

## Cross-Feature Integration Pitfalls

These pitfalls arise from the INTERACTION between the four v3.0 pillars, not from any individual feature.

---

### Integration Pitfall A: Adaptive Difficulty + Spotify Playlist Creates a Feedback Timing Mismatch

**What goes wrong:** Adaptive difficulty adjusts estimation thresholds, which changes the player's per-task estimates, which changes the routine's total estimated time, which changes the playlist duration needed. If difficulty tightens and the player starts estimating more accurately (closer to actual), the estimated total time converges to the actual total time, and the playlist gets more accurate. But if the player is in a "learning the new difficulty" phase, her estimates may temporarily get WORSE, and the playlist diverges from actual time.

**Prevention:**
- Size playlists based on ACTUAL historical routine duration (from `InsightEngine`'s recent actuals), not on the player's estimates. This decouples playlist accuracy from estimation accuracy
- The playlist is a time CUE, not a timer. Communicate this clearly in the UX

**Phase relevance:** Design playlist sizing independently from difficulty adjustment.

**Confidence:** MEDIUM -- interaction effect that requires both features to be designed together.

---

### Integration Pitfall B: Calendar Intelligence + Parent-Configured Schedule Creates Conflicting Authority

**What goes wrong:** The parent configured routines for "Mon, Wed, Fri" in the parent setup. EventKit shows school events on "Mon, Tue, Wed, Thu, Fri." The calendar intelligence suggests "you also have school on Tuesday and Thursday -- want to add those days?" But the parent intentionally chose Mon/Wed/Fri because those are the days the player doesn't have after-school activities. The calendar system overrides the parent's intentional schedule decisions.

**Prevention:**
- Calendar intelligence should INFORM, not OVERRIDE. Show "No quest scheduled today, but you have free time between 3pm and 5pm" rather than "Adding your quest to Tuesday"
- Calendar data should NEVER modify parent-configured routines automatically. Calendar awareness is read-only, advisory, for the player
- Let calendar intelligence suggest NEW player-created quests ("You have a gap Tuesday after school -- want to create a quick quest?") rather than modifying existing parent-configured routines

**Phase relevance:** Calendar intelligence design must respect the parent/player authority boundary.

**Confidence:** HIGH -- direct implication of the app's authority model.

---

### Integration Pitfall C: UI Refresh + Spotify Branding + Game Identity Creates Visual Incoherence

**What goes wrong:** The UI refresh establishes a new visual language. Spotify has mandatory brand guidelines (green color, logo usage requirements). The game's existing identity (clock icon, tint color, quest terminology) is a third visual system. If not unified, the app looks like three different apps stitched together.

**Prevention:**
- Integrate Spotify minimally: use the Spotify green only on the "Connected to Spotify" badge in settings. Everywhere else, represent music with the app's own color scheme and generic music iconography
- Review Spotify's brand guidelines for acceptable minimal usage. The guidelines allow minimal branding when the Spotify-branded element is a secondary feature
- The game identity (quest terminology, curiosity language) should dominate. Spotify and calendar are background features that enhance the game, not competing brands

**Phase relevance:** UI refresh phase should account for Spotify and calendar visual elements.

**Confidence:** MEDIUM -- Spotify brand guidelines are documented but specific enforcement varies.

---

## ADHD-Specific Pitfalls

These pitfalls are unique to building for a player with ADHD-related time blindness and are not general software engineering concerns.

---

### ADHD Pitfall I: Too Many Settings and Options Cause Decision Paralysis

**What goes wrong:** v3.0 adds Spotify connection, calendar connection, difficulty preferences (if exposed), theme customization, and playlist preferences on top of existing notification settings and sound toggle. For a player with ADHD, a settings screen with 8+ options is overwhelming. She opens settings, sees too many choices, closes settings without changing anything.

**Prevention:**
- Most v3.0 features should have ZERO user-facing settings. Adaptive difficulty adjusts automatically. Calendar intelligence activates automatically after permission grant. Spotify creates playlists automatically after connection
- The only new settings should be: "Connect Spotify" (one toggle), "Calendar Access" (one toggle). Everything else should be automatic
- Group settings visually: "Game" (sound, notifications), "Connected" (Spotify, Calendar). Two groups, not a flat list
- Use progressive disclosure: advanced options hidden behind "More" if they exist at all

**Confidence:** HIGH -- decision paralysis in ADHD is well-documented.

---

### ADHD Pitfall II: Spotify OAuth Flow Is a Multi-Step Task That Will Be Abandoned Mid-Flow

**What goes wrong:** The OAuth flow is: tap Connect -> web view opens -> log in to Spotify -> review permissions -> tap Agree -> wait for redirect -> see success. This is 4-7 steps. For a 13-year-old with ADHD, the probability of abandoning mid-flow is high. She taps Connect, sees a web view loading, gets a notification from another app, switches away, and never completes the flow. The next time she opens TimeQuest, there's no indication that Spotify setup is incomplete.

**Prevention:**
- If `ASWebAuthenticationSession` is used, the session is cancelled automatically when the user switches away. This is actually fine -- it just means the connection didn't happen. No stale state
- Do NOT show "Connecting to Spotify..." as a persistent state. It's either connected or not. No "in progress" state that can get stuck
- After an abandoned attempt, do NOT nag. Don't show "You didn't finish connecting Spotify!" The player will try again when she's ready, or she won't. Both are acceptable outcomes
- Make the connection discoverable but not urgent. A music icon in quest settings, not a banner on the home screen

**Confidence:** HIGH -- ADHD task-abandonment in multi-step flows is well-documented.

---

### ADHD Pitfall III: Calendar-Suggested Routines Feel Like Nagging

**What goes wrong:** Calendar intelligence detects "you have a free period after school" and suggests "Time for a quest!" This is indistinguishable from a parent or teacher telling her what to do. The app has now become another authority figure managing her time -- exactly what the app was designed to NOT be.

**Prevention:**
- Calendar intelligence should be PASSIVE, not PROACTIVE. Instead of pushing "Time for a quest!", show contextual info when she ALREADY opens the app: "You have 45 minutes before practice" or "No events until dinner"
- Never suggest she SHOULD play. Never imply she's NOT playing enough. Calendar data contextualizes her choices, it does not make choices for her
- Frame calendar info as useful knowledge, not as scheduling: "Free afternoon today" not "You should do your quests"

**Confidence:** HIGH -- directly derived from the app's anti-nagging design principle.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Severity | Mitigation |
|-------------|---------------|----------|------------|
| Schema V4 migration (do first) | Corrupted v2.0 data (Pitfall 5) | CRITICAL | Lightweight migration only, test with V3 store, separate local-only config for Spotify/Calendar metadata |
| Adaptive difficulty | ADHD punishment loop (Pitfall 3) | CRITICAL | Long window, upward-only ratchet, per-task, invisible adjustments |
| Adaptive difficulty | XP economy destabilization (Pitfall 4) | CRITICAL | Decouple difficulty from XP, or use accuracy-proportional XP |
| Adaptive difficulty | Insight/trend corruption (Pitfall 12) | MODERATE | Store absolute accuracy, use difficulty-adjusted ratings only for display |
| Spotify integration | Audio session conflict (Pitfall 1) | CRITICAL | Web API only (no SDK playback), keep .ambient for game sounds |
| Spotify integration | No backend server (Pitfall 8) | CRITICAL | PKCE flow, no client secret needed |
| Spotify integration | Token management (Pitfall 2) | CRITICAL | Keychain storage, auto-refresh, graceful degradation |
| Spotify integration | Free tier playback limitation (Pitfall 11) | MODERATE | "Suggest playlist" approach instead of API-controlled playback |
| Spotify integration | Playlist duration mismatch (Pitfall 9) | MODERATE | Use actual duration history, create longer playlist, set expectations |
| Spotify integration | Multi-step OAuth abandonment (ADHD II) | MODERATE | No persistent "in progress" state, no nagging |
| Spotify integration | Login complexity (Pitfall 13) | MODERATE | Hide in settings, make interruptible, minimize Spotify branding |
| Calendar intelligence | Permission prompt risk (Pitfall 6) | CRITICAL | Optional, graceful denial, teen-friendly description, consider parent-configured alternative |
| Calendar intelligence | Main thread EventKit queries (Pitfall 10) | MODERATE | Async queries, cache results, narrow date range |
| Calendar intelligence | Calendar nagging (ADHD III) | MODERATE | Passive context, never suggest actions |
| Calendar intelligence | EventKit IDs don't sync (Pitfall 14) | LOW | Store derived schedule, not EventKit refs |
| Calendar intelligence | Conflicting parent authority (Integration B) | MODERATE | Read-only, advisory, never modify parent routines |
| UI/brand refresh | 20+ view regression risk (Pitfall 7) | MODERATE | Theme tokens, single focused phase, low-risk views first |
| UI/brand refresh | Alienating existing player (Pitfall 15) | LOW | Evolutionary not revolutionary, preserve layout hierarchy |
| UI/brand refresh | Spotify brand conflict (Integration C) | LOW | Minimal Spotify branding, game identity dominates |
| All phases | generate-xcodeproj.js updates (Pitfall 18) | LOW | Update script with every new file/framework |
| All phases | Swift 6.0 concurrency (Pitfall 17) | LOW | Async/await wrappers, actor-isolated services |
| All phases | Decision paralysis from too many settings (ADHD I) | MODERATE | Minimal settings, automatic behavior, progressive disclosure |

---

## Recommended Phase Ordering (Based on Pitfall Dependencies)

The pitfalls reveal this dependency chain:

1. **Schema V4 migration** -- Pitfall 5 must be resolved before any model changes. Define ALL v3.0 model additions in one migration.

2. **Adaptive difficulty** -- Pitfalls 3, 4, 12 are the highest-risk design challenges. This is a pure domain engine (no external dependencies, no permissions, no API keys). Build and test it in isolation with comprehensive ADHD-aware test scenarios before integrating with UI.

3. **Spotify integration** -- Pitfalls 1, 2, 8, 9, 11, 13 are numerous but follow a clear sequence: auth flow first, playlist creation second, playback integration third. Each step can be tested independently. Must decide "suggest playlist" vs "control playback" before starting.

4. **Calendar intelligence** -- Pitfalls 6, 10, 14 are straightforward if calendar is kept advisory/optional. Consider whether EventKit is worth the privacy complexity vs parent-configured schedule.

5. **UI/brand refresh** -- Pitfalls 7, 15 are lowest risk and should be last. Applied to the final feature set, including new Spotify and Calendar views.

**Rationale for this order:**
- Migration first (foundational, everything depends on stable schema)
- Adaptive difficulty second (pure domain, highest design risk, no external dependencies to debug simultaneously)
- Spotify third (external dependency but self-contained -- can be fully tested independently)
- Calendar fourth (lower value feature, simplest if parent-configured schedule is chosen over EventKit)
- UI refresh last (applies to all views including new ones from phases 2-4)

---

## The Meta-Pitfall: v3.0 Is Four Unrelated Features Sharing a Milestone

The overarching risk of v3.0 is that adaptive difficulty, Spotify integration, calendar intelligence, and UI refresh are four independent features with minimal technical dependencies between them. They share a milestone but not an architecture. The risk is scope creep: each feature alone is achievable, but four features together in one milestone can lead to:
- Parallel work on multiple fronts without finishing any of them
- Integration testing complexity (4 features x their interactions = 6 pairwise interactions to test)
- If one feature blocks (Spotify API changes, EventKit permission issues), it delays the entire milestone

**Mitigation:** Treat each feature as a self-contained phase that ships independently. The milestone is "done" when all four are done, but each phase produces a working, shippable increment. If calendar intelligence is cut, the other three features still ship. If Spotify API changes require a redesign, adaptive difficulty and UI refresh ship on schedule.

---

## Confidence Assessment

| Pitfall | Confidence | Basis |
|---------|------------|-------|
| Audio session conflict (#1) | HIGH | Fundamental iOS audio architecture |
| Spotify token management (#2) | MEDIUM | Well-documented OAuth flow; teen-specific concerns are design judgment |
| ADHD punishment loop (#3) | HIGH | ADHD executive function variability is well-documented; game design analysis |
| XP economy destabilization (#4) | HIGH | Direct math from existing XPConfiguration |
| SchemaV4 migration (#5) | HIGH | Same migration constraints as v2.0 (validated) |
| EventKit privacy (#6) | HIGH | iOS permission mechanics; privacy/consent implications |
| UI retrofit regression (#7) | HIGH | Standard refactoring risk from codebase analysis |
| Spotify no-backend (#8) | MEDIUM | PKCE flow documented; verify current Spotify API support |
| Playlist duration mismatch (#9) | HIGH | Inherent in the concept design |
| EventKit main thread (#10) | HIGH | Well-documented EventKit behavior |
| Spotify Free tier (#11) | MEDIUM | Well-known restriction; verify current tier limitations |
| Difficulty/insights interaction (#12) | HIGH | Direct code analysis of accuracyPercent storage pattern |
| Spotify login complexity (#13) | MEDIUM | ADHD UX judgment based on design principles |
| EventKit IDs don't sync (#14) | HIGH | Well-documented EventKit identifier behavior |
| UI alienation (#15) | MEDIUM | UX design judgment |
| Spotify rate limiting (#16) | MEDIUM | Exists but thresholds undocumented |
| Swift 6.0 concurrency (#17) | HIGH | Strict concurrency behavior well-documented |
| generate-xcodeproj.js (#18) | HIGH | Direct codebase observation |
| ADHD decision paralysis (ADHD I) | HIGH | Well-documented ADHD symptom |
| ADHD OAuth abandonment (ADHD II) | HIGH | Well-documented ADHD task abandonment |
| ADHD calendar nagging (ADHD III) | HIGH | Directly from app's anti-nagging design principle |
| Integration A (difficulty+playlist timing) | MEDIUM | Interaction analysis |
| Integration B (calendar+parent authority) | HIGH | Directly from app's authority model |
| Integration C (UI+Spotify branding) | MEDIUM | Brand guideline compliance |

**Overall:** The ADHD-specific pitfalls (3, ADHD I-III) and the audio session conflict (1) are the highest-impact risks because they threaten the core design principles that make TimeQuest work for its target user. The Spotify integration pitfalls (2, 8, 9, 11, 13) are numerous but well-understood and have clear prevention paths. The adaptive difficulty pitfalls (3, 4, 12) require the most careful design work. The calendar and UI pitfalls are lower risk with straightforward mitigations.

---

## Sources

- Apple Developer Documentation: AVAudioSession Programming Guide (audio session categories, interruption handling, .ambient mixing behavior)
- Apple Developer Documentation: EventKit Framework (EKEventStore, authorization, event queries, EKEvent identifiers)
- Apple Developer Documentation: ASWebAuthenticationSession (OAuth flow for iOS apps)
- Apple Developer Documentation: SwiftData schema versioning and lightweight migration constraints
- Spotify Web API Reference: Authorization Code Flow with PKCE, Playlist endpoints, Player endpoints, User profile endpoint
- Spotify iOS SDK Documentation: SPTAppRemote, authentication flow
- Spotify Developer Terms: Brand guidelines, rate limiting, Free vs Premium tier API access
- Game design research: Dynamic difficulty adjustment (DDA) patterns, engagement curves, flow theory
- ADHD research: Executive function variability, decision paralysis, task abandonment in multi-step processes, sensitivity to perceived failure
- Existing codebase analysis: SoundManager.swift, TimeEstimationScorer.swift, XPEngine.swift, XPConfiguration.swift, InsightEngine.swift, CalibrationTracker.swift, TimeQuestMigrationPlan.swift, TimeQuestSchemaV3.swift

*All sources referenced from training data (May 2025 cutoff). Web search and Context7 were unavailable for verification. Specific API details (Spotify PKCE support, EventKit iOS 17+ changes, SwiftData migration behavior) should be verified against current documentation during implementation.*
