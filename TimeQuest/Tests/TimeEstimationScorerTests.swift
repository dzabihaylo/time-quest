import XCTest
@testable import TimeQuest

final class TimeEstimationScorerTests: XCTestCase {

    // MARK: - Basic Scoring

    func testPerfectEstimation() {
        let result = TimeEstimationScorer.score(estimated: 300, actual: 300)
        XCTAssertEqual(result.rating, .spot_on)
        XCTAssertEqual(result.accuracyPercent, 100.0, accuracy: 0.1)
    }

    func testCloseEstimation() {
        let result = TimeEstimationScorer.score(estimated: 360, actual: 300)
        XCTAssertEqual(result.rating, .close)
    }

    func testOffEstimation() {
        let result = TimeEstimationScorer.score(estimated: 420, actual: 300)
        XCTAssertEqual(result.rating, .off)
    }

    func testWayOffEstimation() {
        let result = TimeEstimationScorer.score(estimated: 600, actual: 300)
        XCTAssertEqual(result.rating, .way_off)
    }

    // MARK: - Difficulty Thresholds

    func testLevel1ThresholdsAreGenerous() {
        let thresholds = DifficultyConfiguration.default.thresholds(forLevel: 1)
        let result = TimeEstimationScorer.score(estimated: 654, actual: 600, thresholds: thresholds)
        XCTAssertEqual(result.rating, .spot_on, "9% off should be spot_on at level 1")
    }

    func testLevel5ThresholdsAreTight() {
        let thresholds = DifficultyConfiguration.default.thresholds(forLevel: 5)
        let result = TimeEstimationScorer.score(estimated: 654, actual: 600, thresholds: thresholds)
        XCTAssertEqual(result.rating, .close, "9% off should only be close at level 5")
    }

    func testAccuracyPercentUnchangedByDifficulty() {
        let easy = DifficultyConfiguration.default.thresholds(forLevel: 1)
        let hard = DifficultyConfiguration.default.thresholds(forLevel: 5)
        let resultEasy = TimeEstimationScorer.score(estimated: 330, actual: 300, thresholds: easy)
        let resultHard = TimeEstimationScorer.score(estimated: 330, actual: 300, thresholds: hard)
        XCTAssertEqual(resultEasy.accuracyPercent, resultHard.accuracyPercent, accuracy: 0.001,
                       "DIFF-05: accuracyPercent must be difficulty-independent")
    }

    // MARK: - Short Task Exploits

    func testShortTaskScoringUsesFixedWindow() {
        let result = TimeEstimationScorer.score(estimated: 10, actual: 10)
        XCTAssertEqual(result.accuracyPercent, 100.0, accuracy: 0.1)
    }

    func testMinimumAbsoluteThreshold() {
        let result = TimeEstimationScorer.score(estimated: 70, actual: 60)
        XCTAssertEqual(result.rating, .spot_on, "10s off within 15s floor = spot_on")
    }

    // MARK: - Clock Manipulation

    func testInstantCompletion() {
        let result = TimeEstimationScorer.score(estimated: 300, actual: 0.5)
        XCTAssertEqual(result.rating, .way_off)
        XCTAssertLessThan(result.accuracyPercent, 10)
    }

    func testZeroActualTime() {
        let result = TimeEstimationScorer.score(estimated: 300, actual: 0.1)
        XCTAssertGreaterThanOrEqual(result.accuracyPercent, 0, "Should not go negative")
    }

    func testClockForwardPerfectMatchIsUndetectable() {
        // DOCUMENTED: Clock manipulation that produces matching times is invisible at scoring layer
        let result = TimeEstimationScorer.score(estimated: 300, actual: 300)
        XCTAssertEqual(result.rating, .spot_on)
    }
}
