import XCTest
@testable import TimeQuest

final class InsightEngineTests: XCTestCase {

    // MARK: - Test Helper

    private func makeSnapshot(
        taskName: String = "Brush Teeth",
        estimated: Double = 120,
        actual: Double = 120,
        difference: Double = 0,
        accuracy: Double = 100,
        recordedAt: Date = Date(),
        routineName: String = "Morning",
        isCalibration: Bool = false
    ) -> EstimationSnapshot {
        EstimationSnapshot(
            taskDisplayName: taskName,
            estimatedSeconds: estimated,
            actualSeconds: actual,
            differenceSeconds: difference,
            accuracyPercent: accuracy,
            recordedAt: recordedAt,
            routineName: routineName,
            isCalibration: isCalibration
        )
    }

    /// Create N snapshots with sequential dates, optionally mixing in calibration.
    private func makeSnapshots(
        count: Int,
        taskName: String = "Brush Teeth",
        difference: Double = 0,
        accuracy: Double = 75,
        isCalibration: Bool = false
    ) -> [EstimationSnapshot] {
        (0..<count).map { i in
            makeSnapshot(
                taskName: taskName,
                estimated: 120 + difference,
                actual: 120,
                difference: difference,
                accuracy: accuracy,
                recordedAt: Date(timeIntervalSinceNow: Double(i) * 86400),
                isCalibration: isCalibration
            )
        }
    }

    // MARK: - detectBias Tests

    func test_detectBias_returnsNil_whenFewerThan5NonCalibrationSnapshots() {
        // 4 non-calibration + 3 calibration = 4 eligible
        var snapshots = makeSnapshots(count: 4, difference: 30)
        snapshots += makeSnapshots(count: 3, difference: 30, isCalibration: true)

        let result = InsightEngine.detectBias(snapshots: snapshots)
        XCTAssertNil(result, "Should return nil when fewer than 5 non-calibration snapshots")
    }

    func test_detectBias_overestimates_whenMeanDifferenceAboveThreshold() {
        // 6 snapshots with positive difference averaging > 15s
        let snapshots = makeSnapshots(count: 6, difference: 30)

        let result = InsightEngine.detectBias(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.direction, .overestimates)
        XCTAssertEqual(result?.sampleCount, 6)
        XCTAssertEqual(result?.meanDifferenceSeconds, 30, accuracy: 0.01)
    }

    func test_detectBias_underestimates_whenMeanDifferenceBelowNegativeThreshold() {
        // 6 snapshots with negative difference averaging < -15s
        let snapshots = makeSnapshots(count: 6, difference: -25)

        let result = InsightEngine.detectBias(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.direction, .underestimates)
        XCTAssertEqual(result?.meanDifferenceSeconds, -25, accuracy: 0.01)
    }

    func test_detectBias_balanced_whenMeanDifferenceWithinThreshold() {
        // 6 snapshots with small diffs within +-15s
        let snapshots = makeSnapshots(count: 6, difference: 5)

        let result = InsightEngine.detectBias(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.direction, .balanced)
    }

    func test_detectBias_excludesCalibrationSessions() {
        // 5 calibration + 4 non-calibration = only 4 eligible -> nil
        var snapshots = makeSnapshots(count: 5, difference: 30, isCalibration: true)
        snapshots += makeSnapshots(count: 4, difference: 30)

        let result = InsightEngine.detectBias(snapshots: snapshots)
        XCTAssertNil(result, "Should return nil because only 4 non-calibration snapshots")
    }

    // MARK: - detectTrend Tests

    func test_detectTrend_returnsNil_whenInsufficientData() {
        let snapshots = makeSnapshots(count: 3, accuracy: 75)

        let result = InsightEngine.detectTrend(snapshots: snapshots)
        XCTAssertNil(result, "Should return nil for fewer than 5 snapshots")
    }

    func test_detectTrend_improving_whenAccuracyIncreasingOverTime() {
        // 7 snapshots with accuracy going 50, 55, 60, 65, 70, 75, 80
        let snapshots = (0..<7).map { i in
            makeSnapshot(
                accuracy: 50 + Double(i) * 5,
                recordedAt: Date(timeIntervalSinceNow: Double(i) * 86400)
            )
        }

        let result = InsightEngine.detectTrend(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.direction, .improving)
        XCTAssertEqual(result?.sampleCount, 7)
        XCTAssertGreaterThan(result?.slopePerSession ?? 0, InsightEngine.trendSlopeThreshold)
    }

    func test_detectTrend_declining_whenAccuracyDecreasing() {
        // 7 snapshots with accuracy going 90, 85, 80, 75, 70, 65, 60
        let snapshots = (0..<7).map { i in
            makeSnapshot(
                accuracy: 90 - Double(i) * 5,
                recordedAt: Date(timeIntervalSinceNow: Double(i) * 86400)
            )
        }

        let result = InsightEngine.detectTrend(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.direction, .declining)
        XCTAssertLessThan(result?.slopePerSession ?? 0, -InsightEngine.trendSlopeThreshold)
    }

    func test_detectTrend_stable_whenAccuracyFlat() {
        // 6 snapshots with accuracy all ~75
        let snapshots = (0..<6).map { i in
            makeSnapshot(
                accuracy: 75 + Double(i) * 0.1,
                recordedAt: Date(timeIntervalSinceNow: Double(i) * 86400)
            )
        }

        let result = InsightEngine.detectTrend(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.direction, .stable)
    }

    // MARK: - computeConsistency Tests

