import SpriteKit

final class GameScene: SKScene {
    let engine: GameEngine
    private let tileSize: CGFloat = 16
    private var terrainNode = SKNode()
    /// One optional node per cell, keyed by `row * width + col`. Updated
    /// incrementally (see `updateTerrain()`) instead of rebuilding the whole
    /// grid every time a single tile changes — digging used to rebuild
    /// hundreds of `SKShapeNode`s on every tick, causing visible stutter.
    private var terrainNodes: [Int: SKShapeNode] = [:]
    private var lastGrid: [[Tile]] = []
    private var lemmingNodes: [Int: SKSpriteNode] = [:]
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0
    private var paused_ = false
    private var previousStates: [Int: LemState] = [:]
    private var tickCounter = 0

    var onLemmingTapped: ((Int) -> Void)?

    init(engine: GameEngine) {
        self.engine = engine
        let size = CGSize(width: CGFloat(engine.width) * tileSize, height: CGFloat(engine.height) * tileSize)
        super.init(size: size)
        scaleMode = .aspectFit
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.07, green: 0.06, blue: 0.05, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        addChild(terrainNode)
        lastGrid = Array(repeating: Array(repeating: Tile.empty, count: engine.width), count: engine.height)
        updateTerrain()
    }

    func setEnginePaused(_ paused: Bool) { paused_ = paused }

    private func flipRow(_ row: Int) -> CGFloat {
        CGFloat(engine.height - 1 - row) * tileSize
    }

