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

        // Extra headroom above the platform: Builder's fixed 12-brick
        // staircase climbs one row per brick, so bridging a 3-tile gap
        // needs enough sky above the platform to climb that high without
        // hitting the top of the map before the staircase reaches the far
        // side — verified by a headless simulation that previously showed
        // the lemming falling one column short of the far ledge.
        var rows: [String] = [air, air, entranceRow, air, air, platform]
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

    /// Builder must bridge a water pit. Floater does not save you from drowning.
    static let level5: LevelDefinition = {
        let width = 26
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", width - 3)])
        let platform = row(width, [("#", 9), (".", 6), ("#", 8), ("X", 1), ("#", 2)])
        let water = row(width, [("#", 9), ("W", 6), ("#", 11)])
        let bed = row(width, [("S", width)])
        var rows: [String] = [air, air, entranceRow, air, air, platform]
        rows.append(contentsOf: Array(repeating: water, count: 3))
        rows.append(bed)
        return LevelDefinition(
            id: "level5",
            nameKey: "Still Water",
            pack: .fun,
            rows: rows,
            totalLemmings: 10,
            neededToSave: 6,
            spawnIntervalTicks: 42,
            timeLimitSeconds: 180,
            skillCounts: [.builder: 5, .blocker: 2, .floater: 2]
        )
    }()

    /// Steel wall too tall to hop: Climber (or a long Builder ramp from the left).
    static let level6: LevelDefinition = {
        let width = 28
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", 6), ("S", 2), (".", 17)])
        let steelFace = row(width, [(".", 9), ("S", 2), (".", 17)])
        let walk = row(width, [("#", 9), ("S", 2), ("#", 14), ("X", 1), ("#", 2)])
        let floor = row(width, [("S", width)])
        var rows: [String] = [air, entranceRow]
        rows.append(contentsOf: Array(repeating: steelFace, count: 6))
        rows.append(contentsOf: [walk, floor])
        return LevelDefinition(
            id: "level6",
            nameKey: "Iron Gate",
            pack: .tricky,
            rows: rows,
            totalLemmings: 12,
            neededToSave: 8,
            spawnIntervalTicks: 38,
            timeLimitSeconds: 200,
            skillCounts: [.climber: 12, .builder: 2, .blocker: 1]
        )
    }()

    /// Mine under a steel roof toward an exit, or bomb a dirt plug over water.
    static let level7: LevelDefinition = {
        let width = 32
        let air = row(width, [(".", width)])
        let roof = row(width, [("S", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", width - 3)])
        let dirt = row(width, [("#", 12), (".", 8), ("S", 3), ("X", 1), ("#", 8)])
        let water = row(width, [("#", 12), ("W", 8), ("S", 4), ("#", 8)])
        let bed = row(width, [("S", width)])
        var rows: [String] = [roof, air, entranceRow, air, dirt, dirt]
        rows.append(contentsOf: Array(repeating: water, count: 2))
        rows.append(bed)
        return LevelDefinition(
            id: "level7",
            nameKey: "Sunken Plug",
            pack: .taxing,
            rows: rows,
            totalLemmings: 14,
            neededToSave: 8,
            spawnIntervalTicks: 36,
            timeLimitSeconds: 220,
            skillCounts: [.builder: 4, .blocker: 2, .bomber: 2, .miner: 2]
        )
    }()

    static let level8: LevelDefinition = {
        let width = 34
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", width - 3)])
        let ledge = row(width, [("#", 8), (".", 5), ("#", 6), (".", 6), ("#", 6), ("X", 1), ("#", 2)])
        let hazards = row(width, [("#", 8), ("W", 5), ("#", 6), ("T", 6), ("#", 9)])
        let bed = row(width, [("S", width)])
        var rows: [String] = [air, air, entranceRow, air, ledge]
        rows.append(contentsOf: Array(repeating: hazards, count: 2))
        rows.append(bed)
        return LevelDefinition(
            id: "level8",
            nameKey: "Two Gaps",
            pack: .mayhem,
            rows: rows,
            totalLemmings: 16,
            neededToSave: 10,
            spawnIntervalTicks: 32,
            timeLimitSeconds: 240,
            skillCounts: [.builder: 3, .blocker: 2, .climber: 1, .floater: 1, .bomber: 1]
        )
    }()

    static let all: [LevelDefinition] = [
        level1, level5, level2, level6, level3, level7, level4, level8,
    ]
}
