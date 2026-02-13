# Phase 5: Self-Set Routines + Production Audio - Research

**Researched:** 2026-02-13
**Domain:** SwiftData schema migration, player-facing routine creation UX, AVAudioSession configuration, XP tuning
**Confidence:** HIGH

## Summary

Phase 5 has two independent workstreams: (A) player-created routines with schema changes and a guided creation flow, and (B) production audio polish with proper AVAudioSession configuration plus XP constant exposure. Both build on well-established codebase patterns.

The routine workstream requires a **SchemaV3** with a `createdBy` field on the Routine model, a lightweight migration from V2 to V3, a `RoutineTemplateProvider` for starter templates, a player-facing guided creation flow reusing the existing value-type editing pattern (`RoutineEditState` / `TaskEditState`), and filtering changes in the `RoutineRepository` and `RoutineListView` to separate parent vs player routines. The parent's existing `RoutineEditorView` and `RoutineEditorViewModel` provide a battle-tested pattern for the player creation flow.

The audio workstream requires replacing the 5 placeholder `.wav` files with real production-quality CC0 sound effects, configuring `AVAudioSession` with the `.ambient` category (mix with background music, respect silent switch), and extracting XP/level constants into a tunable configuration struct. The existing `SoundManager` is almost production-ready -- it just needs the audio session setup and real sound files.

**Primary recommendation:** Add `createdBy` as a `String` property with default `"parent"` to Routine in SchemaV3, use lightweight migration, build the player creation flow by adapting the existing parent editor pattern into a guided multi-step flow, and configure AVAudioSession.ambient in SoundManager.init().

## Standard Stack

### Core (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ | Schema versioning, persistence | Already used for all models via VersionedSchema pattern |
| AVFoundation | iOS 17+ | Audio playback, session config | Already used via AVAudioPlayer in SoundManager |
| SwiftUI | iOS 17+ | Player creation flow UI | All views in the app use SwiftUI |

### Supporting (No New Dependencies Needed)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVAudioSession | Built-in | Audio category configuration | Configure once at SoundManager init to set .ambient |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AVAudioPlayer (.wav) | AVAudioPlayer (.caf) | CAF is iOS-native format, slightly more efficient; but WAV works fine for <1MB total and is already the established pattern |
| Guided multi-step flow | Single Form (like parent editor) | Multi-step is more engaging for a child, aligns with "quest creation" metaphor; single form is simpler but less age-appropriate |
| String-based createdBy | Enum-based createdBy | String is safer for CloudKit + lightweight migration (stored as primitive); enum would require rawValue pattern like AccuracyRating |

**Installation:** No new dependencies. Everything uses built-in Apple frameworks already in the project.

## Architecture Patterns

### Recommended Project Structure
```
TimeQuest/
  Models/
    Schemas/
      TimeQuestSchemaV3.swift          # NEW: V3 with createdBy on Routine
    Migration/
      TimeQuestMigrationPlan.swift     # MODIFIED: add V2->V3 stage
    Routine.swift                      # MODIFIED: add createdBy convenience
  Domain/
    RoutineTemplateProvider.swift       # NEW: 3+ starter templates
    XPConfiguration.swift              # NEW: tunable XP constants
  Features/
    Player/
      Views/
        PlayerRoutineCreationView.swift  # NEW: guided creation flow (multi-step)
        PlayerTaskEditorView.swift       # NEW: simplified task editor for player
      ViewModels/
        PlayerRoutineCreationViewModel.swift  # NEW: creation + template logic
    Parent/
      Views/
        RoutineListView.swift            # MODIFIED: filter out player routines
  Repositories/
    RoutineRepository.swift              # MODIFIED: add fetchByCreator methods
  Services/
    SoundManager.swift                   # MODIFIED: add AVAudioSession config
  Resources/
    Sounds/
      estimate_lock.wav                  # REPLACED: real production audio
      reveal.wav                         # REPLACED: real production audio
      level_up.wav                       # REPLACED: real production audio
      personal_best.wav                  # REPLACED: real production audio
      session_complete.wav               # REPLACED: real production audio
```

### Pattern 1: SchemaV3 with createdBy Field
**What:** Add a `createdBy` string field to Routine in a new VersionedSchema, defaulting to `"parent"` so existing routines are correctly attributed.
**When to use:** This is the required pattern for any schema change under the existing CloudKit + lightweight migration constraint.
**Confidence:** HIGH (verified against existing V1->V2 migration pattern in codebase)

