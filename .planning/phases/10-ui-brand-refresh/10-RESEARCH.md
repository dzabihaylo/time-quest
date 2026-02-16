# Phase 10: UI/Brand Refresh - Research

**Researched:** 2026-02-16
**Domain:** SwiftUI design system, dark-mode-first theming, semantic tokens, SF Rounded typography, card-based layouts, celebration animations
**Confidence:** HIGH

## Summary

Phase 10 is a visual consistency pass across the entire app. The codebase currently has ~26 Swift files containing 145 `.font()` calls, ~27 `Color(.systemGray6)` hardcoded backgrounds, ~21 `RoundedRectangle(cornerRadius:)` calls with inconsistent radii (10, 12, 14, 16), and ~18 direct color references (`.teal`, `.orange`, `.purple`) scattered inline. There is no design system, no theme object, and no centralized token definitions. Every style value is hardcoded at the call site.

The architecture for the refresh is straightforward: define a `DesignTokens` struct containing semantic color, typography, spacing, and shape tokens; inject it into the SwiftUI environment using `@Entry`; create reusable `ViewModifier`s that read from those tokens; then migrate all 26+ view files to use the modifiers and tokens instead of hardcoded values. The app currently uses SpriteKit for celebration particles (via `CelebrationScene` and `AccuracyRevealScene`), which will need their hardcoded `SKColor` values updated to derive from the design token palette.

The project targets iOS 17+ with Xcode 16.2 and Swift 6.0, which means full access to the `@Entry` macro for environment values, `PhaseAnimator` and `KeyframeAnimator` for animations, SwiftUI `Material` types, and `Font.Design.rounded`. No third-party dependencies are needed -- this is a pure SwiftUI + SpriteKit refactor.

**Primary recommendation:** Build a single-file `DesignTokens` struct injected via `@Entry` into the environment, create a library of `ViewModifier`s for card, chip, and button styles, set `.preferredColorScheme(.dark)` at the root, then migrate views file-by-file starting with shared components and working outward to feature screens.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI framework | Already in use; provides `@Entry`, `Material`, `Font.Design.rounded`, `PhaseAnimator` |
| SpriteKit | iOS 17+ | Particle celebrations | Already in use for `CelebrationScene` and `AccuracyRevealScene` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SF Symbols 5 | Built-in | Icon system | Already used throughout; ensure all icons use `.rounded` weight variants where available |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom `@Entry` tokens | SwiftThemeKit (3rd party) | Unnecessary dependency for a single-theme app; `@Entry` is simpler |
| SpriteKit particles | Pure SwiftUI `Canvas` + `TimelineView` | Would need full rewrite; SpriteKit already works, just update colors |
| Asset catalog colors | Code-defined Color values | Code is easier to audit for hardcoded values and more portable |

**No additional dependencies needed.** This phase is a refactor of existing code using existing frameworks.

## Architecture Patterns

### Recommended Project Structure
```
TimeQuest/
├── App/
│   ├── DesignSystem/
│   │   ├── DesignTokens.swift          # All semantic tokens (colors, typography, spacing, shapes)
│   │   ├── DesignTokens+Colors.swift   # Color palette: dark-first with light fallbacks
│   │   ├── DesignTokens+Typography.swift # SF Rounded text styles
│   │   └── ViewModifiers/
│   │       ├── CardModifier.swift       # .tqCard() — standard card background
│   │       ├── ChipModifier.swift       # .tqChip() — capsule badges/tags
│   │       ├── PrimaryButtonModifier.swift # .tqPrimaryButton() — main CTAs
│   │       └── SectionHeaderModifier.swift # .tqSectionHeader() — list section titles
│   ├── TimeQuestApp.swift              # Add .preferredColorScheme(.dark) + inject tokens
│   └── ...existing files
├── Features/
│   └── ...all views updated to use tokens
└── Game/
    └── ...celebration scenes updated to use token-derived colors
```

