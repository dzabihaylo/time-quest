import AuthenticationServices
import CryptoKit
import Foundation

// MARK: - Token Storage Type

struct SpotifyTokens: Codable, Sendable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - SpotifyAuthManager

@MainActor
@Observable
final class SpotifyAuthManager: NSObject {

    // MARK: - Observable State

    var isConnected: Bool = false
    var userDisplayName: String?
    private(set) var isAuthenticating: Bool = false

    // MARK: - Constants

    private let clientID = "YOUR_SPOTIFY_CLIENT_ID"
    private let redirectURI = "timequest://spotify-callback"
    private let tokenEndpoint = "https://accounts.spotify.com/api/token"
    private let authorizeEndpoint = "https://accounts.spotify.com/authorize"

    // MARK: - Scopes

    private var scopes: String {
        [
            "playlist-read-private",
            "playlist-read-collaborative",
            "user-read-currently-playing",
            "user-read-playback-state"
        ].joined(separator: " ")
    }

    // MARK: - Token Refresh Race Protection

    private var refreshTask: Task<String, Error>?

    // MARK: - Init / Restore

    override init() {
        super.init()
        // Check if tokens exist in Keychain to restore connected state
        if loadTokens() != nil {
            isConnected = true
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .prefix(128)
            .description
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Authorization Flow

    func authorize() async throws {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: authorizeEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: scopes)
        ]

        guard let authURL = components.url else {
            throw SpotifyError.invalidResponse
        }

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "timequest"
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: SpotifyError.authCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: SpotifyError.invalidResponse)
                    return
                }

                continuation.resume(returning: code)
            }

            // Reuse existing Safari login for better UX (family app -- research pitfall #7)
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            session.start()
        }

        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code: code, verifier: verifier)
        try saveTokens(tokens)

        // Fetch user profile to set display name
        let profile = try await fetchUserProfile()
        userDisplayName = profile.displayName
        isConnected = true
    }

    // MARK: - Token Exchange

    func exchangeCodeForTokens(code: String, verifier: String) async throws -> SpotifyTokens {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI)",
            "client_id=\(clientID)",
            "code_verifier=\(verifier)"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpotifyError.invalidResponse
        }

        return try JSONDecoder().decode(SpotifyTokens.self, from: data)
    }

    // MARK: - Token Storage (Keychain)

    func saveTokens(_ tokens: SpotifyTokens) throws {
        guard let accessData = tokens.accessToken.data(using: .utf8) else {
            throw SpotifyError.invalidResponse
        }
        try KeychainHelper.save(accessData, forKey: "access_token")

        if let refreshToken = tokens.refreshToken,
           let refreshData = refreshToken.data(using: .utf8) {
            try KeychainHelper.save(refreshData, forKey: "refresh_token")
        }

        let expiryDate = Date.now.addingTimeInterval(TimeInterval(tokens.expiresIn))
        let expiryData = try JSONEncoder().encode(expiryDate)
        try KeychainHelper.save(expiryData, forKey: "token_expiry")
    }

    func loadTokens() -> (accessToken: String, refreshToken: String, expiryDate: Date)? {
        guard let accessData = KeychainHelper.load(forKey: "access_token"),
              let accessToken = String(data: accessData, encoding: .utf8),
              let refreshData = KeychainHelper.load(forKey: "refresh_token"),
              let refreshToken = String(data: refreshData, encoding: .utf8),
              let expiryData = KeychainHelper.load(forKey: "token_expiry"),
              let expiryDate = try? JSONDecoder().decode(Date.self, from: expiryData) else {
            return nil
        }
        return (accessToken, refreshToken, expiryDate)
    }

    // MARK: - Token Refresh with Race Condition Protection

    func validAccessToken() async throws -> String {
        guard let stored = loadTokens() else {
            throw SpotifyError.notConnected
        }

        // Check expiry with 60-second buffer
        if stored.expiryDate.timeIntervalSinceNow > 60 {
            return stored.accessToken
        }

        // Token expired or expiring soon -- refresh
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        let task = Task<String, Error> {
            defer { refreshTask = nil }
            try await refreshAccessToken()
            guard let refreshed = loadTokens() else {
                throw SpotifyError.tokenExpired
            }
            return refreshed.accessToken
        }

        refreshTask = task
        return try await task.value
    }

    private func refreshAccessToken() async throws {
        guard let stored = loadTokens() else {
            throw SpotifyError.notConnected
        }

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(stored.refreshToken)",
            "client_id=\(clientID)"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpotifyError.tokenExpired
        }

        let tokens = try JSONDecoder().decode(SpotifyTokens.self, from: data)
        try saveTokens(tokens)
    }

    // MARK: - Disconnect

    func disconnect() {
        KeychainHelper.delete(forKey: "access_token")
        KeychainHelper.delete(forKey: "refresh_token")
        KeychainHelper.delete(forKey: "token_expiry")
        isConnected = false
        userDisplayName = nil
    }

    // MARK: - User Profile

    func fetchUserProfile() async throws -> SpotifyUserProfile {
        let token = try await validAccessToken()
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpotifyError.invalidResponse
        }

        return try JSONDecoder().decode(SpotifyUserProfile.self, from: data)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyAuthManager: @preconcurrency ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            ASPresentationAnchor()
        }
    }
}
