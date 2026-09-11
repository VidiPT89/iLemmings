import SpriteKit

final class GameScene: SKScene {
    let engine: GameEngine
    private let tileSize: CGFloat = 22
    /// How many tiles are visible across the screen width at default zoom.
    /// Levels are much wider than this, so the camera scrolls horizontally —
    /// the classic Lemmings view (full level height visible, side-scrolling),
    /// instead of squeezing the whole level into the screen and making every
    /// lemming a few pixels tall.
    private let visibleTilesWide: CGFloat = 15
    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 3.0

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

    private let gameCamera = SKCameraNode()
    private var worldWidth: CGFloat { CGFloat(engine.width) * tileSize }
    private var worldHeight: CGFloat { CGFloat(engine.height) * tileSize }
    private var dragStart: CGPoint?
    private var didDrag = false

    var onLemmingTapped: ((Int) -> Void)?

    init(engine: GameEngine) {
        self.engine = engine
        let viewportWidth = min(CGFloat(engine.width), 15) * tileSize
        let viewportHeight = CGFloat(engine.height) * tileSize
        super.init(size: CGSize(width: viewportWidth, height: viewportHeight))
        // .resizeFill maps 1 scene point to 1 view point exactly, so lemmings
        // always render at a fixed, readable pixel size. .aspectFit used to
        // squeeze the (roughly square) level into whatever window/screen
        // shape was available, leaving huge black bars on wide screens.
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.07, green: 0.06, blue: 0.05, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        addChild(makeSky())
        addChild(terrainNode)
        lastGrid = Array(repeating: Array(repeating: Tile.empty, count: engine.width), count: engine.height)
        updateTerrain()

        camera = gameCamera
        addChild(gameCamera)
        let startX = CGFloat(engine.entranceColumn) * tileSize
        gameCamera.position = CGPoint(x: clampedCameraX(startX), y: worldHeight / 2)
    }

    func setEnginePaused(_ paused: Bool) { paused_ = paused }

    /// Called by the SwiftUI container whenever the actual on-screen size
    /// changes (window resize, rotation). The level's world is a fixed,
    /// modest size in points (tileSize * tile count) — without this, a big
    /// macOS window would just show a small island of level surrounded by
    /// empty background. Zoom is set so the full level height always fills
    /// the view, matching the classic Lemmings full-height, side-scrolling
    /// camera; horizontal panning reveals the rest of the (wider) level.
    func resizeViewport(to newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        size = newSize
        let fitHeightScale = worldHeight / newSize.height
        gameCamera.setScale(min(max(fitHeightScale, minZoom), maxZoom))
        gameCamera.position.y = worldHeight / 2
        gameCamera.position.x = clampedCameraX(gameCamera.position.x)
    }

    // MARK: - Camera: pan & zoom

    private func clampedCameraX(_ x: CGFloat) -> CGFloat {
        let halfViewport = size.width * gameCamera.xScale / 2
        guard worldWidth > halfViewport * 2 else { return worldWidth / 2 }
        return min(max(x, halfViewport), worldWidth - halfViewport)
    }

    func pan(bySceneDelta delta: CGFloat) {
        gameCamera.position.x = clampedCameraX(gameCamera.position.x + delta)
    }

    func zoom(byFactor factor: CGFloat) {
        let newScale = min(max(gameCamera.xScale * factor, minZoom), maxZoom)
        gameCamera.setScale(newScale)
        gameCamera.position.x = clampedCameraX(gameCamera.position.x)
    }

    // MARK: - Sky & terrain

