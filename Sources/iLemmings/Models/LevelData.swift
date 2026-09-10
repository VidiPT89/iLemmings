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
            rows: rows,
            totalLemmings: 10,
            neededToSave: 5,
            spawnIntervalTicks: 45,
            timeLimitSeconds: 180,
            skillCounts: [.builder: 4, .blocker: 2, .climber: 1, .floater: 1]
        )
    }()

    /// A vertical shaft level: teaches Digger + Basher + Climber.
    static let level2: LevelDefinition = {
        let width = 32
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", width - 3)])
        let ledge1 = row(width, [("#", width - 6), (".", 6)])
        let wall = row(width, [(".", width - 10), ("#", 10)])
        let ledge2 = row(width, [(".", 6), ("#", width - 6 - 1), ("X", 1)])
        let deepWall = row(width, [(".", width - 10), ("#", 10)])
        let floor = row(width, [("S", width)])

        var rows: [String] = [air, entranceRow, air, ledge1, wall, wall, ledge2]
        rows.append(contentsOf: Array(repeating: deepWall, count: 8))
        rows.append(floor)

        return LevelDefinition(
            id: "level2",
            nameKey: "Copper Shaft",
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
            rows: rows,
            totalLemmings: 14,
            neededToSave: 7,
            spawnIntervalTicks: 35,
            timeLimitSeconds: 220,
            skillCounts: [.bomber: 3, .miner: 3, .builder: 3, .blocker: 2, .floater: 2]
        )
    }()

    static let all: [LevelDefinition] = [level1, level2, level3]
}
