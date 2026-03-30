import XCTest
@testable import TimeQuest

final class StreakTrackerTests: XCTestCase {

    func testFirstSessionStartsStreak() {
        let result = StreakTracker.updatedStreak(currentStreak: 0, lastPlayedDate: nil, today: .now)
        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertTrue(result.isActive)
    }

    func testSameDayDoesNotIncrement() {
        let today = Date.now
        let result = StreakTracker.updatedStreak(currentStreak: 5, lastPlayedDate: today, today: today)
        XCTAssertEqual(result.currentStreak, 5)
    }

    func testConsecutiveDayIncrements() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let result = StreakTracker.updatedStreak(currentStreak: 5, lastPlayedDate: yesterday, today: .now)
        XCTAssertEqual(result.currentStreak, 6)
    }

    func testGapPausesNotResets() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        let result = StreakTracker.updatedStreak(currentStreak: 10, lastPlayedDate: threeDaysAgo, today: .now)
        XCTAssertEqual(result.currentStreak, 10, "ADHD-friendly: pause, never reset")
        XCTAssertFalse(result.isActive)
    }

    func testBackwardClockDoesNotCrash() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let result = StreakTracker.updatedStreak(currentStreak: 5, lastPlayedDate: tomorrow, today: .now)
        XCTAssertGreaterThanOrEqual(result.currentStreak, 0)
    }

    func testStreakSurvivesMonthAbsence() {
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let result = StreakTracker.updatedStreak(currentStreak: 15, lastPlayedDate: monthAgo, today: .now)
        XCTAssertEqual(result.currentStreak, 15, "30-day gap pauses at 15")
    }

    func testStreakReactivatesOnConsecutivePlay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let result = StreakTracker.updatedStreak(currentStreak: 15, lastPlayedDate: yesterday, today: .now)
        XCTAssertEqual(result.currentStreak, 16)
        XCTAssertTrue(result.isActive)
    }
}
