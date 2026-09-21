import SpriteKit

/// Neighbor-aware tiles so the playfield reads as a cave, not a chessboard.
/// Physics stay on the grid; only the pixels of each cell change.
///
/// Each material is drawn with its own pattern rather than one shared noise
/// function: the original's tilesets are dithered two-tone dirt, riveted
/// steel plates, grass tufts and banded water, and a single speckle applied
/// to every tile is what made this playfield read as flat coloured blocks.
enum TerrainRenderer {

    enum Style: Hashable { case dirt, grassCap, steel, trap, water }

    /// The four tiles around the one being drawn. Passing the tiles rather
    /// than booleans lets each material ask its own question: dirt wants to
    /// know what is *solid* next to it, while steel and water want to know
    /// what is *the same material* — a plate spanning six cells should read
    /// as one plate, and only the top row of a pond has a surface.
    struct Neighbours {
        let n: Tile, e: Tile, s: Tile, w: Tile
    }

    /// Chunky on purpose: the original's tiles are low-resolution bitmaps,
    /// and a smooth high-resolution tile here looks modern, not 1991.
    private static let size = 24

    /// Water is drawn as a few phases of the same tile so the surface can be
    /// animated; everything else only ever uses phase 0.
    static let waterPhaseCount = 3

    static func style(for tile: Tile, above: Tile) -> Style? {
        switch tile {
        case .dirt:
            // Grass only grows where there is air above. Capping whatever
            // was not dirt or steel meant the bed of a pond sprouted a green
            // fringe underwater, and so did the floor under a spike pit.
            switch above {
            case .empty, .entrance, .exit: return .grassCap
            case .dirt, .steel, .water, .trap: return .dirt
            }
        case .steel: return .steel
        case .trap: return .trap
        case .water: return .water
        case .exit, .entrance, .empty: return nil
        }
    }

    static func texture(
        style: Style,
        tile: Tile,
        neighbours: Neighbours,
        row: Int,
        col: Int,
        phase: Int = 0
    ) -> SKTexture {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }

        var rng = SeededGenerator(seed: row * 97 + col * 13 + style.hashValue)
        // Per-column fringe heights, fixed per tile, so a grass ledge has an
        // uneven silhouette against the sky instead of a ruled green line.
        let fringe = (0..<size).map { _ in Int.random(in: 0...3, using: &rng) }
        let solid = Edges(
            n: isSolid(neighbours.n), e: isSolid(neighbours.e),
            s: isSolid(neighbours.s), w: isSolid(neighbours.w)
        )
        let same = Edges(
            n: neighbours.n == tile, e: neighbours.e == tile,
            s: neighbours.s == tile, w: neighbours.w == tile
        )

        // Dirt crumbles away from whatever is *solid* beside it. Steel,
        // water and spikes butt up against their own kind, so a plate, a
        // pond or a spike pit is one shape rather than a row of tiles with
        // dark seams between them.
        let squaredOff = (style == .steel || style == .water || style == .trap)
        let edges = squaredOff ? same : solid

