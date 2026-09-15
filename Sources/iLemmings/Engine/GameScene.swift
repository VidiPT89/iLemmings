import SpriteKit

/// Deterministic RNG so the procedural terrain textures look the same on
/// every launch instead of re-rolling their speckle pattern each time.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

final class GameScene: SKScene {
    /// Shared with SwiftUI so the playfield height and camera cap stay in sync.
    static let tileOnScreen: CGFloat = 28

    let engine: GameEngine
    private let tileSize: CGFloat = GameScene.tileOnScreen
    private let maxTileOnScreen: CGFloat = GameScene.tileOnScreen
    private let minZoom: CGFloat = 0.15
    private let maxZoom: CGFloat = 8.0

    private var terrainNode = SKNode()
    /// One optional node per cell, keyed by `row * width + col`. Updated
    /// incrementally (see `updateTerrain()`) instead of rebuilding the whole
    /// grid every time a single tile changes — digging used to rebuild
    /// hundreds of `SKShapeNode`s on every tick, causing visible stutter.
    private var terrainNodes: [Int: SKSpriteNode] = [:]
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
    var onExplosion: (() -> Void)?
    var onSplat: (() -> Void)?
    var onDrown: (() -> Void)?
    private var lastPointer: CGPoint?
    private var hoverRing = SKShapeNode(circleOfRadius: 7)

