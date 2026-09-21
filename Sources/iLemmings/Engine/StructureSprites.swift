import SpriteKit
import CoreGraphics

/// Pixel art for the two structures every level has: the hatch the lemmings
/// drop out of and the exit they have to reach.
///
/// Both used to be `SKShapeNode` rectangles with rounded corners, which is
/// the one thing on screen that could never look like 1991 — vector shapes
/// with antialiased edges sitting on top of hard-edged bitmap terrain.
enum StructureSprites {

    private static let palette: [Character: CGColor] = [
        "#": CGColor(red: 0.20, green: 0.22, blue: 0.27, alpha: 1), // steel, in shadow
        "=": CGColor(red: 0.42, green: 0.45, blue: 0.52, alpha: 1), // steel
        "-": CGColor(red: 0.66, green: 0.70, blue: 0.78, alpha: 1), // steel, lit
        "k": CGColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1), // the drop
        "G": CGColor(red: 0.20, green: 0.85, blue: 0.30, alpha: 1), // hatch stripe
        "o": CGColor(red: 0.95, green: 0.65, blue: 0.12, alpha: 1), // bolt
        "Y": CGColor(red: 1.00, green: 0.94, blue: 0.47, alpha: 1), // lamp, lit
        "y": CGColor(red: 0.59, green: 0.47, blue: 0.16, alpha: 1), // lamp, dim
        "B": CGColor(red: 0.55, green: 0.18, blue: 0.13, alpha: 1), // exit brick
        "b": CGColor(red: 0.37, green: 0.12, blue: 0.09, alpha: 1), // exit brick, shaded
        "w": CGColor(red: 1.00, green: 0.84, blue: 0.36, alpha: 1), // doorway glow
    ]

    /// The hatch before the level starts: shutters down.
    private static let hatchClosedArt: [String] = [
        "..----------------..",
        ".==================.",
        "#=o=============o=#.",
        "#==================#",
        "#===GGGGGGGGGGGG===#",
        "#==================#",
        ".##==============##.",
        "..#=--------------#.",
        "..#=--------------#.",
        "..#=--------------#.",
        "..#=--------------#.",
        "..#=--------------#.",
        "..##==============##",
        "...################.",
    ]

    /// Shutters up. The level swaps to this frame as the first
    /// lemming is released, which is the original's opening beat.
    private static let hatchOpenArt: [String] = [
        "..----------------..",
        ".==================.",
        "#=o=============o=#.",
        "#==================#",
        "#===GGGGGGGGGGGG===#",
        "#==================#",
        ".##==============##.",
        "..#--kkkkkkkkkkk--#.",
        "..#--kkkkkkkkkkk--#.",
        "..#--kkkkkkkkkkk--#.",
        "..#--kkkkkkkkkkk--#.",
        "..#--kkkkkkkkkkk--#.",
        "..##==============##",
        "...################.",
    ]

    /// The exit flashes between these two frames so it catches the
    /// eye from across a scrolling level.
    private static let exitLitArt: [String] = [
        ".......YY.......",
        "......YYYY......",
        ".......##.......",
        ".....######.....",
        "....########....",
        "...##########...",
        "...#BBBBBBBB#...",
        "...#BbBBBBbB#...",
        "...#BBBBBBBB#...",
        "...#BBwwwwBB#...",
        "...#BBwwwwBB#...",
        "...#BbwwwwbB#...",
        "...#BBwwwwBB#...",
        "...#BBwwwwBB#...",
        "...#BBwwwwBB#...",
        "...#BbwwwwbB#...",
        "...#BBwwwwBB#...",
        "...#BBwwwwBB#...",
        "...##########...",
        "..############..",
    ]

    private static let exitDimArt: [String] = [
        "................",
        ".......yy.......",
        ".......##.......",
        ".....######.....",
        "....########....",
        "...##########...",
        "...#BBBBBBBB#...",
        "...#BbBBBBbB#...",
        "...#BBBBBBBB#...",
        "...#BByyyyBB#...",
        "...#BByyyyBB#...",
        "...#BbyyyybB#...",
        "...#BByyyyBB#...",
        "...#BByyyyBB#...",
        "...#BByyyyBB#...",
        "...#BbyyyybB#...",
        "...#BByyyyBB#...",
        "...#BByyyyBB#...",
        "...##########...",
        "..############..",
    ]

    static let hatchClosed = PixelArt.makeTexture(hatchClosedArt, palette: palette)
    static let hatchOpen = PixelArt.makeTexture(hatchOpenArt, palette: palette)
    static let exitLit = PixelArt.makeTexture(exitLitArt, palette: palette)
    static let exitDim = PixelArt.makeTexture(exitDimArt, palette: palette)

    /// Width-to-height of the source art, so the scene can size the node in
    /// tiles without the structure ending up stretched.
    static let hatchAspect = CGFloat(hatchClosedArt[0].count) / CGFloat(hatchClosedArt.count)
    static let exitAspect = CGFloat(exitLitArt[0].count) / CGFloat(exitLitArt.count)
}