The existing V2 Routine has all properties with defaults (CloudKit constraint). Adding `createdBy: String = "parent"` follows the same pattern. Existing parent-created routines will get the default value `"parent"` during lightweight migration.

**Critical detail:** SwiftData's lightweight migration handles adding properties with defaults. The Donny Wals deep-dive confirms that adding optional properties or properties with defaults is a lightweight migration scenario. Since `createdBy` has a Swift-level default of `"parent"`, existing rows will get this default value. However, this MUST be tested with a real V2 store to verify -- never trust that Swift defaults propagate to the database layer without testing.

**Schema definition pattern:**
```swift
enum TimeQuestSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] { /* same 5 models */ }

    @Model
    final class Routine {
        var cloudID: String = UUID().uuidString
        var name: String = ""
        var displayName: String = ""
        var activeDays: [Int] = []
        var isActive: Bool = true
        var createdBy: String = "parent"    // NEW: "parent" or "player"
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        // ... relationships unchanged
    }
    // ... other models identical to V2
}
```

**Migration plan update:**
```swift
enum TimeQuestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TimeQuestSchemaV1.self, TimeQuestSchemaV2.self, TimeQuestSchemaV3.self]
    }
    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3]
    }
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV1.self,
        toVersion: TimeQuestSchemaV2.self
    )
    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: TimeQuestSchemaV2.self,
        toVersion: TimeQuestSchemaV3.self
    )
}
```

### Pattern 2: Value-Type Editing for Player Routine Creation
**What:** Reuse the existing `RoutineEditState` / `TaskEditState` structs with a player-facing ViewModel that adds template initialization and guided-step navigation.
**When to use:** The codebase already uses this pattern for parent routine editing. The player flow extends it.
**Confidence:** HIGH (pattern already proven in RoutineEditorViewModel)

The existing `RoutineEditState` struct captures all routine fields as value types, preventing SwiftData auto-save surprises. The player creation ViewModel should:
1. Accept a template (or blank) and populate `RoutineEditState`
2. Track which step the player is on (name, tasks, schedule, review)
3. Set `createdBy = "player"` when creating the Routine model
4. Apply validation guardrails (1-10 tasks, non-empty names, at least one active day)

### Pattern 3: Repository Filtering by createdBy
**What:** Add methods to `RoutineRepositoryProtocol` to fetch routines filtered by creator.
**When to use:** Parent dashboard needs only parent routines; player home needs all routines but with visual distinction.
**Confidence:** HIGH

```swift
// Added to RoutineRepositoryProtocol
func fetchParentRoutines() -> [Routine]
func fetchPlayerRoutines() -> [Routine]
```

**SwiftData predicate note:** `#Predicate { $0.createdBy == "parent" }` works because `createdBy` is a simple String -- unlike array-contains predicates which require in-memory filtering.

### Pattern 4: AVAudioSession .ambient Configuration
**What:** Set the audio session category to `.ambient` so sounds mix with background music and respect the silent switch.
**When to use:** Once, during SoundManager initialization.
**Confidence:** HIGH (verified via Apple documentation and multiple iOS audio guides)

```swift
init() {
    self.isMuted = UserDefaults.standard.bool(forKey: "soundMuted")
    configureAudioSession()
    preloadAll()
}

private func configureAudioSession() {
    do {
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        // Audio session config failed -- sounds will still play but may
        // interrupt other audio or ignore silent switch
    }
}
```

### Pattern 5: XP Configuration Struct
**What:** Extract hardcoded XP constants from `XPEngine` and `LevelCalculator` into a single tunable struct.
**When to use:** Post-playtesting adjustment without code changes throughout the codebase.
**Confidence:** HIGH (straightforward refactoring of existing constants)

```swift
struct XPConfiguration {
    // XPEngine constants
    var spotOnXP: Int = 100
    var closeXP: Int = 60
    var offXP: Int = 25
    var wayOffXP: Int = 10
    var completionBonus: Int = 20

    // LevelCalculator constants
    var levelBaseXP: Double = 100
    var levelExponent: Double = 1.5

    static let `default` = XPConfiguration()
}
```

