import SwiftUI

struct PlaylistPickerView: View {
    @Binding var selectedPlaylistID: String?
    @Binding var selectedPlaylistName: String?

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var playlists: [SpotifyPlaylist] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Choose Playlist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
        .task {
            await loadPlaylists()
        }
    }

    // MARK: - Content States

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading playlists...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            errorView(message: errorMessage)
        } else if playlists.isEmpty {
            ContentUnavailableView(
                "No Playlists Found",
                systemImage: "music.note.list",
                description: Text("Create a playlist in Spotify first, then come back here.")
            )
        } else {
            playlistList
        }
    }

    private var playlistList: some View {
        List {
            ForEach(playlists) { playlist in
                Button {
                    selectedPlaylistID = playlist.id
                    selectedPlaylistName = playlist.name
                    dismiss()
                } label: {
                    playlistRow(playlist)
                }
            }
        }
    }

    private func playlistRow(_ playlist: SpotifyPlaylist) -> some View {
        HStack(spacing: 12) {
            // Playlist thumbnail
            if let imageURL = playlist.images.first?.url,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }

            // Name and track count
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("\(playlist.tracks.total) tracks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Checkmark if selected
            if playlist.id == selectedPlaylistID {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .fontWeight(.semibold)
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await loadPlaylists()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadPlaylists() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await dependencies.spotifyAPIClient.getUserPlaylists()
            playlists = result.items
            isLoading = false
        } catch {
            errorMessage = "Could not load playlists. Please check your connection and try again."
            isLoading = false
        }
    }
}
