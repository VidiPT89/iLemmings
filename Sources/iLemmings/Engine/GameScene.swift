import SpriteKit

final class GameScene: SKScene {
    let engine: GameEngine
    private let tileSize: CGFloat = 16
    private var terrainNode = SKNode()
    private var lemmingNodes: [Int: SKShapeNode] = [:]
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

            let target = CGPoint(x: CGFloat(lem.x) * tileSize + tileSize / 2, y: flipRow(lem.y) + tileSize / 2)
            node.run(.move(to: target, duration: 1.0 / engine.ticksPerSecond))
            node.isHidden = !lem.isAlive
            node.xScale = lem.facingRight ? abs(node.xScale) : -abs(node.xScale)

            colorLemming(node, for: lem)
        }
        for (id, node) in lemmingNodes where !seen.contains(id) {
            node.removeFromParent()
            lemmingNodes.removeValue(forKey: id)
        }
    }

    private func makeLemmingNode(for lem: Lemming) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: tileSize * 0.35)
        node.strokeColor = .black
        node.lineWidth = 1
        node.name = "lem-\(lem.id)"
        node.zPosition = 10
        return node
    }

    private func colorLemming(_ node: SKShapeNode, for lem: Lemming) {
        switch lem.state {
        case .blocking: node.fillColor = SKColor.systemRed
        case .building: node.fillColor = SKColor.systemYellow
        case .basher, .miner, .digger: node.fillColor = SKColor.systemBrown
        case .exploding: node.fillColor = SKColor.systemPink
        case .climbing: node.fillColor = SKColor.systemTeal
        case .floating: node.fillColor = SKColor.systemCyan
        default: node.fillColor = SKColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1)
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
            if let name = n.name, name.hasPrefix("lem-"), let id = Int(name.dropFirst(4)) {
                onLemmingTapped?(id)
                return
            }
        }
    }
}
