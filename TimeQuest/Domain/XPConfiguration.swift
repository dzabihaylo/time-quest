import Foundation

/// Centralizes all tunable XP and level-curve constants.
/// Change `XPEngine.configuration` once at app launch to adjust
/// gameplay without touching XPEngine or LevelCalculator code.
struct XPConfiguration: Sendable {
    // MARK: - XP per estimation accuracy

    /// XP awarded for a spot-on estimation (within 10% / 15s).
    var spotOnXP: Int = 100

    /// XP awarded for a close estimation (within 25%).
    var closeXP: Int = 60

    /// XP awarded for an off estimation (within 50%).
    var offXP: Int = 25

    /// XP awarded for a way-off estimation (beyond 50%).
    var wayOffXP: Int = 10

    // MARK: - Session bonus

    /// Flat XP bonus for completing an entire session.
    var completionBonus: Int = 20

    // MARK: - Level curve

    /// Base XP for the level curve: xpRequired = baseXP * level^exponent.
    var levelBaseXP: Double = 100

    /// Exponent for the level curve: higher = steeper progression.
    var levelExponent: Double = 1.5

    /// Shared default configuration used throughout the app.
    static let `default` = XPConfiguration()
}
