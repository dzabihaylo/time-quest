import XCTest
@testable import TimeQuest

final class SpotifyPlaylistMatcherTests: XCTestCase {

    private let matcher = SpotifyPlaylistMatcher()

    func testEmptyTracksReturnsZero() {
        let result = matcher.matchDuration(trackDurationsMs: [], targetDurationSeconds: 300)
        XCTAssertEqual(result.trackCount, 0)
    }

    func testZeroTargetReturnsZero() {
        let result = matcher.matchDuration(trackDurationsMs: [180000, 200000], targetDurationSeconds: 0)
        XCTAssertEqual(result.trackCount, 0)
    }

    func testMatchesDurationCorrectly() {
        // 3-minute songs (180000ms each), 10-minute target
        let durations = [180000, 180000, 180000, 180000, 180000]
        let result = matcher.matchDuration(trackDurationsMs: durations, targetDurationSeconds: 600)
        XCTAssertGreaterThanOrEqual(result.trackCount, 3)
        XCTAssertLessThanOrEqual(result.trackCount, 4)
    }

    func testSongCountFormatSingular() {
        XCTAssertEqual(matcher.formatSongCount(1.0), "1 song")
    }

    func testSongCountFormatPlural() {
        XCTAssertEqual(matcher.formatSongCount(3.0), "3 songs")
    }

    func testSongCountFormatHalf() {
        XCTAssertEqual(matcher.formatSongCount(4.5), "4.5 songs")
    }

    func testSongCountFormatLessThanOne() {
        XCTAssertEqual(matcher.formatSongCount(0.2), "less than 1 song")
    }

    func testSongCountLeaksTimeInfo() {
        // DOCUMENTED: Song count reveals time info — accepted trade-off
        let durations = [210000, 210000, 210000, 210000, 210000]  // 3.5 min each
        let result = matcher.matchDuration(trackDurationsMs: durations, targetDurationSeconds: 945)
        XCTAssertTrue(result.songCountLabel.contains("4.5") || result.songCountLabel.contains("5"),
                      "Song count leaks time — documented trade-off")
    }
}
