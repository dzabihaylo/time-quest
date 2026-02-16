import SwiftUI
import SpriteKit

// MARK: - Design Tokens

/// Centralized design token system for TimeQuest.
/// Provides semantic colors, SF Rounded typography, spacing, shapes, and SpriteKit color helpers.
/// Injected into the SwiftUI environment via @Entry and accessible with @Environment(\.designTokens).
@Observable
final class DesignTokens: @unchecked Sendable {

    // MARK: - Colors (Surfaces)

    /// System dark/light background
    let surfacePrimary = Color(UIColor.systemBackground)
    /// Card background (elevated)
    let surfaceSecondary = Color(UIColor.secondarySystemGroupedBackground)
    /// Nested card background (card-within-card)
    let surfaceTertiary = Color(UIColor.tertiarySystemGroupedBackground)

    // MARK: - Colors (Semantic)

    /// Primary brand accent
    let accent = Color.teal
    /// Achievement/celebration accent
    let accentSecondary = Color.orange
    /// Success states
    let positive = Color.green
    /// Warning / over-estimate
    let caution = Color.orange
    /// Error states
    let negative = Color.red
    /// Discovery / way-off (non-judgmental)
    let discovery = Color.purple
    /// Under-estimate / calm
    let cool = Color.teal
    /// School day context
    let school = Color.blue

    // MARK: - Colors (Text)

    /// Primary text color
    let textPrimary = Color.primary
    /// Secondary text color
    let textSecondary = Color.secondary
    /// Tertiary text color
    let textTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Typography

    /// Returns an SF Rounded font for the given text style and weight.
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
    /// Capsule / pill shape
    let cornerRadiusFull: CGFloat = 100

    // MARK: - Shadows (light mode; dark mode uses border/glow instead)

    let shadowColor = Color.black.opacity(0.12)
    let shadowRadius: CGFloat = 8
    let shadowY: CGFloat = 4

    // MARK: - SpriteKit Color Helpers

    /// Gold/teal burst colors for level-up celebrations
    var celebrationGolds: [SKColor] {
        [
            SKColor(Color.orange),
            SKColor(Color.yellow),
            SKColor(Color.orange.opacity(0.8)),
            SKColor.white,
        ]
    }

    /// Teal/cyan burst colors for personal best celebrations
    var celebrationTeals: [SKColor] {
        [
            SKColor(Color.teal),
            SKColor(Color.cyan),
            SKColor.white,
        ]
    }

    /// Orange/red streak celebration colors
    var celebrationStreaks: [SKColor] {
        [
            SKColor(Color.orange),
            SKColor(red: 1.0, green: 0.35, blue: 0.1, alpha: 1.0),
            SKColor(Color.yellow),
        ]
    }
}

// MARK: - Environment Injection

extension EnvironmentValues {
    @Entry var designTokens: DesignTokens = DesignTokens()
}
