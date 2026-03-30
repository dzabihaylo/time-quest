import XCTest
@testable import TimeQuest

final class SessionIntegrityTests: XCTestCase {

    func testImplausiblyFastCompletion() {
        XCTAssertFalse(SessionIntegrityChecker.isPlausibleDuration(estimatedSeconds: 300, actualSeconds: 2.0))
    }

    func testReasonablyFastCompletion() {
        XCTAssertTrue(SessionIntegrityChecker.isPlausibleDuration(estimatedSeconds: 300, actualSeconds: 120))
    }

    func testNegativeDuration() {
        XCTAssertFalse(SessionIntegrityChecker.isPlausibleDuration(estimatedSeconds: 300, actualSeconds: -10))
    }

    func testAbsurdlyLongDuration() {
        XCTAssertFalse(SessionIntegrityChecker.isPlausibleDuration(estimatedSeconds: 300, actualSeconds: 86400))
    }

    func testMinimumActiveTimeFloor() {
        XCTAssertFalse(SessionIntegrityChecker.isPlausibleDuration(estimatedSeconds: 10, actualSeconds: 0.5))
    }

    func testClassifySuspiciouslyFast() {
        XCTAssertEqual(SessionIntegrityChecker.classify(estimatedSeconds: 300, actualSeconds: 1), .suspiciouslyFast)
    }

    func testClassifyClockManipulation() {
        XCTAssertEqual(SessionIntegrityChecker.classify(estimatedSeconds: 300, actualSeconds: -5), .clockManipulation)
    }

    func testClassifyAbandoned() {
        XCTAssertEqual(SessionIntegrityChecker.classify(estimatedSeconds: 60, actualSeconds: 7200), .abandoned)
    }

    func testClassifyClean() {
        XCTAssertEqual(SessionIntegrityChecker.classify(estimatedSeconds: 300, actualSeconds: 280), .clean)
    }
}