### Pattern 1: DesignTokens via @Entry
**What:** A single `@Observable` struct containing all design tokens, injected into the environment using the `@Entry` macro.
**When to use:** Always -- this is the single source of truth for all visual values.
**Example:**
```swift
// Source: Apple @Entry macro documentation + SwiftUI environment pattern
import SwiftUI

@Observable
final class DesignTokens {
    // MARK: - Colors (dark-first)

    // Surfaces
    let surfacePrimary = Color("SurfacePrimary")     // Deep dark background
    let surfaceSecondary = Color("SurfaceSecondary")  // Elevated card background
    let surfaceTertiary = Color("SurfaceTertiary")    // Nested card / input background

    // Semantic
    let accent = Color.teal                            // Primary brand accent
    let accentSecondary = Color.orange                 // Achievement / celebration
    let positive = Color.green                         // Success states
    let caution = Color.orange                         // Warning / over-estimate
    let discovery = Color.purple                       // Discovery / way-off (non-judgmental)
    let cool = Color.teal                              // Under-estimate / calm

    // Text
    let textPrimary = Color.primary
    let textSecondary = Color.secondary
    let textTertiary = Color(.tertiaryLabel)

    // MARK: - Typography

    func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    // MARK: - Spacing

    let spacingXS: CGFloat = 4
    let spacingSM: CGFloat = 8
    let spacingMD: CGFloat = 12
    let spacingLG: CGFloat = 16
    let spacingXL: CGFloat = 24
    let spacingXXL: CGFloat = 32

    // MARK: - Shapes

    let cornerRadiusSM: CGFloat = 8
    let cornerRadiusMD: CGFloat = 12
    let cornerRadiusLG: CGFloat = 16
    let cornerRadiusXL: CGFloat = 20
    let cornerRadiusFull: CGFloat = 100  // Capsule / pill

    // MARK: - Shadows (for light mode; dark mode uses border/glow instead)

    let shadowColor = Color.black.opacity(0.12)
    let shadowRadius: CGFloat = 8
    let shadowY: CGFloat = 4
}

// @Entry macro — available in Xcode 16+, backward compatible to iOS 13
extension EnvironmentValues {
    @Entry var designTokens: DesignTokens = DesignTokens()
}
```

### Pattern 2: Reusable Card ViewModifier
**What:** A `ViewModifier` that applies the standard card style (background, corner radius, shadow/border) reading from environment tokens.
**When to use:** Every card-like container across all screens.
**Example:**
```swift
// Card style modifier using design tokens from environment
struct TQCardModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens
    @Environment(\.colorScheme) private var colorScheme

    var elevation: CardElevation = .standard

    enum CardElevation {
        case standard   // surfaceSecondary background
        case nested     // surfaceTertiary background (card inside card)
    }

    func body(content: Content) -> some View {
        content
            .padding(tokens.spacingLG)
            .background(
                elevation == .standard ? tokens.surfaceSecondary : tokens.surfaceTertiary
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadiusMD))
            .overlay(
                // Subtle border for dark mode elevation
                RoundedRectangle(cornerRadius: tokens.cornerRadiusMD)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.06 : 0), lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : tokens.shadowColor,
                radius: tokens.shadowRadius,
                y: tokens.shadowY
            )
    }
}

extension View {
    func tqCard(elevation: TQCardModifier.CardElevation = .standard) -> some View {
        modifier(TQCardModifier(elevation: elevation))
    }
}
```

### Pattern 3: Global SF Rounded Typography
**What:** Apply `.rounded` font design to all text by providing typed font helpers via the design tokens.
**When to use:** Every `.font()` call should go through tokens.
**Example:**
```swift
// Usage in views — replaces all .font(.headline), .font(.title), etc.
@Environment(\.designTokens) private var tokens

Text("TimeQuest")
    .font(tokens.font(.largeTitle, weight: .bold))

Text("No quests today")
    .font(tokens.font(.title3))
    .foregroundStyle(tokens.textSecondary)
```