### Anti-Patterns to Avoid
- **Sharing RoutineEditorView between parent and player:** The parent editor is a Form-based single-screen editor. The player flow needs a guided multi-step experience. Trying to share the view creates coupling and makes neither flow good. Instead, share the `RoutineEditState` value type and create a separate player creation view.
- **Using an enum for createdBy in the schema:** Storing a Swift enum directly in SwiftData requires rawValue handling. Using a plain `String` with constants (`"parent"`, `"player"`) is simpler and survives schema evolution better. The typealias extension can add a computed enum property if type safety is desired at the Swift level.
- **Filtering player routines in the view layer:** The `RoutineListView` currently uses `@Query` to fetch all routines. Filtering should happen at the repository/predicate level, not by fetching all and filtering in the view. This keeps the parent dashboard from ever seeing player routines.
- **Configuring AVAudioSession per-play:** Audio session should be configured once at startup, not before each sound play. Per-play configuration causes audible glitches and is unnecessary.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio mixing with background music | Custom audio mixing code | `AVAudioSession.Category.ambient` | Apple's built-in category handles all edge cases (AirPlay, CarPlay, interruptions) |
| Silent switch detection | Custom mute switch detection | `AVAudioSession.Category.ambient` | `.ambient` automatically respects the hardware switch |
| Sound effect format conversion | Custom audio conversion pipeline | Keep .wav format, use Audacity/ffmpeg for asset prep | AVAudioPlayer handles .wav natively; the 5 files total <1MB |
| Routine template persistence | Database-stored templates | In-memory `RoutineTemplateProvider` struct | Templates are static, version-controlled code; no need to persist |

**Key insight:** The existing `SoundManager` with `AVAudioPlayer` is the right tool. The only missing piece is the `AVAudioSession` configuration. Don't add AudioKit, AVAudioEngine, or any audio framework -- `AVAudioPlayer` is perfect for short game sound effects.

## Common Pitfalls

### Pitfall 1: SwiftData Default Values in Lightweight Migration
**What goes wrong:** Adding `var createdBy: String = "parent"` to SchemaV3 and assuming existing rows automatically get `"parent"` in the database. The Swift default value is an initializer default, not necessarily a database-level default.
**Why it happens:** Swift property defaults and database column defaults are separate concepts. SwiftData may or may not propagate the Swift default to existing rows during lightweight migration.
**How to avoid:** Test the migration with a real V2 database before shipping. Create a V2 store, add routines, then run the V3 migration and verify `createdBy` values. If the default doesn't propagate, use a custom migration stage to backfill `"parent"` for existing rows.
**Warning signs:** All existing routines show `""` (empty string) for `createdBy` after migration.

### Pitfall 2: @Query in RoutineListView Ignoring createdBy Filter
**What goes wrong:** `RoutineListView` uses `@Query(sort: \Routine.createdAt) private var routines: [Routine]` which fetches ALL routines, including player-created ones.
**Why it happens:** The parent dashboard currently has no filtering -- it displays every routine. After Phase 5, player-created routines would appear in the parent dashboard unless explicitly filtered.
**How to avoid:** Either add a `#Predicate` filter to the `@Query` macro, or replace the `@Query` with repository-based fetching that filters by `createdBy == "parent"`. The repository approach is more consistent with the rest of the codebase (PlayerHomeView already uses `SwiftDataRoutineRepository` directly).
**Warning signs:** Player sees "parent" routines in their creation list, or parent sees player routines in their dashboard.

### Pitfall 3: Player Editing/Deleting Parent Routines
**What goes wrong:** If the player's quest list doesn't distinguish between parent and player routines, the player could potentially modify or delete parent-created routines.
**Why it happens:** The existing `QuestView` and `GameSessionViewModel` don't check `createdBy` before allowing interaction.
**How to avoid:** Player should only be able to edit/delete routines where `createdBy == "player"`. Parent routines are play-only from the player's perspective. The "Create Quest" flow creates new routines; it never modifies existing parent routines.
**Warning signs:** An edit/delete button appearing on parent-created routines in the player view.

