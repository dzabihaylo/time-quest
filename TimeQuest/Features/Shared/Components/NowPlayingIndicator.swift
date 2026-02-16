import SwiftUI

/// Compact Now Playing overlay showing current Spotify track info.
/// Designed to sit at the bottom of the active quest view.
/// Caller conditionally renders this only when nowPlayingInfo is non-nil.
struct NowPlayingIndicator: View {
    let info: NowPlayingInfo
    @Environment(\.designTokens) private var tokens

    var body: some View {
        HStack(spacing: tokens.spacingSM) {
            Image(systemName: "music.note")
                .font(tokens.font(.caption))
                .foregroundStyle(tokens.textSecondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(info.trackName)
                    .font(tokens.font(.caption))
                    .lineLimit(1)

                Text(info.artistName)
                    .font(tokens.font(.caption2))
                    .foregroundStyle(tokens.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, tokens.spacingMD)
        .padding(.vertical, tokens.spacingSM)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: tokens.cornerRadiusSM + 2))
        .padding(.horizontal, tokens.spacingLG)
    }
}
