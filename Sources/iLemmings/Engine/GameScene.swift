import SpriteKit

final class GameScene: SKScene {
    let engine: GameEngine
    let tileSize: CGFloat = 28
    private let minZoom: CGFloat = 0.15
    private let maxZoom: CGFloat = 8.0

    // Members below without `private` are the ones the `GameSceneInput` and
    // `GameSceneTerrain` extensions reach for: Swift's `private` is
    // file-scoped, so splitting the class across files makes them internal
    // by necessity, not by design.
    var terrainNode = SKNode()
    /// One optional node per cell, keyed by `row * width + col`. Updated
    /// incrementally (see `updateTerrain()`) instead of rebuilding the whole
    /// grid every time a single tile changes — digging used to rebuild
    /// hundreds of `SKShapeNode`s on every tick, causing visible stutter.
    var terrainNodes: [Int: SKSpriteNode] = [:]
    var lastGrid: [[Tile]] = []
    private var lemmingNodes: [Int: SKSpriteNode] = [:]
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0
    var isEnginePaused = false
    private var previousStates: [Int: LemState] = [:]
    private var tickCounter = 0

    let gameCamera = SKCameraNode()
    var worldWidth: CGFloat { CGFloat(engine.width) * tileSize }
    var worldHeight: CGFloat { CGFloat(engine.height) * tileSize }
    var dragStart: CGPoint?
    var didDrag = false

