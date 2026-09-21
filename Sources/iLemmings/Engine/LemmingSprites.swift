import SpriteKit
import CoreGraphics

/// Turns the pixel grids in `LemmingArt` into SpriteKit textures and the
/// per-state animations the scene plays.
///
/// Colours are the 1991 palette — bright green hair, skin-tone face,
/// royal-blue overalls, near-black shoes — confirmed against an actual
/// screenshot of the original (Wikipedia's Amiga_Lemmings.png), not just
/// text descriptions. Built with CoreGraphics (not UIImage/NSImage) so the
/// same code works on iOS and macOS.
enum LemmingSprites {

    /// The frame rate of the original's animations: eight frames of walk in
    /// roughly half a second. Every cycle here uses the same cadence so a
    /// lemming that switches job doesn't visibly change speed.
    private static let framesPerSecond = 0.12

    private static let palette: [Character: CGColor] = [
        "g": CGColor(red: 0.10, green: 0.72, blue: 0.16, alpha: 1), // hair green — a prior text-only research pass wrongly said blond
        "s": CGColor(red: 0.96, green: 0.78, blue: 0.60, alpha: 1), // skin
        "b": CGColor(red: 0.24, green: 0.32, blue: 0.92, alpha: 1), // overalls blue
        "d": CGColor(red: 0.05, green: 0.06, blue: 0.16, alpha: 1), // shoes
        "k": CGColor(red: 0, green: 0, blue: 0, alpha: 1),          // eye
        "y": CGColor(red: 0.95, green: 0.65, blue: 0.12, alpha: 1), // umbrella
        "t": CGColor(red: 0.72, green: 0.74, blue: 0.80, alpha: 1), // tool head
        "n": CGColor(red: 0.50, green: 0.32, blue: 0.14, alpha: 1), // tool handle
        "o": CGColor(red: 0.85, green: 0.45, blue: 0.15, alpha: 1), // brick
    ]

    static func makeCGImage(_ pattern: [String]) -> CGImage? {
        PixelArt.makeCGImage(pattern, palette: palette)
    }

    private static func makeTexture(_ pattern: [String]) -> SKTexture {
        PixelArt.makeTexture(pattern, palette: palette)
    }

    private static func loop(_ patterns: [[String]]) -> SKAction {
        .repeatForever(.animate(with: patterns.map(makeTexture), timePerFrame: framesPerSecond))
    }

    // MARK: - Animations
    //
    // Every working state has its own cycle. The previous build drew a
    // standing lemming with a coloured dot over its head for Basher, Miner,
    // Digger, Builder and Blocker alike, which is not how any of this reads
    // in the original: there you tell the jobs apart by what the lemming is
    // visibly doing.

    static let walk = loop([LemmingArt.walk1, LemmingArt.walk2, LemmingArt.walk3, LemmingArt.walk4])
    static let fall = loop([LemmingArt.fall1, LemmingArt.fall2])
    static let float = loop([LemmingArt.float1, LemmingArt.float2])
    static let climb = loop([LemmingArt.climb1, LemmingArt.climb2])
    static let dig = loop([LemmingArt.dig1, LemmingArt.dig2])
    static let bash = loop([LemmingArt.bash1, LemmingArt.bash2])
    static let mine = loop([LemmingArt.mine1, LemmingArt.mine2])
    static let build = loop([LemmingArt.build1, LemmingArt.build2])
    static let block = loop([LemmingArt.block1, LemmingArt.block2])
    static let shrug = loop([LemmingArt.shrug1, LemmingArt.shrug2])
    static let drown = loop([LemmingArt.drown1, LemmingArt.drown2])

    /// Oh-No runs faster than the rest: it is a five-second panic, and the
    /// quicker flap is the tell that this one is about to blow.
    static let ohNo = SKAction.repeatForever(
        .animate(with: [LemmingArt.ohno1, LemmingArt.ohno2].map(makeTexture), timePerFrame: 0.07)
    )

    // MARK: - Single frames

    static let stand: SKTexture = makeTexture(LemmingArt.walk1)
    static let splat: SKTexture = makeTexture(LemmingArt.splat1)

    /// The panel icon for a skill: the lemming actually doing that job.
    /// That is what the original puts on its buttons, and it means the panel
    /// teaches the poses you then have to recognise out on the level — which
    /// a set of abstract arrow glyphs never did.
    static func iconImage(for skill: LemSkill) -> CGImage? {
        let art: [String]
        switch skill {
        case .climber: art = LemmingArt.climb1
        case .floater: art = LemmingArt.float1
        case .bomber:  art = LemmingArt.ohno1
        case .blocker: art = LemmingArt.block1
        case .builder: art = LemmingArt.build1
        case .basher:  art = LemmingArt.bash1
        case .miner:   art = LemmingArt.mine1
        case .digger:  art = LemmingArt.dig1
        }
        return makeCGImage(art)
    }

    /// A CGImage of the walking pose, for SwiftUI decorations (e.g. the
    /// menu's background walkers) that don't need a full SpriteKit scene.
    static let standCGImageForUI: CGImage? = makeCGImage(LemmingArt.walk1)
}
