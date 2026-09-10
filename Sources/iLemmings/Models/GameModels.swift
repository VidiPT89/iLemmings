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
    case basher(stepsLeft: Int)
    case miner(stepsLeft: Int)
    case digger(stepsLeft: Int)
    case floating
    case exploding(ticksLeft: Int)
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
    var isAlive: Bool { state != .dead && state != .saved }
}

struct LevelDefinition: Identifiable {
    let id: String
    let nameKey: String
    let rows: [String]           // ASCII rows, top to bottom, matching Tile raw values
    let totalLemmings: Int
    let neededToSave: Int
    let spawnIntervalTicks: Int
    let timeLimitSeconds: Int
    let skillCounts: [LemSkill: Int]

    var width: Int { rows.first?.count ?? 0 }
    var height: Int { rows.count }
}
