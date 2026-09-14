import SpriteKit

/// Neighbor-aware organic tiles so the playfield reads as a cave, not a
/// chessboard. Physics stay on the grid; only the pixels of each cell change.
enum TerrainRenderer {

    enum Style: Hashable { case dirt, grassCap, steel, trap, water }

    static func style(for tile: Tile, above: Tile) -> Style? {
        switch tile {
        case .dirt:
            let isCapped = above != .dirt && above != .steel
            return isCapped ? .grassCap : .dirt
        case .steel: return .steel
        case .trap: return .trap
        case .water: return .water
        case .exit, .entrance, .empty: return nil
        }
    }

    static func texture(
        style: Style,
        solidN: Bool,
        solidE: Bool,
        solidS: Bool,
        solidW: Bool,
        seed: Int
    ) -> SKTexture {
        let size = 22
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }

        var rng = SeededGenerator(seed: seed)
        let base: (CGFloat, CGFloat, CGFloat)
        let variance: CGFloat
        switch style {
        case .dirt: base = (0.42, 0.24, 0.06); variance = 0.07
        case .grassCap: base = (0.26, 0.48, 0.14); variance = 0.08
        case .steel: base = (0.38, 0.40, 0.44); variance = 0.04
        case .trap: base = (0.55, 0.07, 0.05); variance = 0.06
        case .water: base = (0.12, 0.34, 0.58); variance = 0.05
        }

        for y in 0..<size {
            for x in 0..<size {
                if !isFilled(x: x, y: y, size: size, n: solidN, e: solidE, s: solidS, w: solidW, steel: style == .steel || style == .water) {
                    continue
                }
                let grassLine = Int(Double(size) * 0.72)
                let useGrass = style == .grassCap && y >= grassLine
                let baseCol = useGrass
                    ? (0.26, 0.48, 0.14)
                    : base
                let n = CGFloat.random(in: -variance...variance, using: &rng)
                ctx.setFillColor(CGColor(
                    red: min(max(baseCol.0 + n, 0), 1),
                    green: min(max(baseCol.1 + n, 0), 1),
                    blue: min(max(baseCol.2 + n, 0), 1),
                    alpha: 1
                ))
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        guard let image = ctx.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// Open edges recede with a jagged inset so adjacent empty cells show
    /// black sky through the gaps, like the original bitmap caves.
    private static func isFilled(
        x: Int, y: Int, size: Int,
        n: Bool, e: Bool, s: Bool, w: Bool,
        steel: Bool
    ) -> Bool {
        let inset = steel ? 1 : 3
        let wave = steel ? 0 : ((x * 3 + y * 5) % 3)
        if !w, x < inset + wave { return false }
        if !e, x > size - 1 - inset - wave { return false }
        if !s, y < inset + ((x * 2) % 3) { return false }
        if !n, y > size - 1 - inset - ((x * 2) % 3) { return false }
        return true
    }
}
