import Foundation

/// Deterministic RNG so the procedural terrain textures look the same on
/// every launch instead of re-rolling their speckle pattern each time.
///
/// Lives on its own rather than at the top of `GameScene` so it can be
/// compiled into a small headless tool that dumps the tile textures to PNG,
/// which is the only way to check the terrain art while the app itself
/// needs a window to show anything.
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