### Pattern 4: Dark-Mode-First Color Definitions
**What:** Define colors in Asset Catalog with dark appearance as the primary design, light as fallback.
**When to use:** All semantic surface colors.
**Example:**
```
Assets.xcassets/
├── Colors/
│   ├── SurfacePrimary.colorset/     # Dark: #0D0D0F  Light: #F2F2F7
│   ├── SurfaceSecondary.colorset/   # Dark: #1C1C1E  Light: #FFFFFF
│   └── SurfaceTertiary.colorset/    # Dark: #2C2C2E  Light: #F2F2F7
```
In the Asset Catalog editor, design the "Any Appearance" and "Dark" variants. The dark variant is your primary design target; the light variant is the fallback.

### Anti-Patterns to Avoid
- **Hardcoded Color(.systemGray6) everywhere:** This is the current state. Replace all 27 instances with `tokens.surfaceSecondary` or `tokens.surfaceTertiary`.
- **Inconsistent corner radii (10, 12, 14, 16):** Currently scattered. Use ONLY `tokens.cornerRadiusMD` (12) for standard cards and `tokens.cornerRadiusLG` (16) for prominent cards.
- **Direct color names (.teal, .orange) in view code:** All 18 instances must be replaced with semantic token references like `tokens.accent`, `tokens.accentSecondary`.
- **Mixing .font(.headline) and .font(.system(.headline, design: .rounded)):** All typography must go through `tokens.font()` to guarantee SF Rounded everywhere.
- **Color-based elevation in dark mode:** Drop shadows are invisible against dark backgrounds. Use subtle borders or material overlays instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dark/light color switching | Custom colorScheme branching in every view | Asset Catalog color sets with Any/Dark variants | SwiftUI resolves automatically; zero runtime cost |
| Frosted glass effects | Custom blur + overlay composites | SwiftUI `Material` (.ultraThinMaterial, .thinMaterial) | Apple handles vibrancy, accessibility, performance |
| Spring animations | Manual CADisplayLink timing | `.spring()`, `.bouncy`, `.snappy` animation presets | iOS 17 spring APIs handle duration/bounce natively |
| Confetti/particle effects | Pure SwiftUI Canvas particle system | SpriteKit scenes (already exist) | Already working; just update colors from tokens |
| Dynamic Type scaling | Manual font size calculations | `Font.system(.textStyle, design: .rounded)` | Automatically scales with user accessibility settings |

**Key insight:** SwiftUI's built-in `Material`, `Font.Design.rounded`, asset catalog color sets, and iOS 17 animation APIs handle 100% of what this phase needs. No custom rendering, no third-party packages.

## Common Pitfalls

### Pitfall 1: Migrating Colors Without Auditing Semantic Meaning
**What goes wrong:** Replacing `Color(.systemGray6)` with `tokens.surfaceSecondary` everywhere, but some instances are actually nested backgrounds (card-within-card) that should be `surfaceTertiary`.
**Why it happens:** The current codebase uses `Color(.systemGray6)` for ALL card backgrounds regardless of nesting level.
**How to avoid:** Before migrating each view, identify the card nesting depth. Top-level cards use `surfaceSecondary`; nested elements (e.g., stat cards inside session summary) use `surfaceTertiary`.
**Warning signs:** Cards inside cards that look like a single flat surface with no visual separation.

### Pitfall 2: Shadows Invisible in Dark Mode
**What goes wrong:** Adding shadows to cards that look great in light mode but completely disappear in dark mode, making cards look flat and undifferentiated.
**Why it happens:** Black shadows against dark backgrounds have no contrast.
**How to avoid:** In dark mode, use subtle white/light borders (1px, 6% opacity) or `.ultraThinMaterial` backgrounds instead of shadows. The card modifier should be color-scheme-aware.
**Warning signs:** Cards that blend into the dark background with no visual boundary.

### Pitfall 3: SF Rounded Not Applied Everywhere
**What goes wrong:** Some text still uses the default SF Pro because `.font()` was not updated, or because system components (NavigationTitle, alerts, pickers) use their own fonts.
**Why it happens:** SwiftUI navigation titles and system controls have their own font handling.
**How to avoid:** For `NavigationTitle`, use `.navigationBarTitleDisplayMode(.large)` which uses the system large title font. Apply `.font(tokens.font(...))` to ALL Text views. System pickers and alerts cannot be restyled -- accept this limitation.
**Warning signs:** Visual inconsistency between body text (rounded) and nav titles (not rounded).

