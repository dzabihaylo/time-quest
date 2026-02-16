import SpriteKit

/// SpriteKit particle scene for milestone celebrations.
/// Renders type-specific particle bursts for level ups, personal bests, and streaks.
final class CelebrationScene: SKScene {

    enum CelebrationType {
        case levelUp
        case personalBest
        case streak(Int)
    }

    var celebrationType: CelebrationType = .levelUp
    private let tokens = DesignTokens()

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        size = view.bounds.size

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        spawnBurst(at: center)
    }

    private func spawnBurst(at position: CGPoint) {
        let config = burstConfig(for: celebrationType)

        for _ in 0..<config.particleCount {
            let radius = CGFloat.random(in: 2...6)
            let particle = SKShapeNode(circleOfRadius: radius)
            particle.fillColor = config.colors.randomElement() ?? .white
            particle.strokeColor = .clear
            particle.position = position
            particle.alpha = 1.0
            particle.zPosition = 1
            addChild(particle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: config.radiusRange)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let duration = Double.random(in: config.durationRange)

            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: duration)
            moveAction.timingMode = .easeOut

            let fadeAction = SKAction.fadeOut(withDuration: duration)
            let scaleAction = SKAction.scale(to: 0.3, duration: duration)

            let group = SKAction.group([moveAction, fadeAction, scaleAction])
            let sequence = SKAction.sequence([group, .removeFromParent()])

            particle.run(sequence)
        }
    }

    private struct BurstConfig {
        let particleCount: Int
        let radiusRange: ClosedRange<CGFloat>
        let durationRange: ClosedRange<Double>
        let colors: [SKColor]
    }

    private func burstConfig(for type: CelebrationType) -> BurstConfig {
        switch type {
        case .levelUp:
            return BurstConfig(
                particleCount: 60,
                radiusRange: 60...150,
                durationRange: 1.0...2.0,
                colors: tokens.celebrationGolds
            )
        case .personalBest:
            return BurstConfig(
                particleCount: 40,
                radiusRange: 40...120,
                durationRange: 0.8...1.6,
                colors: tokens.celebrationTeals
            )
        case .streak:
            return BurstConfig(
                particleCount: 30,
                radiusRange: 40...100,
                durationRange: 0.6...1.4,
                colors: tokens.celebrationStreaks
            )
        }
    }
}