    private func fillColor(for tile: Tile) -> SKColor? {
        switch tile {
        case .dirt: return SKColor(red: 0.62, green: 0.34, blue: 0.05, alpha: 1)
        case .steel: return SKColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 1)
        case .trap: return SKColor(red: 0.75, green: 0.1, blue: 0.05, alpha: 1)
        case .exit: return SKColor(red: 0.85, green: 0.58, blue: 0.09, alpha: 1)
        case .entrance: return SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.6)
        case .empty: return nil
        }
    }

    /// Only touches the cells that actually changed since last frame —
    /// digging/bashing/mining edit one or two tiles per tick, so rebuilding
    /// the entire grid's shape nodes every time was wasted work that caused
    /// visible stutter on every dig.
    private func updateTerrain() {
        for r in 0..<engine.height {
            for c in 0..<engine.width {
                let tile = engine.tile(r, c)
                guard tile != lastGrid[r][c] else { continue }
                let key = r * engine.width + c

                guard let color = fillColor(for: tile) else {
                    terrainNodes[key]?.removeFromParent()
                    terrainNodes.removeValue(forKey: key)
                    continue
                }

                if let existing = terrainNodes[key] {
                    existing.fillColor = color
                } else {
                    let node = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
                    node.position = CGPoint(x: CGFloat(c) * tileSize + tileSize / 2, y: flipRow(r) + tileSize / 2)
                    node.lineWidth = 0
                    node.fillColor = color
                    terrainNode.addChild(node)
                    terrainNodes[key] = node
                }
            }
        }
        lastGrid = engine.grid
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard !paused_ else { return }
        accumulator += dt
        let step = 1.0 / engine.ticksPerSecond
        var ticked = false
        while accumulator >= step {
            engine.tick()
            tickCounter += 1
            ticked = true
            accumulator -= step
        }
        if ticked { updateTerrain() }
        syncLemmingNodes()
    }

    private func syncLemmingNodes() {
        var seen = Set<Int>()
        for lem in engine.lemmings {
            seen.insert(lem.id)
            let node = lemmingNodes[lem.id] ?? makeLemmingNode(for: lem)
            lemmingNodes[lem.id] = node
            if node.parent == nil { addChild(node) }

            let target = CGPoint(x: CGFloat(lem.x) * tileSize + tileSize / 2, y: flipRow(lem.y))
            node.run(.move(to: target, duration: 1.0 / engine.ticksPerSecond))
            node.isHidden = !lem.isAlive
            node.xScale = lem.facingRight ? abs(node.xScale) : -abs(node.xScale)

            updateAppearance(node, for: lem)
            emitParticles(for: lem, at: target)
            previousStates[lem.id] = lem.state
        }
        for (id, node) in lemmingNodes where !seen.contains(id) {
            node.removeFromParent()
            lemmingNodes.removeValue(forKey: id)
            previousStates.removeValue(forKey: id)
        }
    }

    private func emitParticles(for lem: Lemming, at position: CGPoint) {
        let wasExploding: Bool
        if case .exploding = previousStates[lem.id] ?? lem.state { wasExploding = true } else { wasExploding = false }

        switch lem.state {
        case .basher, .miner, .digger:
            if tickCounter % 4 == 0 { addParticles(kind: .dust, at: position) }
        case .dead:
            if wasExploding { addParticles(kind: .explosion, at: position) }
        default:
            break
        }
    }

    private enum ParticleKind { case dust, explosion }

    private static let particleTexture: SKTexture = {
        let size = 6
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }()

    private func addParticles(kind: ParticleKind, at position: CGPoint) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.particleTexture
        emitter.position = position
        emitter.zPosition = 20

        switch kind {
        case .dust:
            emitter.particleColor = SKColor(red: 0.62, green: 0.44, blue: 0.25, alpha: 1)
            emitter.particleBirthRate = 40
            emitter.numParticlesToEmit = 6
            emitter.particleLifetime = 0.35
            emitter.particleSpeed = 18
            emitter.particleSpeedRange = 10
            emitter.emissionAngleRange = .pi * 2
            emitter.particleScale = 0.5
            emitter.particleAlpha = 0.8
            emitter.particleAlphaSpeed = -2.0

        case .explosion:
            emitter.particleColor = SKColor.orange
            emitter.particleColorBlendFactor = 1
            emitter.particleBirthRate = 200
            emitter.numParticlesToEmit = 24
            emitter.particleLifetime = 0.5
            emitter.particleSpeed = 60
            emitter.particleSpeedRange = 40
            emitter.emissionAngleRange = .pi * 2
            emitter.particleScale = 0.9
            emitter.particleScaleSpeed = -1.2
            emitter.particleAlphaSpeed = -1.8
        }

        addChild(emitter)
        let wait = SKAction.wait(forDuration: Double(emitter.particleLifetime) + 0.3)
        emitter.run(.sequence([wait, .removeFromParent()]))
    }

    private func makeLemmingNode(for lem: Lemming) -> SKSpriteNode {
        let node = SKSpriteNode(texture: LemmingSprites.stand)
        node.size = CGSize(width: tileSize * 1.1, height: tileSize * 1.8)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.name = "lem-\(lem.id)"
        node.zPosition = 10

        let badge = SKShapeNode(circleOfRadius: 3.5)
        badge.name = "badge"
        badge.strokeColor = .black
        badge.lineWidth = 0.5
        badge.position = CGPoint(x: 0, y: node.size.height + 5)
        badge.isHidden = true
        node.addChild(badge)

        return node
    }

    /// Picks the right pixel-art frame/animation and skill badge for the
    /// lemming's current state, without recoloring the sprite itself — the
    /// green hair / blue overalls silhouette must always read as a lemming.
    private func updateAppearance(_ node: SKSpriteNode, for lem: Lemming) {
        let badge = node.childNode(withName: "badge") as? SKShapeNode
        badge?.isHidden = true

        switch lem.state {
        case .walking:
            if node.action(forKey: "walk") == nil {
                node.run(.repeatForever(LemmingSprites.walkAnimation), withKey: "walk")
            }
            return

        case .climbing:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.climb

        case .blocking:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.block
            badge?.isHidden = false
            badge?.fillColor = .systemRed

        case .building:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
            badge?.isHidden = false
            badge?.fillColor = .systemYellow

        case .basher, .miner, .digger:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
            badge?.isHidden = false
            badge?.fillColor = .brown

        case .exploding:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
            badge?.isHidden = false
            badge?.fillColor = .systemPink

        case .floating:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
            badge?.isHidden = false
            badge?.fillColor = .cyan

        case .falling, .saved, .dead:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
        }
    }

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        handleTap(at: t.location(in: self))
    }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) {
        handleTap(at: event.location(in: self))
    }
    #endif

    private func handleTap(at point: CGPoint) {
        let nodesHere = nodes(at: point)
        for n in nodesHere {
            let name = n.name ?? n.parent?.name
            if let name, name.hasPrefix("lem-"), let id = Int(name.dropFirst(4)) {
                onLemmingTapped?(id)
                return
            }
        }
    }
}