### Pitfall 4: AVAudioSession Category Reset by Other Frameworks
**What goes wrong:** Another framework (SpriteKit, push notifications) resets the audio session category, causing sounds to stop mixing with background music.
**Why it happens:** SpriteKit scenes can configure their own audio session. The app uses `SpriteView` for celebration scenes (AccuracyRevealScene, CelebrationScene).
**How to avoid:** Re-apply the `.ambient` category after presenting SpriteKit scenes, or configure the SKScene to not manage the audio session (set `scene.audioEngine` properties appropriately). Monitor for audio session interruption notifications.
**Warning signs:** Background music stops when a celebration animation plays, or sounds stop respecting the silent switch after a SpriteKit scene.

### Pitfall 5: Sound Files Not in Bundle
**What goes wrong:** Replacing placeholder .wav files with real ones, but the new files aren't included in the Xcode build. The `project.yml` includes `Resources/` as a resource path, so any files placed in `Resources/Sounds/` should be bundled automatically.
**Why it happens:** File naming mismatch (must be exactly `estimate_lock.wav`, `reveal.wav`, `level_up.wav`, `personal_best.wav`, `session_complete.wav`) or XcodeGen not re-run after adding files.
**How to avoid:** Keep exact same filenames. Run `xcodegen generate` after replacing files. Verify via `Bundle.main.url(forResource:withExtension:)` at runtime.
**Warning signs:** SoundManager silently skips sounds (it catches errors and returns early without logging).

### Pitfall 6: Validation Guardrails Missing from Player Creation
**What goes wrong:** Player creates a routine with 0 tasks, empty name, or no active days, resulting in an unplayable quest.
**Why it happens:** The parent editor has a `canSave` check but it only validates name + displayName + at least one task. The requirements specify stricter validation: 1-10 tasks, non-empty names, at least one active day.
**How to avoid:** Implement `REQ-032` validation in the player creation ViewModel. Disable the "Create" button until all validation passes. Show inline guidance (not error alerts -- this is for a child).
**Warning signs:** A quest with 0 tasks shows up in the quest list and crashes when started.

## Code Examples

Verified patterns from the existing codebase:

### Creating a Routine with createdBy (adapting existing RoutineEditorViewModel.createNew)
```swift
// Source: TimeQuest/Features/Parent/ViewModels/RoutineEditorViewModel.swift lines 130-152
// Adapted for player creation:
private func createPlayerRoutine() throws {
    let routine = Routine(
        name: editState.name.trimmingCharacters(in: .whitespaces),
        displayName: editState.displayName.trimmingCharacters(in: .whitespaces),
        activeDays: editState.activeDays,
        isActive: true
    )
    routine.createdBy = "player"  // Mark as player-created
    modelContext.insert(routine)

    for taskState in editState.tasks where !taskState.name.trimmingCharacters(in: .whitespaces).isEmpty {
        let task = RoutineTask(
            name: taskState.name.trimmingCharacters(in: .whitespaces),
            displayName: taskState.displayName.trimmingCharacters(in: .whitespaces),
            referenceDurationSeconds: nil,  // Player doesn't set reference durations
            orderIndex: taskState.orderIndex
        )
        modelContext.insert(task)
        task.routine = routine
    }

    try modelContext.save()
}
```

### RoutineTemplateProvider (Pure Domain, No Dependencies)
```swift
// Source: Project convention -- Domain/ folder holds pure logic structs
struct RoutineTemplate {
    let name: String           // Internal identifier
    let displayName: String    // What player sees as quest name
    let suggestedTasks: [String]  // Task display names
    let suggestedDays: [Int]   // Default active days
}

struct RoutineTemplateProvider {
    static let templates: [RoutineTemplate] = [
        RoutineTemplate(
            name: "homework",
            displayName: "Homework Quest",
            suggestedTasks: ["Get supplies ready", "Work on assignment", "Pack up"],
            suggestedDays: [2, 3, 4, 5, 6]  // Weekdays
        ),
        RoutineTemplate(
            name: "friends_house",
            displayName: "Friend's House Prep",
            suggestedTasks: ["Pick what to bring", "Get dressed", "Pack bag"],
            suggestedDays: Array(1...7)  // Any day
        ),
        RoutineTemplate(
            name: "activity_prep",
            displayName: "Activity Prep",
            suggestedTasks: ["Gather gear", "Get changed", "Fill water bottle"],
            suggestedDays: [2, 3, 4, 5, 6]  // Weekdays
        ),
    ]
}
```