### Pitfall 4: Breaking Existing Animations During Migration
**What goes wrong:** Changing view structure during the visual refresh breaks existing animation triggers (`.transition`, `.withAnimation`, `.sensoryFeedback`).
**Why it happens:** SwiftUI animations depend on view identity. If you wrap views in new containers or change their conditional rendering, animations may stop working.
**How to avoid:** Migrate styling (colors, fonts, spacing) FIRST, without changing view structure. Only restructure layouts after the token migration is stable.
**Warning signs:** Reveal animations that used to animate now just pop in/out.

### Pitfall 5: SpriteKit Color Mismatch
**What goes wrong:** CelebrationScene and AccuracyRevealScene still use hardcoded SKColor values that don't match the refreshed color palette.
**Why it happens:** SpriteKit scenes use `SKColor` (UIColor), not SwiftUI `Color`. They live in a separate layer and are easy to forget.
**How to avoid:** Create a `DesignTokens.spriteKitColors` helper that converts the semantic palette to `SKColor` values. Update both scene files.
**Warning signs:** Gold/teal particle bursts that look out of place against the new dark background.

### Pitfall 6: Forgetting Light Mode Fallback
**What goes wrong:** App looks great in dark mode but terrible in light mode because colors were only tested in dark.
**Why it happens:** When designing dark-first, it's natural to forget the light variant.
**How to avoid:** Define BOTH appearances in every Asset Catalog color set. Test in both modes after each migration batch. Use `@Environment(\.colorScheme)` only for structural differences (shadow vs border), not for color values.
**Warning signs:** White text on white background, or invisible borders in light mode.

## Code Examples

Verified patterns from official sources:

### Injecting Design Tokens at App Root
```swift
// Source: Apple @Entry macro docs (Xcode 16+, iOS 13+)
@main
struct TimeQuestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)  // Dark-first default
                .environment(\.designTokens, DesignTokens())
        }
        .modelContainer(container)
    }
}
```

### Card Background Migration (Before/After)
```swift
// BEFORE (current — hardcoded):
.padding(16)
.background(Color(.systemGray6))
.clipShape(RoundedRectangle(cornerRadius: 12))

// AFTER (with design system):
.tqCard()

// Or for nested cards:
.tqCard(elevation: .nested)
```

### Typography Migration (Before/After)
```swift
// BEFORE (current — default SF Pro):
.font(.headline)
.font(.title3)
.font(.system(.title, design: .rounded))  // Only some views use .rounded

// AFTER (consistent SF Rounded):
.font(tokens.font(.headline, weight: .semibold))
.font(tokens.font(.title3))
.font(tokens.font(.title, weight: .bold))
```

### Semantic Color Migration (Before/After)
```swift
// BEFORE (current — hardcoded color names):
.foregroundStyle(.teal)
.foregroundStyle(.orange)
.foregroundStyle(Color.orange.opacity(0.8))

// AFTER (semantic tokens):
.foregroundStyle(tokens.accent)
.foregroundStyle(tokens.accentSecondary)
.foregroundStyle(tokens.caution.opacity(0.8))
```

### Chip/Badge Style Modifier
```swift
struct TQChipModifier: ViewModifier {
    @Environment(\.designTokens) private var tokens
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(.caption, design: .rounded, weight: .medium))
            .padding(.horizontal, tokens.spacingMD)
            .padding(.vertical, tokens.spacingSM - 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

extension View {
    func tqChip(color: Color) -> some View {
        modifier(TQChipModifier(color: color))
    }
}

// Usage:
Text("Calibrating").tqChip(color: tokens.caution)
Text("School day").tqChip(color: tokens.cool)
```

### SpriteKit Color Derivation
```swift
// Helper to keep SpriteKit celebrations in sync with design tokens
extension DesignTokens {
    var celebrationGolds: [SKColor] {
        [
            SKColor(Color.orange),
            SKColor(Color.yellow),
            SKColor(Color.orange.opacity(0.8)),
            SKColor.white,
        ]
    }

    var celebrationTeals: [SKColor] {
        [
            SKColor(Color.teal),
            SKColor(Color.cyan),
            SKColor.white,
        ]
    }
}
```

