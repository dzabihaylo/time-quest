import Foundation

// MARK: - Playlist Match Result

struct PlaylistMatchResult: Sendable {
    let trackCount: Int
    let totalDurationSeconds: Double
    let songCountLabel: String
}

// MARK: - Spotify Playlist Matcher

/// Pure domain engine for duration-based song counting.
/// Computes how many songs from a playlist fit a target routine duration
/// and produces human-readable labels like "4.5 songs".
struct SpotifyPlaylistMatcher: Sendable {

    /// Matches track durations against a target duration to compute song count.
    ///
    /// Iterates tracks in order, accumulating duration until >= target.
    /// Calculates fractional song count as targetMs / averageTrackMs.
    ///
    /// - Parameters:
    ///   - trackDurationsMs: Array of track durations in milliseconds, in playlist order.
    ///   - targetDurationSeconds: The routine's total duration in seconds.
    /// - Returns: A `PlaylistMatchResult` with track count, total duration, and formatted label.
    func matchDuration(trackDurationsMs: [Int], targetDurationSeconds: Double) -> PlaylistMatchResult {
        guard !trackDurationsMs.isEmpty, targetDurationSeconds > 0 else {
            return PlaylistMatchResult(
                trackCount: 0,
                totalDurationSeconds: 0,
                songCountLabel: formatSongCount(0)
            )
        }

        let targetMs = targetDurationSeconds * 1000.0

        // Calculate average track duration
        let totalTrackMs = trackDurationsMs.reduce(0, +)
        let averageTrackMs = Double(totalTrackMs) / Double(trackDurationsMs.count)

        guard averageTrackMs > 0 else {
            return PlaylistMatchResult(
                trackCount: 0,
                totalDurationSeconds: 0,
                songCountLabel: formatSongCount(0)
            )
        }

        // Fractional song count based on target vs average
        let fractionalCount = targetMs / averageTrackMs

        // Count how many whole tracks fit within the target
        var accumulatedMs = 0.0
        var trackCount = 0
        for durationMs in trackDurationsMs {
            accumulatedMs += Double(durationMs)
            trackCount += 1
            if accumulatedMs >= targetMs {
                break
            }
        }

        let totalDurationSeconds = accumulatedMs / 1000.0

        return PlaylistMatchResult(
            trackCount: trackCount,
            totalDurationSeconds: totalDurationSeconds,
            songCountLabel: formatSongCount(fractionalCount)
        )
    }

    /// Formats a fractional song count into a human-readable label.
    ///
    /// Rounds to nearest 0.5. Examples:
    /// - 0.3 -> "less than 1 song"
    /// - 1.0 -> "1 song"
    /// - 3.0 -> "3 songs"
    /// - 4.3 -> "4.5 songs"
    func formatSongCount(_ count: Double) -> String {
        // Round to nearest 0.5
        let rounded = (count * 2).rounded() / 2

        if rounded < 0.5 {
            return "less than 1 song"
        } else if rounded == 1.0 {
            return "1 song"
        } else if rounded == rounded.rounded(.down) {
            // Whole number
            return "\(Int(rounded)) songs"
        } else {
            // Half number (e.g., 4.5)
            return "\(String(format: "%.1f", rounded)) songs"
        }
    }
}
