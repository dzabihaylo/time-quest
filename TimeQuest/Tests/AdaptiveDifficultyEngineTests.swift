import XCTest
@testable import TimeQuest

final class AdaptiveDifficultyEngineTests: XCTestCase {

    // MARK: - EMA Tests

    func testEMAFromZero() {
        let ema = AdaptiveDifficultyEngine.updatedEMA(
            currentAccuracy: 80.0,
            previousEMA: 0.0
        )
        XCTAssertEqual(ema, 24.0, accuracy: 0.01)
        // (80 * 0.3) + (0 * 0.7) = 24.0
    }

    func testEMAConverges() {
        var ema = 0.0
        for _ in 0..<20 {
            ema = AdaptiveDifficultyEngine.updatedEMA(
                currentAccuracy: 80.0,
                previousEMA: ema
            )
        }
        // After many iterations of constant input, EMA should converge to that input
        XCTAssertEqual(ema, 80.0, accuracy: 1.0)
    }

    func testEMAWeightsRecentMore() {
        // Start with EMA of 50, get a 90
        let ema = AdaptiveDifficultyEngine.updatedEMA(
            currentAccuracy: 90.0,
            previousEMA: 50.0
        )
        // (90 * 0.3) + (50 * 0.7) = 27 + 35 = 62
        XCTAssertEqual(ema, 62.0, accuracy: 0.01)
    }

    // MARK: - Difficulty Level Tests

    func testStartsAtLevel1() {
        let level = AdaptiveDifficultyEngine.difficultyLevel(
            ema: 0.0,
            currentLevel: 1,
            totalEstimations: 0
        )
        XCTAssertEqual(level, 1)
    }

    func testCannotAdvanceBelowMinimumSessions() {
        // EMA of 90 would normally be level 5, but only 3 estimations
        let level = AdaptiveDifficultyEngine.difficultyLevel(
            ema: 90.0,
            currentLevel: 1,
            totalEstimations: 3
        )
        XCTAssertEqual(level, 1)
    }

    func testAdvancesAtMinimumSessions() {
        let level = AdaptiveDifficultyEngine.difficultyLevel(
            ema: 70.0,
            currentLevel: 1,
            totalEstimations: 5
        )
        XCTAssertEqual(level, 2)  // EMA 70 >= 65 threshold
    }

    func testMonotonicRatchetNeverDecreases() {
        // Player is at level 3 but EMA drops to 50 (below level 2 threshold)
        let level = AdaptiveDifficultyEngine.difficultyLevel(
            ema: 50.0,
            currentLevel: 3,
            totalEstimations: 20
        )
        XCTAssertEqual(level, 3)  // max(3, 1) = 3, NEVER decrease
    }

    func testAdvancesToLevel5() {
        let level = AdaptiveDifficultyEngine.difficultyLevel(
            ema: 92.0,
            currentLevel: 4,
            totalEstimations: 50
        )
        XCTAssertEqual(level, 5)  // EMA 92 >= 90 threshold
    }

    func testHoldsAtCurrentLevelWhenEMAInsufficient() {
        let level = AdaptiveDifficultyEngine.difficultyLevel(
            ema: 74.0,
            currentLevel: 2,
            totalEstimations: 15
        )
        XCTAssertEqual(level, 2)  // EMA 74 < 75, stays at level 2
    }

    // MARK: - Threshold Tests

    func testLevel1Thresholds() {
        let t = AdaptiveDifficultyEngine.thresholds(forLevel: 1)
        XCTAssertEqual(t.spotOn, 0.10, accuracy: 0.001)
        XCTAssertEqual(t.close, 0.25, accuracy: 0.001)
        XCTAssertEqual(t.off, 0.50, accuracy: 0.001)
    }

    func testLevel5ThresholdsTighter() {
        let t = AdaptiveDifficultyEngine.thresholds(forLevel: 5)
        XCTAssertEqual(t.spotOn, 0.04, accuracy: 0.001)
        XCTAssertEqual(t.close, 0.10, accuracy: 0.001)
        XCTAssertEqual(t.off, 0.25, accuracy: 0.001)
    }

    func testOutOfBoundsLevelClamps() {
        // Level 0 should clamp to level 1 thresholds
        let t0 = AdaptiveDifficultyEngine.thresholds(forLevel: 0)
        let t1 = AdaptiveDifficultyEngine.thresholds(forLevel: 1)
        XCTAssertEqual(t0.spotOn, t1.spotOn)

        // Level 99 should clamp to level 5 thresholds
        let t99 = AdaptiveDifficultyEngine.thresholds(forLevel: 99)
        let t5 = AdaptiveDifficultyEngine.thresholds(forLevel: 5)
        XCTAssertEqual(t99.spotOn, t5.spotOn)
    }

    // MARK: - XP Multiplier Tests

    func testLevel1Baseline() {
        let mult = AdaptiveDifficultyEngine.xpMultiplier(forLevel: 1)
        XCTAssertEqual(mult, 1.0, accuracy: 0.001)
    }

    func testLevel5DoubleXP() {
        let mult = AdaptiveDifficultyEngine.xpMultiplier(forLevel: 5)
        XCTAssertEqual(mult, 2.0, accuracy: 0.001)
    }

    func testXPMultiplierIncreases() {
        var previous = 0.0
        for level in 1...5 {
            let mult = AdaptiveDifficultyEngine.xpMultiplier(forLevel: level)
            XCTAssertGreaterThan(mult, previous, "Level \(level) multiplier should exceed level \(level - 1)")
            previous = mult
        }
    }

    // MARK: - Full Flow Simulation

    func testEMABuildupThroughCalibrationAndAdvancement() {
        var ema = 0.0
        var level = 1
        let accuracies = [60.0, 65.0, 70.0, 72.0, 75.0, 80.0, 85.0, 82.0, 88.0, 90.0]

        for (i, accuracy) in accuracies.enumerated() {
            ema = AdaptiveDifficultyEngine.updatedEMA(
                currentAccuracy: accuracy,
                previousEMA: ema
            )
            level = AdaptiveDifficultyEngine.difficultyLevel(
                ema: ema,
                currentLevel: level,
                totalEstimations: i + 1
            )
        }

        // After 10 sessions of improving accuracy, should have advanced past level 1
        XCTAssertGreaterThan(level, 1, "Should advance past level 1 after consistent good performance")
        // Level should never exceed what EMA supports
        XCTAssertLessThanOrEqual(level, 5)
    }

    func testBadStreakDoesNotDecreaseDifficulty() {
        var ema = 75.0  // Established good EMA
        var level = 3

        // Simulate 5 bad sessions
        for _ in 0..<5 {
            ema = AdaptiveDifficultyEngine.updatedEMA(
                currentAccuracy: 30.0,
                previousEMA: ema
            )
            level = AdaptiveDifficultyEngine.difficultyLevel(
                ema: ema,
                currentLevel: level,
                totalEstimations: 30
            )
        }

        XCTAssertEqual(level, 3, "Level must NEVER decrease, even after bad streak")
        XCTAssertLessThan(ema, 75.0, "EMA should drop though")
    }
}