    var onLemmingTapped: ((Int) -> Void)?
    var onExplosion: (() -> Void)?
    var onSplat: (() -> Void)?
    var onDrown: (() -> Void)?
    var onTogglePause: (() -> Void)?
    /// Which columns of the level are on screen, so the minimap can draw the
    /// viewport box the original has.
    var onViewportChanged: ((ClosedRange<Double>) -> Void)?
    private var lastReportedViewport: ClosedRange<Double>?
    var lastPointer: CGPoint?
    /// The original's cursor is a hollow box that snaps around the lemming
    /// under the pointer — the thing that tells you *which* one is about to
    /// get the skill. A small circle floating near it never did that job.
    var hoverRing = SKShapeNode()

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
        let box = tileSize * 0.9
        hoverRing.path = CGPath(rect: CGRect(x: -box / 2, y: 0, width: box, height: box), transform: nil)
        hoverRing.strokeColor = SKColor(red: 1, green: 0.95, blue: 0.35, alpha: 1)
        hoverRing.fillColor = .clear
        hoverRing.lineWidth = max(1, tileSize * 0.05)
        hoverRing.isAntialiased = false
        hoverRing.zPosition = 12
        hoverRing.isHidden = true
        addChild(hoverRing)
        let startX = CGFloat(engine.entranceColumn) * tileSize
        gameCamera.position = CGPoint(x: clampedCameraX(startX), y: worldHeight / 2)
        resizeViewport(to: view.bounds.size)
        #if os(macOS)
        view.window?.acceptsMouseMovedEvents = true
        // Claim the keyboard up front. Clicking the playfield to assign a
        // skill makes this view first responder anyway, so keyboard handling
        // has to live here (see `handleKey`) rather than on a SwiftUI
        // `.focusable()` wrapper that loses focus to it on the first click.
        view.window?.makeFirstResponder(view)
        #endif
    }

    func setEnginePaused(_ paused: Bool) { isEnginePaused = paused }

    /// Fill the SpriteView with the full level height (classic side-scroll).
    /// Lemmings stay a fraction of a tile, so stretching the map to the
    /// window no longer turns them into toolbar-sized giants.
    func resizeViewport(to newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        size = newSize
        let fitHeightScale = worldHeight / newSize.height
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
        guard !isEnginePaused else { return }
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
        syncLemmingNodes(didTick: ticked)
        edgeScroll()
        updateHover()
        reportViewport()
    }

    /// Fires only when the visible span actually moves, rather than on every
    /// frame: this drives SwiftUI state, and a 60-per-second publish would
    /// re-render the whole control panel for nothing.
    private func reportViewport() {
        let half = Double(size.width * gameCamera.xScale / 2)
        let centre = Double(gameCamera.position.x / tileSize)
        let spread = half / Double(tileSize)
        let range = (centre - spread)...(centre + spread)
        if let last = lastReportedViewport,
           abs(last.lowerBound - range.lowerBound) < 0.25,
           abs(last.upperBound - range.upperBound) < 0.25 {
            return
        }
        lastReportedViewport = range
        onViewportChanged?(range)
    }

    /// `didTick` says whether the engine actually advanced this frame. The
    /// move action is only (re)started on a tick: SpriteKit evaluates actions
    /// *after* `update(_:)`, so re-running a keyed move every frame replaced
    /// the action before it was ever evaluated and the lemmings never left
    /// their spawn position — they all sat at the scene origin while the
    /// simulation (and the minimap) ran on without them.
    private func syncLemmingNodes(didTick: Bool) {
        var seen = Set<Int>()
        for lem in engine.lemmings {
            seen.insert(lem.id)
            let existing = lemmingNodes[lem.id]
            let node = existing ?? makeLemmingNode(for: lem)
            lemmingNodes[lem.id] = node

            let target = CGPoint(x: CGFloat(lem.x) * tileSize + tileSize / 2, y: flipRow(lem.y))
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
        // Terrain tiles are the map unit. Classic lemmings are much smaller
        // than a block (about half a tile wide, under one tile tall). The art
        // canvas is square with a margin for the umbrella/pickaxe/brick, so
        // the node is square too and the *body* inside it lands on those
        // proportions.
        node.size = CGSize(width: tileSize * 0.84, height: tileSize * 0.84)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.name = "lem-\(lem.id)"
        node.zPosition = 10

        let countLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        countLabel.name = "countdown"
        countLabel.fontSize = 8
        countLabel.fontColor = SKColor(red: 0.35, green: 0.95, blue: 0.35, alpha: 1)
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: 0, y: node.size.height + 3)
        countLabel.zPosition = 2
        node.addChild(countLabel)

        return node
    }

    /// Picks the animation for the lemming's current job. Nothing here
    /// recolours the sprite — the green hair / blue overalls silhouette must
    /// always read as a lemming, and the job is told by what it is *doing*.
    private func updateAppearance(_ node: SKSpriteNode, for lem: Lemming) {
        let countLabel = node.childNode(withName: "countdown") as? SKLabelNode
        if let digit = lem.countdownDigit {
            countLabel?.text = "\(digit)"
            countLabel?.isHidden = false
        } else {
            countLabel?.text = ""
            countLabel?.isHidden = true
        }

        let (name, animation): (String, SKAction?)
        switch lem.state {
        case .walking:   (name, animation) = ("walk", LemmingSprites.walk)
        case .falling:   (name, animation) = ("fall", LemmingSprites.fall)
        case .floating:  (name, animation) = ("float", LemmingSprites.float)
        case .climbing:  (name, animation) = ("climb", LemmingSprites.climb)
        case .digger:    (name, animation) = ("dig", LemmingSprites.dig)
        case .basher:    (name, animation) = ("bash", LemmingSprites.bash)
        case .miner:     (name, animation) = ("mine", LemmingSprites.mine)
        case .building:  (name, animation) = ("build", LemmingSprites.build)
        case .blocking:  (name, animation) = ("block", LemmingSprites.block)
        case .shrugging: (name, animation) = ("shrug", LemmingSprites.shrug)
        case .ohNo:      (name, animation) = ("ohno", LemmingSprites.ohNo)
        case .drowning:  (name, animation) = ("drown", LemmingSprites.drown)
        case .splatting: (name, animation) = ("splat", nil)
        case .saved, .dead: (name, animation) = ("stand", nil)
        }

        // Keyed by *name*, not by comparing `LemState`: several states carry
        // a countdown in their associated value and so compare unequal on
        // every tick, which would restart the cycle from frame one forever
        // and leave every working lemming frozen on its first frame.
        guard node.userData?["anim"] as? String != name else { return }
        if node.userData == nil { node.userData = NSMutableDictionary() }
        node.userData?["anim"] = name

        node.removeAction(forKey: "anim")
        if let animation {
            node.run(animation, withKey: "anim")
        } else {
            node.texture = (name == "splat") ? LemmingSprites.splat : LemmingSprites.stand
        }
    }
}
