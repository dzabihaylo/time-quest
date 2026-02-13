import AVFoundation

@MainActor
@Observable
final class SoundManager {
    var isMuted: Bool

    private var players: [String: AVAudioPlayer] = [:]

    private static let soundNames = [
        "estimate_lock",
        "reveal",
        "level_up",
        "personal_best",
        "session_complete"
    ]

    init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "soundMuted")
        preloadAll()
    }

    func preloadAll() {
        for name in Self.soundNames {
            preload(name)
        }
    }

    func preload(_ soundName: String, ext: String = "wav") {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: ext) else {
            // Sound file not found -- silently skip (sounds are optional)
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[soundName] = player
        } catch {
            // Failed to load sound -- silently skip
        }
    }

    func play(_ soundName: String) {
        guard !isMuted, let player = players[soundName] else { return }
        // Strong reference kept in players dict prevents deallocation (research pitfall 3)
        player.currentTime = 0
        player.play()
    }

    func toggleMute() {
        isMuted.toggle()
        UserDefaults.standard.set(isMuted, forKey: "soundMuted")
    }
}