        for y in 0..<size {
            for x in 0..<size {
                guard isFilled(x: x, y: y, solid: edges, steel: squaredOff) else { continue }
                guard let color = pixel(
                    style: style, x: x, y: y, fringe: fringe, same: same,
                    row: row, col: col, phase: phase, rng: &rng
                ) else { continue }
                ctx.setFillColor(color)
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        guard let image = ctx.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private struct Edges {
        let n: Bool, e: Bool, s: Bool, w: Bool
    }

    private static func isSolid(_ tile: Tile) -> Bool {
        tile == .dirt || tile == .steel
    }

    // MARK: - Per-material pixels
    //
    // `y = 0` is the bottom of the CGContext, so "the top of the tile" is
    // the high end of the range.

    private static func pixel(
        style: Style, x: Int, y: Int, fringe: [Int], same: Edges,
        row: Int, col: Int, phase: Int, rng: inout SeededGenerator
    ) -> CGColor? {
        switch style {
        case .dirt:
            return dirtPixel(x: x, y: y, rng: &rng)

        case .grassCap:
            return grassPixel(x: x, y: y, fringe: fringe[x], rng: &rng)

        case .steel:
            return steelPixel(x: x, y: y, same: same, row: row, col: col)

        case .trap:
            return trapPixel(x: x, y: y)

        case .water:
            return waterPixel(x: x, y: y, hasSurface: !same.n, phase: phase, rng: &rng)
        }
    }

    /// Two-tone dither with scattered pebbles — the original's dirt is a
    /// dithered texture, not a flat fill with noise on top.
    private static func dirtPixel(x: Int, y: Int, rng: inout SeededGenerator) -> CGColor {
        let roll = Int.random(in: 0..<100, using: &rng)
        if roll < 7 { return rgb(0.28, 0.16, 0.04) }   // pebble shadow
        if roll < 13 { return rgb(0.58, 0.38, 0.15) }  // pebble highlight
        return (x + y).isMultiple(of: 2)
            ? rgb(0.47, 0.28, 0.08)
            : rgb(0.40, 0.23, 0.06)
    }

    /// Grass grows *up* out of the dirt: each column is cut back from the
    /// top of the tile by its own fringe height, so the skyline is ragged.
    /// Filling from the tile's top edge downwards instead gave a flat green
    /// band with the raggedness buried where nobody could see it.
    private static func grassPixel(
        x: Int, y: Int, fringe: Int, rng: inout SeededGenerator
    ) -> CGColor? {
        let blades = 5
        let top = size - 1 - fringe
        if y > top { return nil }                       // sky above this blade
        if y == top { return rgb(0.38, 0.84, 0.30) }    // lit tip
        if y > top - blades { return rgb(0.16, 0.58, 0.17) }
        if y == top - blades { return rgb(0.10, 0.34, 0.11) } // shadow under the grass
        return dirtPixel(x: x, y: y, rng: &rng)
    }

    /// A riveted plate. The bevel is drawn only where the steel region
    /// actually ends, and only every other tile carries rivets — bevelling
    /// and riveting every cell turned a steel floor into an obvious grid of
    /// identical squares.
    private static func steelPixel(x: Int, y: Int, same: Edges, row: Int, col: Int) -> CGColor {
        let last = size - 1
        if (!same.w && x == 0) || (!same.e && x == last)
            || (!same.s && y == 0) || (!same.n && y == last) {
            return rgb(0.14, 0.15, 0.19)
        }
        if (!same.w && x == 1) || (!same.n && y == last - 1) { return rgb(0.54, 0.57, 0.65) }
        if (!same.e && x == last - 1) || (!same.s && y == 1) { return rgb(0.24, 0.26, 0.32) }

        if (row + col).isMultiple(of: 2) {
            let rx = min(x, last - x), ry = min(y, last - y)
            if (4...6).contains(rx) && (4...6).contains(ry) {
                return (rx == 5 && ry == 5) ? rgb(0.66, 0.69, 0.78) : rgb(0.20, 0.22, 0.28)
            }
        }
        return (x + y).isMultiple(of: 4) ? rgb(0.37, 0.39, 0.46) : rgb(0.31, 0.33, 0.39)
    }

    /// Spikes: a dark pit with steel teeth. The teeth reach the *top* of the
    /// tile, because that is the surface a falling lemming lands on — drawn
    /// short and sitting on the floor of the tile, they ended up hidden at
    /// the bottom of the pit where nothing ever touches them.
    private static func trapPixel(x: Int, y: Int) -> CGColor? {
        let period = 6
        let spikeZone = 10
        let inTooth = x % period
        let distanceFromCentre = abs(inTooth - period / 2)
        let toothTop = size - 1 - distanceFromCentre * 3
        if y <= toothTop, y >= size - spikeZone {
            if y >= toothTop - 1 { return rgb(0.92, 0.94, 0.98) } // glinting tip
            return inTooth < period / 2 ? rgb(0.70, 0.72, 0.80) : rgb(0.44, 0.46, 0.54)
        }
        return (x + y).isMultiple(of: 3) ? rgb(0.24, 0.06, 0.06) : rgb(0.15, 0.04, 0.04)
    }

    /// Dark water with a moving crest. `hasSurface` is false for the tiles
    /// with more water above them: only the top of a pond catches the light,
    /// and giving every cell its own crest drew a waterline through the
    /// middle of the pond for each row of it.
    private static func waterPixel(
        x: Int, y: Int, hasSurface: Bool, phase: Int, rng: inout SeededGenerator
    ) -> CGColor {
        if hasSurface {
            let shifted = x + phase * (size / waterPhaseCount)
            let crest = size - 2 - (shifted % 8 < 4 ? 0 : 1)
            if y >= crest { return rgb(0.45, 0.72, 0.92) }
            if y >= crest - 2 { return rgb(0.22, 0.50, 0.80) }
        }
        let roll = Int.random(in: 0..<100, using: &rng)
        if roll < 6 { return rgb(0.18, 0.44, 0.72) }
        return (x + y + phase).isMultiple(of: 2)
            ? rgb(0.10, 0.30, 0.56)
            : rgb(0.08, 0.25, 0.48)
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: 1)
    }

    /// Open edges recede with a jagged inset so adjacent empty cells show
    /// black sky through the gaps, like the original bitmap caves. A capped
    /// tile keeps its full top row — the grass fringe already breaks that
    /// edge up, and insetting it as well left a gap between grass and sky.
    private static func isFilled(x: Int, y: Int, solid: Edges, steel: Bool) -> Bool {
        let inset = steel ? 1 : 3
        let wave = steel ? 0 : ((x * 3 + y * 5) % 3)
        if !solid.w, x < inset + wave { return false }
        if !solid.e, x > size - 1 - inset - wave { return false }
        if !solid.s, y < inset + ((x * 2) % 3) { return false }
        return true
    }
}
