import SpriteKit
import CoreGraphics

/// Turns a grid of characters into a hard-edged bitmap.
///
/// Everything drawn by hand in this game — lemmings, hatch, exit, the skill
/// icons on the panel — goes through here, so they all share one notion of
/// what a pixel is and none of them can drift into looking antialiased.
/// Built with CoreGraphics (not UIImage/NSImage) so the same code works on
/// iOS and macOS.
enum PixelArt {

    /// Each art pixel becomes a block this many device pixels across. The
    /// texture is then sampled with `.nearest`, so it stays crisp however
    /// far the camera zooms in.
    static let defaultScale = 3

    static func makeCGImage(
        _ pattern: [String],
        palette: [Character: CGColor],
        scale: Int = defaultScale
    ) -> CGImage? {
        guard let firstRow = pattern.first else { return nil }
        let width = firstRow.count * scale
        let height = pattern.count * scale

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        for (r, row) in pattern.enumerated() {
            for (c, ch) in row.enumerated() {
                guard let color = palette[ch] else { continue }
                ctx.setFillColor(color)
                // Flip vertically: pattern row 0 is the top, CGContext y = 0
                // is the bottom.
                let y = height - (r + 1) * scale
                ctx.fill(CGRect(x: c * scale, y: y, width: scale, height: scale))
            }
        }

        return ctx.makeImage()
    }

    static func makeTexture(
        _ pattern: [String],
        palette: [Character: CGColor],
        scale: Int = defaultScale
    ) -> SKTexture {
        guard let cgImage = makeCGImage(pattern, palette: palette, scale: scale) else {
            return SKTexture()
        }
        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .nearest
        return texture
    }
}
