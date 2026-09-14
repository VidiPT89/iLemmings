import SpriteKit
import CoreGraphics

/// Procedural pixel-art sprites for the lemmings, drawn to match the classic
/// 1991 look: green hair, skin-tone face, sky-blue overalls, dark-blue shoes
/// — confirmed against an actual screenshot of the original (Wikipedia's
/// Amiga_Lemmings.png), not just text descriptions.
/// Built with CoreGraphics (not UIImage/NSImage) so the same code works on
/// iOS and macOS.
enum LemmingSprites {

    private static let pixelScale = 6

    // 8 columns x 12 rows. '.' = transparent.
    // 1 = hair (green), 2 = skin, 3 = overalls (blue), 4 = shoe/outline (dark navy), 5 = eye (black)
    private static let walkFrame1: [String] = [
        "..1111..",
        ".111111.",
        ".222222.",
        ".2522252",
        ".222222.",
        "..3333..",
        ".333333.",
        ".333333.",
        ".3.33.3.",
        ".3.33.3.",
        "44......",
        "......44",
    ]

    private static let walkFrame2: [String] = [
        "..1111..",
        ".111111.",
        ".222222.",
        ".2522252",
        ".222222.",
        "..3333..",
        ".333333.",
        ".333333.",
        "..3.3.3.",
        "..3.3.3.",
        ".....44.",
        ".44.....",
    ]

    private static let standFrame: [String] = [
        "..1111..",
        ".111111.",
        ".222222.",
        ".2522252",
        ".222222.",
        "..3333..",
        ".333333.",
        ".333333.",
        "..3333..",
        "..3333..",
        "..44.44.",
        "........",
    ]

    private static let climbFrame: [String] = [
        "........",
        "..1111..",
        ".111111.",
        ".222222.",
        ".2522252",
        "..3333..",
        "3.3333.3",
        "3.3333.3",
        "..3333..",
        "..3333..",
        "..44.44.",
        "........",
    ]

    private static let floatFrame: [String] = [
        "..6666..",
        ".6....6.",
        "..1111..",
        ".111111.",
        ".222222.",
        ".2522252",
        "..3333..",
        ".333333.",
        ".3.33.3.",
        ".3.33.3.",
        "44......",
        "......44",
    ]

    private static let blockFrame: [String] = [
        "..1111..",
        ".111111.",
        ".222222.",
        ".2522252",
        ".222222.",
        ".333333.",
        "3.33333.",
        "3.33333.",
        "..3.3...",
        "..3.3...",
        ".44..44.",
        "........",
    ]

    private static func color(for code: Character) -> CGColor {
        switch code {
        case "1": return CGColor(red: 0.15, green: 0.62, blue: 0.20, alpha: 1) // hair green — confirmed against an actual screenshot of the original (a prior text-only research pass wrongly said blond)
        case "2": return CGColor(red: 0.93, green: 0.74, blue: 0.55, alpha: 1) // skin
        case "3": return CGColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 1) // overalls blue
        case "4": return CGColor(red: 0.08, green: 0.10, blue: 0.20, alpha: 1) // shoes/outline
        case "5": return CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1) // eye
        case "6": return CGColor(red: 0.85, green: 0.78, blue: 0.20, alpha: 1) // umbrella
        default: return CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
    }

    static func makeCGImage(_ pattern: [String]) -> CGImage? {
        let cols = pattern[0].count
        let rows = pattern.count
        let width = cols * pixelScale
        let height = rows * pixelScale

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        for (r, row) in pattern.enumerated() {
            for (c, ch) in row.enumerated() where ch != "." {
                ctx.setFillColor(color(for: ch))
                // Flip vertically: image row 0 is the top, CGContext y=0 is the bottom.
                let y = height - (r + 1) * pixelScale
                ctx.fill(CGRect(x: c * pixelScale, y: y, width: pixelScale, height: pixelScale))
            }
        }

        return ctx.makeImage()
    }

    private static func makeTexture(_ pattern: [String]) -> SKTexture {
        guard let cgImage = makeCGImage(pattern) else { return SKTexture() }
        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .nearest
        return texture
    }

    static let walk1: SKTexture = makeTexture(walkFrame1)
    static let walk2: SKTexture = makeTexture(walkFrame2)
    static let stand: SKTexture = makeTexture(standFrame)
    static let climb: SKTexture = makeTexture(climbFrame)
    static let block: SKTexture = makeTexture(blockFrame)
    static let float: SKTexture = makeTexture(floatFrame)

    static let walkAnimation: SKAction = .animate(with: [walk1, walk2], timePerFrame: 0.15)

    /// A CGImage of the walking pose, for SwiftUI decorations (e.g. the
    /// menu's background walkers) that don't need a full SpriteKit scene.
    static let standCGImageForUI: CGImage? = makeCGImage(walkFrame1)
}
