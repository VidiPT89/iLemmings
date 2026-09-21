import Foundation

/// The numbers that decide how the game *feels*, kept together with where
/// each one came from.
///
/// These were reverse-engineered from the original's own source (via
/// LemmingsJS) rather than guessed, and they are the difference between a
/// level that plays like Lemmings and one where the crowd crosses the whole
/// map and dies in under a second. Collected here so changing the feel is
/// one deliberate edit in one place, not a hunt through the simulation.
enum GameTuning {

    static let maxSafeFall = 6
    static let bomberFuseTicks = 100
    static let ohNoTicks = 16
    static let fallTicksPerStep = 4
    static let floatTicksPerStep = 8
    static let climbTicksPerStep = 8
    /// Derived from the original's actual source (LemmingsJS's ActionWalkSystem):
    /// it moves 1px/tick at a 60ms tick (~16.67 ticks/sec) — about 0.6s to
    /// cross one lemming-height of ground. At this engine's 20 ticks/sec,
    /// one tile every 12 ticks lands on the same ~0.6s pace. Also used for
    /// Digger, whose original cadence (1 row/8 ticks ≈ 0.48s) is close to
    /// walking speed.
    static let walkTicksPerStep = 12
    /// Basher/Miner/Builder tunnel through solid ground far slower than a
    /// lemming walks — the original's ActionBashSystem/ActionBuildSystem
    /// only advance once every 16-24 ticks (vs. walking's every tick).
    static let workTicksPerStep = 24
}
