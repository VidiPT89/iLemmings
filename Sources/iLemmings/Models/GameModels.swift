import Foundation

/// One cell of the destructible terrain grid.
enum Tile: Character {
    case empty = "."
    case dirt = "#"      // diggable in every direction
    case steel = "S"     // indestructible
    case entrance = "E"
    case exit = "X"
    case trap = "T"      // instant death (spikes/water)
}

enum LemSkill: String, CaseIterable, Identifiable {
    case climber, floater, bomber, blocker, builder, basher, miner, digger
    var id: String { rawValue }

    var locKey: LocKey {
        switch self {
        case .climber: return .skillClimber
        case .floater: return .skillFloater
        case .bomber: return .skillBomber
        case .blocker: return .skillBlocker
        case .builder: return .skillBuilder
        case .basher: return .skillBasher
        case .miner: return .skillMiner
        case .digger: return .skillDigger
        }
    }

    var symbol: String {
        switch self {
        case .climber: return "figure.climbing"
        case .floater: return "arrow.down.circle.fill"
        case .bomber: return "timer"
        case .blocker: return "hand.raised.fill"
        case .builder: return "hammer.fill"
        case .basher: return "arrow.right.to.line"
        case .miner: return "arrow.down.right"
        case .digger: return "arrow.down.to.line"
        }
    }
}

enum LemState: Equatable {
    case walking
    case falling
    case climbing
    case blocking
    case building(stepsLeft: Int)
    // Basher/Miner/Digger have no step limit in the original — they tunnel
    // until they hit steel, open air, or a missing floor, whichever first.
    case basher
    case miner
    case digger
    case floating
    case shrugging(ticksLeft: Int)
    case splatting(ticksLeft: Int)
    case ohNo(ticksLeft: Int)
    case saved
    case dead
}

struct Lemming: Identifiable {
    let id: Int
    var x: Double        // continuous horizontal position (in tiles)
    var y: Int           // row (tile)
    var facingRight: Bool = true
    var state: LemState = .falling
    var fallDistance: Int = 0
    var hasClimber: Bool = false
    var hasFloater: Bool = false
    /// Parallel bomber fuse, like LemmingsJS `countdown` (starts at 80 ticks
    /// there, ~5s here). The lemming keeps walking/working until the fuse
    /// hits zero, then Oh No, then the crater.
    var countdownTicks: Int = 0
    /// Ticks accumulated since the last walking/digging/bashing/mining/
    /// building step — these only advance one tile every
    /// `GameEngine.walkTicksPerStep`/`workTicksPerStep` ticks, matching the
    /// relative pacing of the original's actual per-action frame cadence
    /// (verified against LemmingsJS's source), instead of one full tile per
    /// tick (20 tiles/sec), which made lemmings cross an entire level (or
    /// tunnel through it) and die in well under a second.
    var actionProgress: Int = 0
    var isAlive: Bool { state != .dead && state != .saved }
    var canReceiveSkill: Bool {
        switch state {
        case .dead, .saved, .splatting, .ohNo: return false
        default: return true
        }
    }
    /// Digit 5...1 drawn above the head during the bomber fuse.
    var countdownDigit: Int? {
        guard countdownTicks > 0 else { return nil }
        return max(1, (countdownTicks + 19) / 20)
    }
}

/// Classic Lemmings difficulty tiers, used to group levels into packs.
enum LevelPack: String, CaseIterable {
    case fun, tricky, taxing, mayhem

    var locKey: LocKey {
        switch self {
        case .fun: return .packFun
        case .tricky: return .packTricky
        case .taxing: return .packTaxing
        case .mayhem: return .packMayhem
        }
    }
}

struct LevelDefinition: Identifiable {
    let id: String
    let nameKey: String
    let pack: LevelPack
    let rows: [String]           // ASCII rows, top to bottom, matching Tile raw values
    let totalLemmings: Int
    let neededToSave: Int
    let spawnIntervalTicks: Int
    let timeLimitSeconds: Int
    let skillCounts: [LemSkill: Int]
    /// Classic release-rate floor (1-99). Mapped from `spawnIntervalTicks`
    /// with the LemmingsJS formula interval = 104 - rate.
    var minReleaseRate: Int { min(99, max(1, 104 - spawnIntervalTicks)) }

    var width: Int { rows.first?.count ?? 0 }
    var height: Int { rows.count }

    /// 1-3 stars from how many lemmings were saved and how much time was left.
    func stars(saved: Int, secondsRemaining: Int) -> Int {
        guard saved >= neededToSave else { return 0 }
        if saved >= totalLemmings { return 3 }
        let bonusThreshold = neededToSave + max(1, (totalLemmings - neededToSave) / 2)
        if saved >= bonusThreshold || secondsRemaining > timeLimitSeconds / 3 { return 2 }
        return 1
    }
}
