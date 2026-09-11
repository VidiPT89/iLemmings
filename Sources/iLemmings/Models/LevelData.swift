import Foundation

/// Built-in levels. Rows are built programmatically (never hand-typed ASCII)
/// to guarantee every row has the same width and no off-by-one mistakes.
enum LevelLibrary {

    private static func row(_ width: Int, _ segments: [(Character, Int)]) -> String {
        var s = ""
        for (ch, count) in segments { s += String(repeating: ch, count: count) }
        precondition(s.count == width, "row width mismatch: \(s.count) != \(width)")
        return s
    }

    /// A simple bridge-the-pit level: teaches Builder + Blocker.
    static let level1: LevelDefinition = {
        let width = 30
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 3), ("E", 1), (".", width - 4)])
        let platform = row(width, [("#", 12), (".", 3), ("#", 12), ("X", 1), ("#", 2)])
        let shaft = row(width, [("#", 12), (".", 3), ("#", 15)])
        let floor = row(width, [("#", 12), ("T", 3), ("#", 15)])

        var rows: [String] = [air, entranceRow, air, air, platform]
        rows.append(contentsOf: Array(repeating: shaft, count: 10))
        rows.append(floor)

        return LevelDefinition(
            id: "level1",
            nameKey: "Green Hills",
            pack: .fun,
            rows: rows,
            totalLemmings: 10,
            neededToSave: 5,
            spawnIntervalTicks: 45,
            timeLimitSeconds: 180,
            skillCounts: [.builder: 4, .blocker: 2, .climber: 1, .floater: 1]
        )
    }()

    /// A wall-then-shaft level: teaches Basher (breach the 2-tile-tall wall —
    /// Climber or Bomber also work) then Digger (breach the floor to reach
    /// the exit chamber below, or just walk off its far edge). Terrain is
    /// shared and permanent, so the diggable block is only 2 tiles thick —
    /// thick enough that Digger visibly saves the walk around, but thin
    /// enough that even a lemming that falls straight through a tunnel a
    /// previous lemming dug (no safe mid-air ledge to catch it) still only
    /// falls 6 tiles total, exactly at the safe limit. A thicker block
    /// looked fine solo but turned any already-dug column into a death trap
    /// for every lemming that followed over it — verified with a headless
    /// simulation, not just by inspection.
    static let level2: LevelDefinition = {
        let width = 28
        let air = row(width, [(".", width)])
        // Entrance plus the upper half of the basher wall (cols 6-10) —
        // together with row2's lower half, a 2-tile-tall wall too tall for
        // the automatic single-ledge hop, so it genuinely requires a skill.
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", 3), ("#", 5), (".", 17)])
        let wallLowerAndWalk = row(width, [(".", 6), ("#", 5), (".", 17)])
        let platformFloor = row(width, [("#", 12), (".", 16)])
        // Top/bottom of the diggable block the platform drops onto.
        let diggableLayer = row(width, [(".", 12), ("#", 12), (".", 4)])
        // Open chamber below the diggable block — fully empty so a lemming
        // lands here whether it was dug through or fell past the block's
        // right edge.
        let chamber = row(width, [(".", width)])
        let chamberFloor = row(width, [("S", 20), ("X", 1), ("S", 7)])

        var rows: [String] = [air, entranceRow, wallLowerAndWalk, platformFloor, air, air]
        rows.append(contentsOf: Array(repeating: diggableLayer, count: 2))
        rows.append(contentsOf: [chamber, chamberFloor])

        return LevelDefinition(
            id: "level2",
            nameKey: "Copper Shaft",
            pack: .tricky,
            rows: rows,
            totalLemmings: 12,
            neededToSave: 6,
            spawnIntervalTicks: 40,
            timeLimitSeconds: 200,
            skillCounts: [.digger: 3, .basher: 3, .climber: 3, .builder: 2, .bomber: 1]
        )
    }()

    /// A trap gauntlet: teaches Bomber + Miner.
    static let level3: LevelDefinition = {
        let width = 36
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", width - 3)])
        let roof = row(width, [("#", width)])
        let trapFloor = row(width, [("#", 14), ("T", 4), ("#", width - 18 - 1), ("X", 1)])
        let steelFloor = row(width, [("S", width)])

        var rows: [String] = [air, entranceRow, air, air, roof]
        rows.append(contentsOf: Array(repeating: air, count: 8))
        rows.append(trapFloor)
        rows.append(steelFloor)

        return LevelDefinition(
            id: "level3",
            nameKey: "Ember Gauntlet",
            pack: .taxing,
            rows: rows,
            totalLemmings: 14,
            neededToSave: 7,
            spawnIntervalTicks: 35,
            timeLimitSeconds: 220,
            skillCounts: [.bomber: 3, .miner: 3, .builder: 3, .blocker: 2, .floater: 2]
        )
    }()

    /// The hardest built-in level: narrow bridges over traps with scarce skills.
    static let level4: LevelDefinition = {
        let width = 40
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", width - 3)])
        let highLedge = row(width, [("#", 10), (".", width - 10)])
        let trapGap = row(width, [("#", 10), (".", 6), ("T", 3), (".", width - 19 - 1), ("X", 1)])
        let deepWall = row(width, [(".", width - 8), ("#", 8)])
        let steelFloor = row(width, [("S", width)])

        var rows: [String] = [air, entranceRow, air, highLedge, air, trapGap]
        rows.append(contentsOf: Array(repeating: deepWall, count: 8))
        rows.append(steelFloor)

        return LevelDefinition(
            id: "level4",
            nameKey: "Obsidian Descent",
            pack: .mayhem,
            rows: rows,
            totalLemmings: 16,
            neededToSave: 8,
            spawnIntervalTicks: 30,
            timeLimitSeconds: 240,
            skillCounts: [.builder: 2, .bomber: 2, .basher: 2, .climber: 1, .floater: 1, .blocker: 1]
        )
    }()

    static let all: [LevelDefinition] = [level1, level2, level3, level4]
}
