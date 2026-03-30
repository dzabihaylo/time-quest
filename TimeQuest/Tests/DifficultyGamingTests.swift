import XCTest
@testable import TimeQuest

final class DifficultyGamingTests: XCTestCase {

    func testSandbagCalibrationRecovery() {
        // EXPLOIT: Intentionally bomb calibration to keep difficulty low
        var ema = 0.0
        var level = 1

        // 3 terrible calibration sessions
        for (i, acc) in [10.0, 15.0, 5.0].enumerated() {
            ema = AdaptiveDifficultyEngine.updatedEMA(currentAccuracy: acc, previousEMA: ema)
            level = AdaptiveDifficultyEngine.difficultyLevel(ema: ema, currentLevel: level, totalEstimations: i + 1)
        }
        XCTAssertEqual(level, 1)
        XCTAssertLessThan(ema, 20)

        // 10 sessions at 80% — EMA should recover
        for i in 3..<13 {
            ema = AdaptiveDifficultyEngine.updatedEMA(currentAccuracy: 80.0, previousEMA: ema)
            level = AdaptiveDifficultyEngine.difficultyLevel(ema: ema, currentLevel: level, totalEstimations: i + 1)
        }
        XCTAssertGreaterThan(ema, 60, "EMA recovers from sandbagging")
        XCTAssertGreaterThan(level, 1, "Difficulty advances despite sandbagged calibration")
    }

    func testAlternatingAccuracySuppressesDifficulty() {
        // EXPLOIT: Alternate 95%/20% to keep EMA below threshold
        var ema = 0.0
        var level = 1
        for i in 0..<20 {
            let acc = i % 2 == 0 ? 95.0 : 20.0
            ema = AdaptiveDifficultyEngine.updatedEMA(currentAccuracy: acc, previousEMA: ema)
            level = AdaptiveDifficultyEngine.difficultyLevel(ema: ema, currentLevel: level, totalEstimations: i + 1)
        }
        XCTAssertLessThanOrEqual(level, 2, "Deliberate inconsistency suppresses advancement")
    }

    func testMonotonicRatchetUnderExtremeBadStreak() {
        var ema = 85.0
        var level = 4
        for _ in 0..<20 {
            ema = AdaptiveDifficultyEngine.updatedEMA(currentAccuracy: 5.0, previousEMA: ema)
            level = AdaptiveDifficultyEngine.difficultyLevel(ema: ema, currentLevel: level, totalEstimations: 100)
        }
        XCTAssertEqual(level, 4, "Monotonic ratchet holds through 20 terrible sessions")
    }

    func testLevel5IsPermanent() {
        var level = 5
        for _ in 0..<100 {
            level = AdaptiveDifficultyEngine.difficultyLevel(ema: 0.0, currentLevel: level, totalEstimations: 200)
        }
        XCTAssertEqual(level, 5, "Level 5 can never be lost")
    }

    func testLuckyEarlyStreakBlockedByMinimumSessions() {
        var ema = 0.0
        var level = 1
        for i in 0..<4 {
            ema = AdaptiveDifficultyEngine.updatedEMA(currentAccuracy: 98.0, previousEMA: ema)
            level = AdaptiveDifficultyEngine.difficultyLevel(ema: ema, currentLevel: level, totalEstimations: i + 1)
        }
        XCTAssertEqual(level, 1, "4 sessions < 5 minimum — no advancement")

        ema = AdaptiveDifficultyEngine.updatedEMA(currentAccuracy: 98.0, previousEMA: ema)
        level = AdaptiveDifficultyEngine.difficultyLevel(ema: ema, currentLevel: level, totalEstimations: 5)
        XCTAssertGreaterThan(level, 1, "5th session unlocks advancement")
    }
}
