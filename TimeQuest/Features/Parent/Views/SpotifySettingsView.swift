import SwiftUI

struct SpotifySettingsView: View {
    @Environment(AppDependencies.self) private var dependencies

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            if dependencies.spotifyAuthManager.isConnected {
                connectedSection
            } else {
                disconnectedSection
            }
        }
        .navigationTitle("Spotify")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Restore display name if connected but name not yet loaded
            if dependencies.spotifyAuthManager.isConnected,
               dependencies.spotifyAuthManager.userDisplayName == nil {
                do {
                    let profile = try await dependencies.spotifyAuthManager.fetchUserProfile()
                    dependencies.spotifyAuthManager.userDisplayName = profile.displayName
                } catch {
                    // Non-fatal -- connected state is still valid
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Connected

    private var connectedSection: some View {
        Group {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    if let displayName = dependencies.spotifyAuthManager.userDisplayName {
                        Text("Connected as \(displayName)")
                    } else {
                        Text("Connected")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    dependencies.spotifyAuthManager.disconnect()
                } label: {
                    Text("Disconnect")
                }
            }
        }
    }

    // MARK: - Disconnected

    private var disconnectedSection: some View {
        Section {
            Text("Connect Spotify to pair playlists with routines. Music plays in the Spotify app during quests.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if dependencies.spotifyAuthManager.isAuthenticating {
                HStack {
                    ProgressView()
                    Text("Connecting...")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Connect Spotify") {
                    Task {
                        do {
                            try await dependencies.spotifyAuthManager.authorize()
                        } catch SpotifyError.authCancelled {
                            // User cancelled -- do nothing
                        } catch {
                            errorMessage = "Could not connect to Spotify. Please try again."
                            showError = true
                        }
                    }
                }
            }
        }
    }
}