### Fetching Routines Filtered by Creator
```swift
// Source: TimeQuest/Repositories/RoutineRepository.swift (adapted)
func fetchParentRoutines() -> [Routine] {
    let descriptor = FetchDescriptor<Routine>(
        predicate: #Predicate { $0.createdBy == "parent" },
        sortBy: [SortDescriptor(\.createdAt)]
    )
    return (try? modelContext.fetch(descriptor)) ?? []
}

func fetchActiveForToday() -> [Routine] {
    // Existing logic unchanged -- returns ALL active routines for today
    // (both parent and player created)
    let descriptor = FetchDescriptor<Routine>(
        predicate: #Predicate { $0.isActive },
        sortBy: [SortDescriptor(\.createdAt)]
    )
    let allActive = (try? modelContext.fetch(descriptor)) ?? []
    let todayWeekday = Calendar.current.component(.weekday, from: Date.now)
    return allActive.filter { $0.activeDays.contains(todayWeekday) }
}
```

### Player Quest Card with Visual Distinction
```swift
// Source: TimeQuest/Features/Player/Views/PlayerHomeView.swift questCard() (adapted)
private func questCard(_ routine: Routine) -> some View {
    Button { selectedQuest = routine } label: {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(routine.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    // Visual distinction for player-created quests
                    if routine.createdBy == "player" {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    if isCalibrating(routine) {
                        Text("Calibrating")
                            .font(.caption2)
                            // ... existing calibration badge
                    }
                }
                Text("\(routine.orderedTasks.count) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
}
```

