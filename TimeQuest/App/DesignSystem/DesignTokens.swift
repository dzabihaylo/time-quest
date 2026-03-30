import SwiftUI
import SpriteKit

// MARK: - Design Tokens

/// Centralized design token system for TimeQuest.
/// Roblox-inspired: deep dark surfaces, vibrant saturated accents, chunky rounded type,
/// gradient buttons with a raised 3D feel. Designed for a 13-year-old in 2026.
/// Injected via @Entry and accessible with @Environment(\.designTokens).
@Observable
final class DesignTokens: @unchecked Sendable {

    // MARK: - Colors (Surfaces)
    // Deep, rich darks — not system gray, more like Roblox's charcoal panels

    /// App background — near-black with a slight blue tint
    let surfacePrimary = Color(red: 0.07, green: 0.07, blue: 0.11)
    /// Card background — raised panel
    let surfaceSecondary = Color(red: 0.11, green: 0.11, blue: 0.16)
    /// Nested card — card-within-card
    let surfaceTertiary = Color(red: 0.15, green: 0.15, blue: 0.21)

    // MARK: - Colors (Semantic)
    // Roblox-bright, saturated, game-UI vibrant

    /// Primary accent — Roblox green (the "Play" button green)
    let accent = Color(red: 0.0, green: 0.75, blue: 0.35)
    /// Achievement/celebration — bright gold
    let accentSecondary = Color(red: 1.0, green: 0.78, blue: 0.0)
    /// Success / XP gain
    let positive = Color(red: 0.0, green: 0.85, blue: 0.4)
    /// Warning / over-estimate
    let caution = Color(red: 1.0, green: 0.6, blue: 0.0)
    /// Error / destructive
    let negative = Color(red: 1.0, green: 0.3, blue: 0.3)
    /// Discovery / way-off (non-judgmental) — vibrant purple
    let discovery = Color(red: 0.6, green: 0.3, blue: 1.0)
    /// Under-estimate / cool — bright cyan
    let cool = Color(red: 0.0, green: 0.8, blue: 0.9)
    /// School day context — Roblox blue
    let school = Color(red: 0.2, green: 0.5, blue: 1.0)

    // MARK: - Gradients
    // Roblox uses bold gradients on CTAs and headers

    /// Primary button gradient — the iconic green
    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.0, green: 0.85, blue: 0.4),
                Color(red: 0.0, green: 0.65, blue: 0.3)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// XP / level-up gradient — gold to orange
    var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.85, blue: 0.2),
                Color(red: 1.0, green: 0.6, blue: 0.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Streak flame gradient
    var streakGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.5, blue: 0.0),
                Color(red: 1.0, green: 0.2, blue: 0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Cool blue gradient for info/stats
    var coolGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.6, blue: 1.0),
                Color(red: 0.1, green: 0.4, blue: 0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Colors (Text)

    /// Primary text — bright white
    let textPrimary = Color.white
    /// Secondary text — soft light gray
    let textSecondary = Color(white: 0.6)
    /// Tertiary text — dim
    let textTertiary = Color(white: 0.38)

    // MARK: - Typography
    // Chunky, bold, rounded — Roblox uses Gotham/Builder but SF Rounded is the iOS equivalent

    /// Returns an SF Rounded font. Default weight is .semibold (bolder than standard apps).
    func font(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, weight: weight, design: .rounded)
    }

    // MARK: - Spacing

    let spacingXS: CGFloat = 4
    let spacingSM: CGFloat = 8
    let spacingMD: CGFloat = 12
    let spacingLG: CGFloat = 16
    let spacingXL: CGFloat = 24
    let spacingXXL: CGFloat = 32

    // MARK: - Shapes
    // Roblox uses very rounded corners — almost pill-shaped on small elements

    let cornerRadiusSM: CGFloat = 10
    let cornerRadiusMD: CGFloat = 14
    let cornerRadiusLG: CGFloat = 18
    let cornerRadiusXL: CGFloat = 24
    /// Capsule / pill shape
    let cornerRadiusFull: CGFloat = 100

    // MARK: - Shadows & Depth
    // Roblox buttons have a raised 3D feel with bottom shadows

    let shadowColor = Color.black.opacity(0.4)
    let shadowRadius: CGFloat = 0
    let shadowY: CGFloat = 4

    /// Bottom edge color for 3D raised button effect
    let buttonShadowColor = Color.black.opacity(0.3)
    let buttonShadowHeight: CGFloat = 4

    // MARK: - Border Glow
    // Subtle bright border on cards for that game-UI panel feel

    let cardBorderColor = Color.white.opacity(0.08)
    let cardBorderWidth: CGFloat = 1

    // MARK: - SpriteKit Color Helpers

    var celebrationGolds: [SKColor] {
        [
            SKColor(Color(red: 1.0, green: 0.85, blue: 0.2)),
            SKColor(Color(red: 1.0, green: 0.6, blue: 0.0)),
            SKColor(Color(red: 1.0, green: 0.95, blue: 0.5)),
            SKColor.white,
        ]
    }

    var celebrationTeals: [SKColor] {
        [
            SKColor(Color(red: 0.0, green: 0.85, blue: 0.4)),
            SKColor(Color(red: 0.0, green: 0.8, blue: 0.9)),
            SKColor.white,
        ]
    }

    var celebrationStreaks: [SKColor] {
        [
            SKColor(Color(red: 1.0, green: 0.5, blue: 0.0)),
            SKColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 1.0),
            SKColor(Color(red: 1.0, green: 0.85, blue: 0.2)),
        ]
    }
}

// MARK: - Environment Injection

extension EnvironmentValues {
    @Entry var designTokens: DesignTokens = DesignTokens()
}
