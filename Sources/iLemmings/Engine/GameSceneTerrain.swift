import SpriteKit

/// Building the world the lemmings run around in: the backdrop, the two
/// structures, and the destructible tiles.
///
/// Split out of `GameScene` so that file is about running the simulation
/// and this one is about drawing the level it runs on.
extension GameScene {

    // MARK: - Background & terrain
    //
    // The original DOS Lemmings renders each level against a flat, dark
    // backdrop with grainy, dithered terrain sprites — not a cheerful blue
    // sky and flat-color blocks. This tries to get closer to that: a solid
    // dark background per level pack, and speckled/noisy tile textures
    // instead of flat fills.

    func makeBackground() -> SKSpriteNode {
        let color: SKColor
        switch engine.level.pack {
        case .fun: color = SKColor(red: 0.05, green: 0.08, blue: 0.10, alpha: 1)
        case .tricky: color = SKColor(red: 0.09, green: 0.06, blue: 0.10, alpha: 1)
        case .taxing: color = SKColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        case .mayhem: color = SKColor(red: 0.10, green: 0.03, blue: 0.03, alpha: 1)
        }
        let bg = SKSpriteNode(color: color, size: CGSize(width: 20_000, height: 20_000))
        bg.position = CGPoint(x: worldWidth / 2, y: worldHeight / 2)
        bg.zPosition = -10
        return bg
    }

    func flipRow(_ row: Int) -> CGFloat {
        CGFloat(engine.height - 1 - row) * tileSize
    }

    /// The classic hatch: a distinct metal doorway lemmings visibly walk out
    /// of, not just a same-as-terrain speckled tile. Previously the entrance
    /// tile used the same near-black speckle texture as the background,
    /// so it was effectively invisible — lemmings appeared to spawn out of
    /// nowhere. Built once (neither structure ever moves), not through the
    /// per-tick terrain diffing used for destructible tiles.
    func makeEntranceHatch() -> SKNode {
        let height = tileSize * 1.5
        let node = SKSpriteNode(
            texture: StructureSprites.hatchClosed,
            size: CGSize(width: height * StructureSprites.hatchAspect, height: height)
        )
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.zPosition = 5
        node.position = CGPoint(
            x: CGFloat(engine.entranceColumn) * tileSize + tileSize / 2,
            y: flipRow(engine.entranceRow)
        )
        // The shutters come up a beat after the level starts, like the
        // original's opening — the first lemming drops through the gap.
        node.run(.sequence([
            .wait(forDuration: 0.8),
            .setTexture(StructureSprites.hatchOpen)
        ]))
        return node
    }

    func makeExitHouse(row: Int, col: Int) -> SKNode {
        let height = tileSize * 2.0
        let node = SKSpriteNode(
            texture: StructureSprites.exitLit,
            size: CGSize(width: height * StructureSprites.exitAspect, height: height)
        )
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.zPosition = 4
        node.position = CGPoint(x: CGFloat(col) * tileSize + tileSize / 2, y: flipRow(row))
        node.run(.repeatForever(.animate(
            with: [StructureSprites.exitLit, StructureSprites.exitDim],
            timePerFrame: 0.4
        )))
        return node
    }

    /// Only touches the cells that actually changed since last frame —
    /// digging/bashing/mining edit one or two tiles per tick, so rebuilding
    /// the entire grid's shape nodes every time was wasted work that caused
    /// visible stutter on every dig.
    func updateTerrain() {
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

            let neighbours = TerrainRenderer.Neighbours(
                n: engine.tile(r - 1, c),
                e: engine.tile(r, c + 1),
                s: engine.tile(r + 1, c),
                w: engine.tile(r, c - 1)
            )
            let phases = terrainStyle == .water ? TerrainRenderer.waterPhaseCount : 1
            let frames = (0..<phases).map { phase in
                TerrainRenderer.texture(
                    style: terrainStyle,
                    tile: tile,
                    neighbours: neighbours,
                    row: r,
                    col: c,
                    phase: phase
                )
            }

            let node: SKSpriteNode
            if let existing = terrainNodes[key] {
                existing.texture = frames[0]
                node = existing
            } else {
                node = SKSpriteNode(texture: frames[0], size: CGSize(width: tileSize, height: tileSize))
                node.position = CGPoint(x: CGFloat(c) * tileSize + tileSize / 2, y: flipRow(r) + tileSize / 2)
                terrainNode.addChild(node)
                terrainNodes[key] = node
            }

            // A still pond reads as a blue wall; the crest drifting sideways
            // is what makes it obviously water you can drown in.
            node.removeAction(forKey: "wave")
            if frames.count > 1 {
                node.run(.repeatForever(.animate(with: frames, timePerFrame: 0.28)), withKey: "wave")
            }
        }
        lastGrid = engine.grid
    }
}
