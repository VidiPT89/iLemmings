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
    /// Fitting the level height exactly makes on-screen tile size just
    /// `screenHeight / level.height`, with zero margin — on a tall window
    /// this made every tile (and the lemming sprites, sized relative to it)
    /// render huge, since nothing else scales it down. The original ran at
    /// 320x200 with roughly 8px lemmings — tiny relative to the screen, with
    /// a wide margin of visible terrain above/below the play area. 1.35 was
    /// a first pass and still read as oversized; this shows noticeably more
    /// sky/ground margin, shrinking tiles and lemmings by the same ratio to
    /// land much closer to how small the original actually was.
    private let heightFitPadding: CGFloat = 2.2

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

    init(engine: GameEngine) {
        self.engine = engine
        let viewportWidth = min(CGFloat(engine.width), visibleTilesWide) * tileSize
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
        addChild(makeBackground())
        addChild(terrainNode)
        lastGrid = Array(repeating: Array(repeating: Tile.empty, count: engine.width), count: engine.height)
        updateTerrain()
        addChild(makeEntranceHatch())

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
        let fitHeightScale = worldHeight * heightFitPadding / newSize.height
        gameCamera.setScale(min(max(fitHeightScale, minZoom), maxZoom))
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

    private enum TerrainStyle: Hashable { case dirt, grassCap, steel, trap, exit }

    /// Dirt capped by open air gets a grassy highlight, like the classic
    /// hand-drawn hills — otherwise every level reads as flat brown blocks.
    private func style(for tile: Tile, row: Int, col: Int) -> TerrainStyle? {
        switch tile {
        case .dirt:
            let isCapped = engine.tile(row - 1, col) != .dirt && engine.tile(row - 1, col) != .steel
            return isCapped ? .grassCap : .dirt
        case .steel: return .steel
        case .trap: return .trap
        case .exit: return .exit
        case .entrance: return nil // drawn as a dedicated hatch structure, see makeEntranceHatch()
        case .empty: return nil
        }
    }

    /// A small speckled/dithered tile, generated once per style and reused —
    /// gives the terrain a grainy, hand-pixelled feel instead of flat fills.
    private static func speckleTexture(base: (CGFloat, CGFloat, CGFloat), variance: CGFloat, seed: Int) -> SKTexture {
        let size = 16
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        var rng = SeededGenerator(seed: seed)
        for y in 0..<size {
            for x in 0..<size {
                let n = CGFloat.random(in: -variance...variance, using: &rng)
                let r = min(max(base.0 + n, 0), 1)
                let g = min(max(base.1 + n, 0), 1)
                let b = min(max(base.2 + n, 0), 1)
                ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        guard let image = ctx.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static let terrainTextures: [TerrainStyle: SKTexture] = [
        .dirt: speckleTexture(base: (0.42, 0.24, 0.06), variance: 0.05, seed: 1),
        .grassCap: speckleTexture(base: (0.28, 0.46, 0.16), variance: 0.05, seed: 2),
        .steel: speckleTexture(base: (0.30, 0.30, 0.32), variance: 0.04, seed: 3),
        .trap: speckleTexture(base: (0.55, 0.07, 0.05), variance: 0.06, seed: 4),
        .exit: speckleTexture(base: (0.70, 0.55, 0.10), variance: 0.05, seed: 5),
    ]

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

            guard let terrainStyle = style(for: tile, row: r, col: c),
                  let texture = Self.terrainTextures[terrainStyle] else {
                terrainNodes[key]?.removeFromParent()
                terrainNodes.removeValue(forKey: key)
                continue
            }

            if let existing = terrainNodes[key] {
                existing.texture = texture
            } else {
                let node = SKSpriteNode(texture: texture, size: CGSize(width: tileSize, height: tileSize))
                node.position = CGPoint(x: CGFloat(c) * tileSize + tileSize / 2, y: flipRow(r) + tileSize / 2)
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
            if wasExploding {
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
    /// blond hair / blue overalls silhouette must always read as a lemming.
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