    func test_computeConsistency_returnsNil_whenInsufficientData() {
        let snapshots = makeSnapshots(count: 3, difference: 10)

        let result = InsightEngine.computeConsistency(snapshots: snapshots)
        XCTAssertNil(result, "Should return nil for fewer than 5 snapshots")
    }

    func test_computeConsistency_veryConsistent_whenLowCV() {
        // 6 snapshots with very similar abs(differenceSeconds) values
        let snapshots = [28.0, 30.0, 32.0, 29.0, 31.0, 30.0].enumerated().map { i, diff in
            makeSnapshot(
                difference: diff,
                recordedAt: Date(timeIntervalSinceNow: Double(i) * 86400)
            )
        }

        let result = InsightEngine.computeConsistency(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.level, .veryConsistent)
        XCTAssertLessThan(result?.coefficientOfVariation ?? 1, InsightEngine.consistencyLowCV)
    }

    func test_computeConsistency_variable_whenHighCV() {
        // 6 snapshots with wildly different abs diffs
        let snapshots = [5.0, 120.0, 10.0, 200.0, 15.0, 180.0].enumerated().map { i, diff in
            makeSnapshot(
                difference: diff,
                recordedAt: Date(timeIntervalSinceNow: Double(i) * 86400)
            )
        }

        let result = InsightEngine.computeConsistency(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.level, .variable)
        XCTAssertGreaterThanOrEqual(result?.coefficientOfVariation ?? 0, InsightEngine.consistencyHighCV)
    }

    func test_computeConsistency_perfectEstimates_returnsVeryConsistent() {
        // All diffs = 0
        let snapshots = makeSnapshots(count: 6, difference: 0)

        let result = InsightEngine.computeConsistency(snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.level, .veryConsistent)
        XCTAssertEqual(result?.coefficientOfVariation, 0, accuracy: 0.001)
    }

    // MARK: - contextualHint Tests

    func test_contextualHint_returnsNil_whenInsufficientData() {
        let snapshots = makeSnapshots(count: 3, taskName: "Brush Teeth")

        let result = InsightEngine.contextualHint(taskName: "Brush Teeth", snapshots: snapshots)
        XCTAssertNil(result, "Should return nil for fewer than 5 snapshots")
    }

    func test_contextualHint_returnsFormattedString_whenEnoughData() {
        // 7 snapshots for "Brush Teeth" with actual = 150s (2m 30s)
        let snapshots = (0..<7).map { i in
            makeSnapshot(
                taskName: "Brush Teeth",
                actual: 150,
                recordedAt: Date(timeIntervalSinceNow: Double(-i) * 86400)
            )
        }

        let result = InsightEngine.contextualHint(taskName: "Brush Teeth", snapshots: snapshots)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("Last 5 times:") == true, "Should contain 'Last 5 times:'")
        XCTAssertTrue(result?.contains("2m 30s") == true, "Should contain formatted duration '2m 30s'")
    }

    func test_contextualHint_excludesCalibration() {
        // 5 calibration + 4 non-calibration -> only 4 eligible -> nil
        var snapshots = makeSnapshots(count: 5, taskName: "Brush Teeth", isCalibration: true)
        snapshots += (0..<4).map { i in
            makeSnapshot(
                taskName: "Brush Teeth",
                actual: 150,
                recordedAt: Date(timeIntervalSinceNow: Double(i) * 86400)
            )
        }

        let result = InsightEngine.contextualHint(taskName: "Brush Teeth", snapshots: snapshots)
        XCTAssertNil(result, "Should return nil because only 4 non-calibration snapshots")
    }

    func test_contextualHint_filtersToSpecificTask() {
        // 6 "Brush Teeth" + 6 "Shower" -> hint for "Brush Teeth" only uses its data
        var snapshots = (0..<6).map { i in
            makeSnapshot(
                taskName: "Brush Teeth",
                actual: 120,
                recordedAt: Date(timeIntervalSinceNow: Double(-i) * 86400)
            )
        }
        snapshots += (0..<6).map { i in
            makeSnapshot(
                taskName: "Shower",
                actual: 600,
                recordedAt: Date(timeIntervalSinceNow: Double(-i) * 86400)
            )
        }

        let result = InsightEngine.contextualHint(taskName: "Brush Teeth", snapshots: snapshots)
        XCTAssertNotNil(result)
        // Brush Teeth actual is 120s = 2m 0s
        XCTAssertTrue(result?.contains("2m 0s") == true, "Should use Brush Teeth actuals (120s), not Shower (600s)")
    }

    // MARK: - generateInsights Tests

    func test_generateInsights_groupsByTaskAndReturnsInsights() {
        // 6 snapshots each for 2 tasks
        var snapshots = makeSnapshots(count: 6, taskName: "Brush Teeth", difference: 20, accuracy: 80)
        snapshots += makeSnapshots(count: 6, taskName: "Shower", difference: -10, accuracy: 90)

        let insights = InsightEngine.generateInsights(snapshots: snapshots)
        XCTAssertEqual(insights.count, 2, "Should return insights for both tasks")

        let taskNames = Set(insights.map(\.taskDisplayName))
        XCTAssertTrue(taskNames.contains("Brush Teeth"))
        XCTAssertTrue(taskNames.contains("Shower"))
    }

    func test_generateInsights_excludesTasksWithInsufficientData() {
        // 4 snapshots for a task -> should not appear
        let snapshots = makeSnapshots(count: 4, taskName: "Brush Teeth", difference: 20, accuracy: 80)

        let insights = InsightEngine.generateInsights(snapshots: snapshots)
        XCTAssertTrue(insights.isEmpty, "Should exclude tasks with fewer than 5 non-calibration snapshots")
    }
}
