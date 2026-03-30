import XCTest
@testable import TimeQuest

final class XPEngineTests: XCTestCase {

    func testSpotOnBaseXP() {
        let xp = XPEngine.xpForEstimation(rating: .spot_on)
        XCTAssertEqual(xp, 100)
    }

    func testWayOffBaseXP() {
        let xp = XPEngine.xpForEstimation(rating: .way_off)
        XCTAssertEqual(xp, 10)
    }

    func testLevel1NoMultiplier() {
        let xp = XPEngine.xpForEstimation(rating: .spot_on, difficultyLevel: 1)
        XCTAssertEqual(xp, 100)
    }

    func testLevel5DoubleXP() {
        let xp = XPEngine.xpForEstimation(rating: .spot_on, difficultyLevel: 5)
        XCTAssertEqual(xp, 200)
    }

    func testMinimumEffortSessionEarnsMinimalXP() {
        // EXPLOIT: Speedrun with way_off on 3 tasks for streak credit
        let wayOff = XPEngine.xpForEstimation(rating: .way_off)
        let sessionXP = wayOff * 3 + XPConfiguration.default.completionBonus
        let perfectXP = XPEngine.xpForEstimation(rating: .spot_on) * 3 + XPConfiguration.default.completionBonus
        XCTAssertGreaterThan(Double(perfectXP) / Double(sessionXP), 5.0,
                             "Honest play must be 5x+ more rewarding than gaming")
    }
}