### Material Background for Overlays
```swift
// For floating overlays like NowPlayingIndicator (already using this pattern)
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: tokens.cornerRadiusSM))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual EnvironmentKey boilerplate | `@Entry` macro | Xcode 16 (2024) | 3 lines instead of 15 for custom env values |
| `.easeInOut` default animations | `.spring()` default (iOS 17+) | iOS 17 (2023) | Spring is now the default; feels more natural |
| Custom blur views | SwiftUI `Material` types | iOS 15 (2021) | Native frosted glass; already used by NowPlayingIndicator |
| Manual color scheme branching | Asset Catalog with Any/Dark | iOS 13+ | SwiftUI resolves automatically based on appearance |
| `withAnimation { }` for multi-step | `PhaseAnimator` / `KeyframeAnimator` | iOS 17 (2023) | Declarative multi-step animations without dispatch queues |

**Deprecated/outdated:**
- `UIColor.systemGray6` wrapped in `Color()`: Still works but should be replaced with named asset catalog colors for semantic meaning.
- Manual `DispatchQueue.main.asyncAfter` for staggered animations: Replace with `PhaseAnimator` where appropriate (currently used in AccuracyRevealView.swift and PINEntryView.swift).

## Codebase Audit Summary

### Files Requiring Migration (26 files)

**Player Views (13 files):**
| File | Font calls | Hardcoded colors | Card backgrounds | Priority |
|------|-----------|------------------|------------------|----------|
| PlayerHomeView.swift | 16 | 5 | 2 | HIGH |
| SessionSummaryView.swift | 18 | 7 | 4 | HIGH |
| AccuracyRevealView.swift | 10 | 3 | 1 | HIGH |
| PlayerRoutineCreationView.swift | 26 | 6 | 5 | HIGH |
| EstimationInputView.swift | 8 | 2 | 2 | MEDIUM |
| QuestView.swift | 1 | 0 | 0 | LOW (wrapper) |
| TaskActiveView.swift | 3 | 0 | 0 | MEDIUM |
| OnboardingView.swift | 4 | 0 | 0 | MEDIUM |
| PlayerStatsView.swift | 10 | 4 | 4 | HIGH |
| WeeklyReflectionCardView.swift | 7 | 2 | 1 | MEDIUM |
| MyPatternsView.swift | 4 | 0 | 0 | LOW |
| NotificationSettingsView.swift | 4 | 0 | 0 | LOW |
| AccuracyTrendChartView.swift | 1 | 2 | 0 | LOW |

**Shared Components (7 files):**
| File | Font calls | Hardcoded colors | Priority |
|------|-----------|------------------|----------|
| InsightCardView.swift | 4 | 2 | MEDIUM |
| AccuracyMeter.swift | 2 | 3 | HIGH (custom drawing) |
| XPBarView.swift | 1 | 2 | MEDIUM |
| LevelBadgeView.swift | 1 | 1 | LOW |
| StreakBadgeView.swift | 1 | 1 | LOW |
| NowPlayingIndicator.swift | 3 | 0 | LOW (already uses Material) |
| PINEntryView.swift | 4 | 1 | MEDIUM |

**Parent Views (6 files):**
| File | Font calls | Hardcoded colors | Priority |
|------|-----------|------------------|----------|
| ParentDashboardView.swift | 0 | 0 | LOW (navigation shell) |
| RoutineEditorView.swift | 5 | 0 | MEDIUM (Form-based) |
| RoutineListView.swift | 4 | 0 | LOW |
| SchedulePickerView.swift | 2 | 1 | LOW |
| CalendarSettingsView.swift | 1 | 1 | LOW |
| SpotifySettingsView.swift | 1 | 1 | LOW |
| PlaylistPickerView.swift | 4 | 1 | LOW |
| TaskEditorView.swift | unknown | unknown | LOW |

**Game Scenes (2 files):**
| File | Hardcoded SKColors | Priority |
|------|-------------------|----------|
| CelebrationScene.swift | 10+ SKColor literals | MEDIUM |
| AccuracyRevealScene.swift | 4 SKColor literals | MEDIUM |

### Current Color Palette (Implicit)
The app currently uses these colors without formal definition:
- **Teal:** Primary accent, XP bar, level badge, accuracy "close" rating, personal best celebration
- **Orange:** Achievement, "over" estimate, streak flame, calibrating badge, star badge
- **Purple:** Discovery / way-off rating, custom quest icon
- **Green:** Balanced/improving indicator, success states (Spotify/Calendar connected)
- **Blue:** School day context chip
- **Red:** Error text (PIN entry)
- **systemGray3-6:** Card backgrounds, inactive states, meter tracks

## Open Questions

1. **Exact dark-mode surface colors**
   - What we know: Apple HIG recommends system backgrounds (#000000, #1C1C1E, #2C2C2E). The current app uses Color(.systemGray6) which is #1C1C1E in dark mode.
   - What's unclear: Whether to use pure black (#000000) for OLED screens or slightly elevated dark gray for the base surface.
   - Recommendation: Use system background colors (`.background` level) for the base, and `.secondarySystemGroupedBackground` equivalent for cards. Define in asset catalog so it can be tweaked without code changes.

2. **Parent dashboard theming scope**
   - What we know: Requirements say "all player-facing screens." The parent dashboard (RoutineEditorView, etc.) uses Form-based layouts.
   - What's unclear: Whether parent screens should get the full card-based refresh or just token adoption.
   - Recommendation: Apply design tokens (colors, typography) to parent screens for consistency, but keep Form-based layouts as-is since they're admin tools, not player-facing. This reduces scope significantly.

3. **Celebration animation upgrade scope**
   - What we know: UI-06 requires "updated celebration and accuracy reveal animations using the new design language."
   - What's unclear: Whether this means just updating colors in existing SpriteKit scenes or rebuilding with SwiftUI PhaseAnimator/KeyframeAnimator.
   - Recommendation: Update colors to use token palette in existing SpriteKit scenes. Only rebuild with SwiftUI animations if the current ones look out of place after the color update. Keep scope tight.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `Font.Design.rounded` -- SF Rounded available via `.system(.textStyle, design: .rounded)`
- Apple Developer Documentation: `Material` -- 5 material types available iOS 15+
- Apple Developer Documentation: `@Entry` macro -- Xcode 16+, backward compatible to iOS 13
- Apple Developer Documentation: `PhaseAnimator` / `KeyframeAnimator` -- iOS 17+
- Codebase audit: Direct inspection of all 26 view files and 2 SpriteKit scene files

### Secondary (MEDIUM confidence)
- [SwiftUI Design System Semantic Colors](https://www.magnuskahr.dk/posts/2025/06/swiftui-design-system-considerations-semantic-colors/) -- Macro-based semantic color approach, pitfalls of Color extensions
- [SwiftLee: @Entry Macro](https://www.avanderlee.com/swiftui/entry-macro-custom-environment-values/) -- Full @Entry implementation pattern verified
- [Dark Mode Best Practices](https://createwithplay.com/blog/dark-mode) -- Dark-first design guidance
- [SwiftUI Custom Environment Values](https://useyourloaf.com/blog/swiftui-custom-environment-values/) -- EnvironmentKey pattern reference

### Tertiary (LOW confidence)
- [Dark mode UI best practices for 2025](https://www.graphiceagle.com/dark-mode-ui/) -- General dark mode guidance; not iOS-specific
- WebSearch aggregate: 70% of iOS users enable dark mode at least some of the time (unverified statistic)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Pure SwiftUI + SpriteKit, already in use, no new dependencies
- Architecture: HIGH -- @Entry + ViewModifier pattern is well-documented and verified across multiple authoritative sources
- Pitfalls: HIGH -- Derived from direct codebase audit showing exact hardcoded values and inconsistencies
- Migration scope: HIGH -- Every file audited with exact counts of items needing change

**Research date:** 2026-02-16
**Valid until:** 2026-04-16 (stable domain; SwiftUI design patterns move slowly)