    init(engine: GameEngine) {
        self.engine = engine
        super.init(size: CGSize(width: 320, height: 160))
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
        addChild(makeBackground())
        addChild(terrainNode)
        lastGrid = Array(repeating: Array(repeating: Tile.empty, count: engine.width), count: engine.height)
        updateTerrain()
        addChild(makeEntranceHatch())
        for (r, row) in engine.grid.enumerated() {
            for (c, tile) in row.enumerated() where tile == .exit {
                addChild(makeExitHouse(row: r, col: c))
            }
        }

        camera = gameCamera
        addChild(gameCamera)
        hoverRing.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.9)
        hoverRing.fillColor = .clear
        hoverRing.lineWidth = 1.5
        hoverRing.zPosition = 12
        hoverRing.isHidden = true
        addChild(hoverRing)
        let startX = CGFloat(engine.entranceColumn) * tileSize
        gameCamera.position = CGPoint(x: clampedCameraX(startX), y: worldHeight / 2)
        resizeViewport(to: view.bounds.size)
        #if os(macOS)
        view.window?.acceptsMouseMovedEvents = true
        #endif
    }

    func setEnginePaused(_ paused: Bool) { paused_ = paused }

    /// Called by the SwiftUI container whenever the actual on-screen size
    /// changes. Camera scale is inverted: larger scale shows more world
    /// (smaller sprites). Always show the full level height; never zoom in
    /// past `maxTileOnScreen`, so a tall window does not inflate the lemmings.
    func resizeViewport(to newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        size = newSize
        let fitHeightScale = worldHeight / newSize.height
        let capZoomIn = tileSize / maxTileOnScreen
        let scale = max(fitHeightScale, capZoomIn)
        gameCamera.setScale(min(max(scale, minZoom), maxZoom))
        gameCamera.position.y = worldHeight / 2
        gameCamera.position.x = clampedCameraX(gameCamera.position.x)
    }

    // MARK: - Camera: horizontal scroll only
    //
    // The original has a fixed-scale viewport and scrolls only horizontally
    // (edge-scroll) — there is no pinch/zoom in DOS/Amiga Lemmings. Zoom
    // here is set once per resize to fit the level's height and is not
    // user-adjustable.

    private func clampedCameraX(_ x: CGFloat) -> CGFloat {
        let halfViewport = size.width * gameCamera.xScale / 2
        guard worldWidth > halfViewport * 2 else { return worldWidth / 2 }
        return min(max(x, halfViewport), worldWidth - halfViewport)
    }

    func pan(bySceneDelta delta: CGFloat) {
        gameCamera.position.x = clampedCameraX(gameCamera.position.x + delta)
    }

    // MARK: - Background & terrain
    //
    // The original DOS Lemmings renders each level against a flat, dark
    // backdrop with grainy, dithered terrain sprites — not a cheerful blue
    // sky and flat-color blocks. This tries to get closer to that: a solid
    // dark background per level pack, and speckled/noisy tile textures
    // instead of flat fills.

    private func makeBackground() -> SKSpriteNode {
        let color: SKColor
        switch engine.level.pack {
        case .fun: color = SKColor(red: 0.05, green: 0.08, blue: 0.10, alpha: 1)
        case .tricky: color = SKColor(red: 0.09, green: 0.06, blue: 0.10, alpha: 1)
        case .taxing: color = SKColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        case .mayhem: color = SKColor(red: 0.10, green: 0.03, blue: 0.03, alpha: 1)
        }
        let bg = SKSpriteNode(color: color, size: CGSize(width: worldWidth, height: worldHeight))
        bg.position = CGPoint(x: worldWidth / 2, y: worldHeight / 2)
        bg.zPosition = -10
        return bg
    }

    private func flipRow(_ row: Int) -> CGFloat {
        CGFloat(engine.height - 1 - row) * tileSize
    }

    private func isTerrainSolid(_ tile: Tile) -> Bool {
        tile == .dirt || tile == .steel
    }

    /// The classic hatch: a distinct metal doorway lemmings visibly walk out
    /// of, not just a same-as-terrain speckled tile. Previously the entrance
    /// tile used the same near-black speckle texture as the background,
    /// so it was effectively invisible — lemmings appeared to spawn out of
    /// nowhere. Built once (the entrance never moves), not through the
    /// per-tick terrain diffing used for destructible tiles.
    private func makeEntranceHatch() -> SKNode {
        let node = SKNode()
        node.zPosition = 5
        node.position = CGPoint(
            x: CGFloat(engine.entranceColumn) * tileSize + tileSize / 2,
            y: flipRow(engine.entranceRow) + tileSize / 2
        )

        let frameSize = CGSize(width: tileSize * 1.6, height: tileSize * 1.6)
        let frame = SKShapeNode(rectOf: frameSize, cornerRadius: 3)
        frame.fillColor = SKColor(red: 0.30, green: 0.32, blue: 0.36, alpha: 1)
        frame.strokeColor = SKColor(red: 0.62, green: 0.66, blue: 0.70, alpha: 1)
        frame.lineWidth = 2
        frame.position = CGPoint(x: 0, y: tileSize * 0.15)
        node.addChild(frame)

        let opening = SKShapeNode(rectOf: CGSize(width: tileSize * 1.1, height: tileSize * 1.0))
        opening.fillColor = .black
        opening.strokeColor = .clear
        opening.position = CGPoint(x: 0, y: tileSize * 0.05)
        frame.addChild(opening)

        let light = SKShapeNode(circleOfRadius: 2.5)
        light.fillColor = .systemGreen
        light.strokeColor = .clear
        light.position = CGPoint(x: 0, y: frameSize.height / 2 - 5)
        light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        frame.addChild(light)

        return node
    }

    private func makeExitHouse(row: Int, col: Int) -> SKNode {
        let node = SKNode()
        node.zPosition = 4
        node.position = CGPoint(
            x: CGFloat(col) * tileSize + tileSize / 2,
            y: flipRow(row) + tileSize / 2
        )
        let arch = SKShapeNode(rectOf: CGSize(width: tileSize * 1.8, height: tileSize * 2.1), cornerRadius: 4)
        arch.fillColor = SKColor(red: 0.55, green: 0.18, blue: 0.12, alpha: 1)
        arch.strokeColor = SKColor(red: 0.85, green: 0.65, blue: 0.20, alpha: 1)
        arch.lineWidth = 2
        arch.position = CGPoint(x: 0, y: tileSize * 0.4)
        node.addChild(arch)
        let door = SKShapeNode(rectOf: CGSize(width: tileSize * 0.9, height: tileSize * 1.15), cornerRadius: 2)
        door.fillColor = SKColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 1)
        door.strokeColor = .clear
        door.position = CGPoint(x: 0, y: tileSize * 0.05)
        arch.addChild(door)
        let glow = SKShapeNode(circleOfRadius: 3)
        glow.fillColor = SKColor(red: 1, green: 0.82, blue: 0.25, alpha: 1)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: tileSize * 0.85)
        glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        arch.addChild(glow)
        return node
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
                for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                    let nr = r + dr, nc = c + dc
                    if nr >= 0, nr < engine.height, nc >= 0, nc < engine.width {
                        cellsToRefresh.insert(nr * engine.width + nc)
                    }
                }
            }
        }

        for key in cellsToRefresh {
            let r = key / engine.width
            let c = key % engine.width
            let tile = engine.tile(r, c)

            guard let terrainStyle = TerrainRenderer.style(for: tile, above: engine.tile(r - 1, c)) else {
                terrainNodes[key]?.removeFromParent()
                terrainNodes.removeValue(forKey: key)
                continue
            }

            let texture = TerrainRenderer.texture(
                style: terrainStyle,
                solidN: isTerrainSolid(engine.tile(r - 1, c)),
                solidE: isTerrainSolid(engine.tile(r, c + 1)),
                solidS: isTerrainSolid(engine.tile(r + 1, c)),
                solidW: isTerrainSolid(engine.tile(r, c - 1)),
                seed: r * 97 + c * 13 + terrainStyle.hashValue
            )

            if let existing = terrainNodes[key] {
                existing.texture = texture
            } else {
                let node = SKSpriteNode(texture: texture, size: CGSize(width: tileSize, height: tileSize))
                node.position = CGPoint(x: CGFloat(c) * tileSize + tileSize / 2, y: flipRow(r) + tileSize / 2)
                terrainNode.addChild(node)
                terrainNodes[key] = node
            }
        }
        lastGrid = engine.grid
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        // Clamp dt: after any stall (app backgrounded, a dropped-frame hitch,
        // the pause sheet, a slow device), SpriteKit's next `update(_:)` can
        // arrive with `currentTime` far ahead of `lastUpdateTime`. Without
        // this cap, the accumulator below would replay all the missed ticks
        // in one burst — a level's entire spawn queue and countdown timer
        // fast-forwarding in a fraction of a second, which is exactly what
        // made a level look broken/nonsensical after any real-world hitch.
        let dt = min(currentTime - lastUpdateTime, 0.25)
        lastUpdateTime = currentTime
        guard !paused_ else { return }
        accumulator += dt
        let step = 1.0 / engine.ticksPerSecond
        var ticked = false
        while accumulator >= step {
            for _ in 0..<max(1, engine.gameSpeed) {
                engine.tick()
                tickCounter += 1
            }
            ticked = true
            accumulator -= step
        }
        if ticked { updateTerrain() }
        syncLemmingNodes()
        edgeScroll()
        updateHover()
    }

    private func syncLemmingNodes() {
        var seen = Set<Int>()
        for lem in engine.lemmings {
            seen.insert(lem.id)
            let node = lemmingNodes[lem.id] ?? makeLemmingNode(for: lem)
            lemmingNodes[lem.id] = node
            if node.parent == nil { addChild(node) }

            let target = CGPoint(x: CGFloat(lem.x) * tileSize + tileSize / 2, y: flipRow(lem.y))
            let moveDuration = 1.0 / (engine.ticksPerSecond * Double(max(1, engine.gameSpeed)))
            node.run(.move(to: target, duration: moveDuration))
            node.isHidden = (lem.state == .dead)
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
        let previous = previousStates[lem.id] ?? lem.state
        let wasOhNo: Bool
        if case .ohNo = previous { wasOhNo = true } else { wasOhNo = false }
        let wasSplat: Bool
        if case .splatting = previous { wasSplat = true } else { wasSplat = false }

        let wasDrown: Bool
        if case .drowning = previous { wasDrown = true } else { wasDrown = false }

        switch lem.state {
        case .basher, .miner, .digger:
            if tickCounter % 4 == 0 { addParticles(kind: .dust, at: position) }
        case .splatting:
            if !wasSplat {
                addParticles(kind: .dust, at: position)
                onSplat?()
            }
        case .drowning:
            if !wasDrown { onDrown?() }
        case .dead:
            if wasOhNo {
                addParticles(kind: .explosion, at: position)
                onExplosion?()
            }
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
        node.size = CGSize(width: tileSize * 1.0, height: tileSize * 1.6)
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

        let countLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        countLabel.name = "countdown"
        countLabel.fontSize = 10
        countLabel.fontColor = SKColor(red: 0.35, green: 0.95, blue: 0.35, alpha: 1)
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: 0, y: node.size.height + 8)
        countLabel.zPosition = 2
        node.addChild(countLabel)

        return node
    }

    /// Picks the right pixel-art frame/animation and skill badge for the
    /// lemming's current state, without recoloring the sprite itself — the
    /// green hair / blue overalls silhouette must always read as a lemming.
    private func updateAppearance(_ node: SKSpriteNode, for lem: Lemming) {
        let badge = node.childNode(withName: "badge") as? SKShapeNode
        badge?.isHidden = true
        node.yScale = 1
        let countLabel = node.childNode(withName: "countdown") as? SKLabelNode
        if let digit = lem.countdownDigit {
            countLabel?.text = "\(digit)"
            countLabel?.isHidden = false
        } else {
            countLabel?.text = ""
            countLabel?.isHidden = true
        }

        switch lem.state {
        case .walking:
            if node.action(forKey: "walk") == nil {
                node.run(.repeatForever(LemmingSprites.walkAnimation), withKey: "walk")
            }
            if lem.hasClimber || lem.hasFloater {
                badge?.isHidden = false
                badge?.fillColor = lem.hasClimber ? .systemGreen : .cyan
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

        case .shrugging:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
            badge?.isHidden = false
            badge?.fillColor = .systemYellow

        case .splatting:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
            node.yScale = 0.4

        case .drowning:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
            node.yScale = 0.55
            badge?.isHidden = false
            badge?.fillColor = .cyan

        case .ohNo:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.stand
            badge?.isHidden = false
            badge?.fillColor = .systemPink

        case .floating:
            node.removeAction(forKey: "walk")
            node.texture = LemmingSprites.float

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
        lastPointer = dragStart
        didDrag = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let start = dragStart else { return }
        let location = t.location(in: self)
        lastPointer = location
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
        lastPointer = dragStart
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let location = event.location(in: self)
        lastPointer = location
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

    override func mouseMoved(with event: NSEvent) {
        lastPointer = event.location(in: self)
    }

    override func scrollWheel(with event: NSEvent) {
        pan(bySceneDelta: -event.scrollingDeltaX)
    }
    #endif

    private func handleTap(at point: CGPoint) {
        if let id = nearestLiving(to: point) {
            onLemmingTapped?(id)
        }
    }

    private func nearestLiving(to point: CGPoint) -> Int? {
        let radius = tileSize * 1.6
        var best: (Int, CGFloat)?
        for lem in engine.lemmings where lem.canReceiveSkill {
            let p = CGPoint(x: CGFloat(lem.x) * tileSize + tileSize / 2, y: flipRow(lem.y) + tileSize * 0.4)
            let d = hypot(p.x - point.x, p.y - point.y)
            if d <= radius, best == nil || d < best!.1 {
                best = (lem.id, d)
            }
        }
        return best?.0
    }

    private func edgeScroll() {
        guard !paused_, let p = lastPointer else { return }
        let half = size.width * gameCamera.xScale / 2
        let left = gameCamera.position.x - half
        let right = gameCamera.position.x + half
        let band = tileSize * 1.4
        if p.x < left + band {
            pan(bySceneDelta: -2.4)
        } else if p.x > right - band {
            pan(bySceneDelta: 2.4)
        }
    }

    private func updateHover() {
        guard let p = lastPointer, let id = nearestLiving(to: p),
              let lem = engine.lemmings.first(where: { $0.id == id }) else {
            hoverRing.isHidden = true
            return
        }
        hoverRing.isHidden = false
        hoverRing.position = CGPoint(x: CGFloat(lem.x) * tileSize + tileSize / 2, y: flipRow(lem.y) + tileSize * 0.7)
    }
}
