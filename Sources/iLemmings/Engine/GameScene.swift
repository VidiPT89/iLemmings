import SpriteKit

final class GameScene: SKScene {
    let engine: GameEngine
    private let tileSize: CGFloat = 16
    private var terrainNode = SKNode()
    private var lemmingNodes: [Int: SKSpriteNode] = [:]
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0
    private var paused_ = false

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
        redrawTerrain()
    }

    func setEnginePaused(_ paused: Bool) { paused_ = paused }

    private func flipRow(_ row: Int) -> CGFloat {
        CGFloat(engine.height - 1 - row) * tileSize
    }

    private func redrawTerrain() {
        terrainNode.removeAllChildren()
        for r in 0..<engine.height {
            for c in 0..<engine.width {
                let t = engine.tile(r, c)
                guard t != .empty else { continue }
                let node = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
                node.position = CGPoint(x: CGFloat(c) * tileSize + tileSize / 2, y: flipRow(r) + tileSize / 2)
                node.lineWidth = 0
                switch t {
                case .dirt: node.fillColor = SKColor(red: 0.62, green: 0.34, blue: 0.05, alpha: 1)
                case .steel: node.fillColor = SKColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 1)
                case .trap: node.fillColor = SKColor(red: 0.75, green: 0.1, blue: 0.05, alpha: 1)
                case .exit: node.fillColor = SKColor(red: 0.85, green: 0.58, blue: 0.09, alpha: 1)
                case .entrance: node.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.6)
                case .empty: break
                }
                terrainNode.addChild(node)
            }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard !paused_ else { return }
        accumulator += dt
        let step = 1.0 / engine.ticksPerSecond
        var terrainChanged = false
        while accumulator >= step {
            let before = engine.grid
            engine.tick()
            if engine.grid != before { terrainChanged = true }
            accumulator -= step
        }
        if terrainChanged { redrawTerrain() }
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
        }
        for (id, node) in lemmingNodes where !seen.contains(id) {
            node.removeFromParent()
            lemmingNodes.removeValue(forKey: id)
        }
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