    private func makeSky() -> SKSpriteNode {
        let colors: [SKColor]
        switch engine.level.pack {
        case .fun: colors = [SKColor(red: 0.42, green: 0.68, blue: 0.85, alpha: 1), SKColor(red: 0.72, green: 0.85, blue: 0.68, alpha: 1)]
        case .tricky: colors = [SKColor(red: 0.55, green: 0.42, blue: 0.65, alpha: 1), SKColor(red: 0.85, green: 0.55, blue: 0.35, alpha: 1)]
        case .taxing: colors = [SKColor(red: 0.30, green: 0.30, blue: 0.34, alpha: 1), SKColor(red: 0.55, green: 0.40, blue: 0.30, alpha: 1)]
        case .mayhem: colors = [SKColor(red: 0.12, green: 0.05, blue: 0.05, alpha: 1), SKColor(red: 0.45, green: 0.12, blue: 0.08, alpha: 1)]
        }
        let texture = Self.gradientTexture(top: colors[0], bottom: colors[1])
        let sky = SKSpriteNode(texture: texture)
        sky.size = CGSize(width: worldWidth, height: worldHeight)
        sky.position = CGPoint(x: worldWidth / 2, y: worldHeight / 2)
        sky.zPosition = -10
        return sky
    }

    private static func gradientTexture(top: SKColor, bottom: SKColor) -> SKTexture {
        let width = 4, height = 256
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        let gradient = CGGradient(colorsSpace: colorSpace, colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: .zero, options: [])
        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }

    private func flipRow(_ row: Int) -> CGFloat {
        CGFloat(engine.height - 1 - row) * tileSize
    }

    /// Dirt capped by open air gets a grassy highlight, like the classic
    /// hand-drawn hills — otherwise every level reads as flat brown blocks.
    private func fillColor(for tile: Tile, row: Int, col: Int) -> SKColor? {
        switch tile {
        case .dirt:
            let isCapped = engine.tile(row - 1, col) != .dirt && engine.tile(row - 1, col) != .steel
            return isCapped
                ? SKColor(red: 0.36, green: 0.58, blue: 0.22, alpha: 1)
                : SKColor(red: 0.62, green: 0.34, blue: 0.05, alpha: 1)
        case .steel: return SKColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 1)
        case .trap: return SKColor(red: 0.75, green: 0.1, blue: 0.05, alpha: 1)
        case .exit: return SKColor(red: 1.0, green: 0.85, blue: 0.05, alpha: 1)
        case .entrance: return SKColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1)
        case .empty: return nil
        }
    }

    /// Only touches the cells that actually changed since last frame —
    /// digging/bashing/mining edit one or two tiles per tick, so rebuilding
    /// the entire grid's shape nodes every time was wasted work that caused
    /// visible stutter on every dig.
    private func updateTerrain() {
        // Cells whose tile actually changed, plus the cell directly below
        // each of them (removing dirt can turn the tile below into a
        // grass-capped one — see `fillColor(for:row:col:)`).
        var cellsToRefresh = Set<Int>()
        for r in 0..<engine.height {
            for c in 0..<engine.width where engine.tile(r, c) != lastGrid[r][c] {
                cellsToRefresh.insert(r * engine.width + c)
                if r + 1 < engine.height { cellsToRefresh.insert((r + 1) * engine.width + c) }
            }
        }

        for key in cellsToRefresh {
            let r = key / engine.width
            let c = key % engine.width
            let tile = engine.tile(r, c)

            guard let color = fillColor(for: tile, row: r, col: c) else {
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
                if tile == .exit {
                    node.run(.repeatForever(.sequence([
                        .scale(to: 1.15, duration: 0.5), .scale(to: 1.0, duration: 0.5),
                    ])))
                }
                terrainNode.addChild(node)
                terrainNodes[key] = node
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

    // MARK: - Input: tap assigns a skill, drag pans the camera

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        dragStart = t.location(in: self)
        didDrag = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let start = dragStart else { return }
        let location = t.location(in: self)
        let delta = start.x - location.x
        if abs(delta) > 2 {
            didDrag = true
            pan(bySceneDelta: delta)
            dragStart = location
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        if !didDrag { handleTap(at: t.location(in: self)) }
        dragStart = nil
    }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) {
        dragStart = event.location(in: self)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let location = event.location(in: self)
        let delta = start.x - location.x
        if abs(delta) > 2 {
            didDrag = true
            pan(bySceneDelta: delta)
            dragStart = location
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag { handleTap(at: event.location(in: self)) }
        dragStart = nil
    }

    override func scrollWheel(with event: NSEvent) {
        pan(bySceneDelta: -event.scrollingDeltaX)
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
