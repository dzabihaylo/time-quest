import SwiftUI

/// Compact Now Playing overlay showing current Spotify track info.
/// Designed to sit at the bottom of the active quest view.
/// Caller conditionally renders this only when nowPlayingInfo is non-nil.
struct NowPlayingIndicator: View {
    let info: NowPlayingInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(info.trackName)
                    .font(.caption)
                    .lineLimit(1)

                Text(info.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }
}
