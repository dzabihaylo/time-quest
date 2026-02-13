import SpriteKit

/// Minimal SpriteKit celebration scene for spot-on accuracy.
/// Displays a burst of particles from center that expand and fade.
final class AccuracyRevealScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        size = view.bounds.size

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        spawnBurst(at: center)
    }

    private func spawnBurst(at position: CGPoint) {
        let particleCount = 40

        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            particle.fillColor = randomGoldColor()
            particle.strokeColor = .clear
            particle.position = position
            particle.alpha = 1.0
            particle.zPosition = 1
            addChild(particle)

            // Random direction and distance
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 40...120)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let duration = Double.random(in: 0.6...1.4)

            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: duration)
            moveAction.timingMode = .easeOut

            let fadeAction = SKAction.fadeOut(withDuration: duration)
            let scaleAction = SKAction.scale(to: 0.3, duration: duration)

            let group = SKAction.group([moveAction, fadeAction, scaleAction])
            let sequence = SKAction.sequence([group, .removeFromParent()])

            particle.run(sequence)
        }
    }

    private func randomGoldColor() -> SKColor {
        let colors: [SKColor] = [
            SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0),    // Gold
            SKColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0),    // Orange
            SKColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 1.0),    // Light gold
            SKColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1.0),   // Deep gold
        ]
        return colors.randomElement() ?? .yellow
    }
}