### XP Configuration Extraction
```swift
// Source: TimeQuest/Domain/XPEngine.swift + LevelCalculator.swift (refactored)
struct XPConfiguration {
    var spotOnXP: Int = 100
    var closeXP: Int = 60
    var offXP: Int = 25
    var wayOffXP: Int = 10
    var completionBonus: Int = 20
    var levelBaseXP: Double = 100
    var levelExponent: Double = 1.5

    static let `default` = XPConfiguration()
}

struct XPEngine {
    static var configuration = XPConfiguration.default

    static func xpForEstimation(rating: AccuracyRating) -> Int {
        switch rating {
        case .spot_on:  configuration.spotOnXP
        case .close:    configuration.closeXP
        case .off:      configuration.offXP
        case .way_off:  configuration.wayOffXP
        }
    }

    static func xpForSession(estimations: [TaskEstimation]) -> Int {
        let taskXP = estimations.reduce(0) { $0 + xpForEstimation(rating: $1.rating) }
        return taskXP + configuration.completionBonus
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Unversioned SwiftData models | VersionedSchema + MigrationPlan | Since project Phase 3 | All schema changes MUST go through versioned schemas |
| No audio session config | AVAudioSession.Category.ambient | Best practice since iOS 3+ | Required for proper mixing and silent switch behavior |
| Hardcoded XP constants in function bodies | Extracted tunable configuration struct | Phase 5 (this phase) | Enables post-playtesting adjustment without code changes |
| Parent-only routine creation | Dual creator (parent + player) | Phase 5 (this phase) | Requires createdBy field and filtered queries |

**Deprecated/outdated:**
- None relevant. The existing patterns (AVAudioPlayer, SwiftData VersionedSchema, @Observable) are all current best practices for iOS 17+.

## Open Questions

1. **SwiftData default value propagation during lightweight migration**
   - What we know: Swift property defaults work for new object creation. Lightweight migration "should" apply defaults to existing rows for added properties.
   - What's unclear: Whether SwiftData actually sets existing rows to `"parent"` during V2->V3 lightweight migration, or leaves them as empty string/nil.
   - Recommendation: Build SchemaV3 with `createdBy: String = "parent"`. Test with a real V2 database. If defaults don't propagate, add a custom migration stage that backfills `"parent"` for all existing routines. Alternatively, use `createdBy: String? = nil` (optional) and treat nil as "parent" in code -- this is the safest approach for lightweight migration since nil is the natural default for a new column.

2. **Sound asset sourcing logistics**
   - What we know: CC0 sources exist (Freesound, Pixabay, SONNISS, itch.io). The 5 current placeholder files are each ~8.7KB (identical size, likely generated silence or beep).
   - What's unclear: The exact sound aesthetic the user wants (retro game, modern minimal, nature-inspired). Whether the developer will source sounds manually or wants AI to generate them.
   - Recommendation: Source from Freesound.org or Pixabay with CC0 license. Target short sounds (0.5-2 seconds each). Keep .wav format for consistency with existing SoundManager. Total budget: <1MB across all 5 files. The plan should list specific search terms for each sound type.

3. **Player routine editing after creation**
   - What we know: REQ-026 says player can customize templates (rename, add/remove/reorder tasks, change days). This implies editing exists after initial creation.
   - What's unclear: Whether the player should have a persistent edit capability for their quests, or only during creation.
   - Recommendation: Provide edit/delete capability for player-created routines from the player home screen (long-press or swipe gesture). Reuse the same creation flow for editing, initialized with the existing routine's data.

4. **SpriteKit audio session interference**
   - What we know: The app uses SpriteView for CelebrationScene and AccuracyRevealScene. SpriteKit can manage its own audio session.
   - What's unclear: Whether the current SpriteKit scenes reset the AVAudioSession category.
   - Recommendation: Test by playing background music, triggering a celebration scene, then checking if sounds still mix properly. If SpriteKit interferes, configure the SKScene to disable its audio engine management.

## Sources

### Primary (HIGH confidence)
- **Codebase inspection** -- All 55+ Swift files read and cross-referenced
  - `TimeQuest/Models/Schemas/TimeQuestSchemaV2.swift` -- Current Routine model (no createdBy field)
  - `TimeQuest/Models/Migration/TimeQuestMigrationPlan.swift` -- V1->V2 lightweight migration pattern
  - `TimeQuest/Services/SoundManager.swift` -- Current audio infrastructure (AVAudioPlayer, no AVAudioSession config)
  - `TimeQuest/Domain/XPEngine.swift` + `LevelCalculator.swift` -- Hardcoded XP constants
  - `TimeQuest/Features/Parent/ViewModels/RoutineEditorViewModel.swift` -- Value-type editing pattern (RoutineEditState)
  - `TimeQuest/Features/Player/Views/PlayerHomeView.swift` -- Quest list rendering, navigation
  - `TimeQuest/Features/Parent/Views/RoutineListView.swift` -- @Query fetching all routines (no filter)
  - `TimeQuest/Features/Parent/Views/ParentDashboardView.swift` -- Parent dashboard structure
  - `TimeQuest/Repositories/RoutineRepository.swift` -- Repository protocol + SwiftData implementation
  - `TimeQuest/project.yml` -- XcodeGen config, iOS 17.0, Swift 6.0
- [Apple AVAudioSession.Category.ambient documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient) -- .ambient mixes with background audio, respects silent switch

### Secondary (MEDIUM confidence)
- [Donny Wals: Deep Dive into SwiftData Migrations](https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/) -- Lightweight migration rules: adding optional properties or properties with defaults is automatic; default values in Swift code don't guarantee database-level backfill
- [Igor Kulman: Correctly Playing Audio in iOS](https://blog.kulman.sk/correctly-playing-audio-in-ios-apps/) -- AVAudioSession.Category.ambient recommended for non-primary sound effects
- [Hacking with Swift: Lightweight vs Complex Migrations](https://www.hackingwithswift.com/quick-start/swiftdata/lightweight-vs-complex-migrations) -- When lightweight migration works vs when custom stages are needed

### Tertiary (LOW confidence)
- [Freesound.org](https://freesound.org) -- CC0 sound effects source (not verified for specific game sounds needed)
- [Pixabay Sound Effects](https://pixabay.com/sound-effects/) -- CC0 sound effects, free download
- [SONNISS GameAudioGDC](https://sonniss.com/gameaudiogdc/) -- Royalty-free game audio bundles

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new dependencies; everything uses existing Apple frameworks and established codebase patterns
- Architecture: HIGH -- All patterns directly extend proven codebase conventions (VersionedSchema, value-type editing, repository protocol, @Observable ViewModels)
- Schema migration: HIGH for pattern, MEDIUM for default value propagation -- Lightweight migration is correct approach but default backfill behavior needs runtime verification
- Audio configuration: HIGH -- AVAudioSession.Category.ambient is well-documented and straightforward
- Pitfalls: HIGH -- Identified from direct codebase analysis and verified with official documentation
- Sound sourcing: MEDIUM -- CC0 sources identified but specific asset selection requires manual effort

**Research date:** 2026-02-13
**Valid until:** 2026-03-15 (stable domain; iOS 17+ APIs are mature)
