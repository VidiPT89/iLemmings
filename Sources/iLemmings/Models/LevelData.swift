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
            nameKey: .levelGreenHills,
            pack: .fun,
            rows: rows,
            totalLemmings: 10,
            neededToSave: 5,
            minReleaseRate: 8,
            timeLimitSeconds: 180,
            skillCounts: [.builder: 4, .blocker: 2, .climber: 1, .floater: 1]
        )
    }()

    /// A 2-tile-tall dirt wall on a flat walkway: Basher (or Climber) then
    /// walk to the exit. No drop after the breach.
    static let level2: LevelDefinition = {
        let width = 28
        let air = row(width, [(".", width)])
        // Dirt wall two tiles tall (cols 8-12). One tile was a step the
        // crowd simply walked up, so the level won itself with no skills.
        // The steel post at the left edge turns the lemmings the wall sent
        // back, rather than walking them straight off the map while you
        // pick a Basher.
        let wallTop = row(width, [("S", 1), (".", 7), ("#", 5), (".", 15)])
        let entranceRow = row(width, [("S", 1), (".", 1), ("E", 1), (".", 5), ("#", 5), (".", 15)])
        let walk = row(width, [("#", 25), ("X", 1), ("#", 2)])
        let floor = row(width, [("S", width)])
        let rows = [air, wallTop, entranceRow, walk, floor]
        return LevelDefinition(
            id: "level2",
            nameKey: .levelCopperShaft,
            pack: .tricky,
            rows: rows,
            totalLemmings: 12,
            neededToSave: 6,
            minReleaseRate: 64,
            timeLimitSeconds: 200,
            skillCounts: [.basher: 3, .climber: 3, .builder: 2, .blocker: 1]
        )
    }()

    /// Trap pit on the walkway: Builder (or Bomber the traps) then the exit.
    static let level3: LevelDefinition = {
        let width = 36
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", width - 3)])
        let walk = row(width, [("#", 14), (".", 4), ("#", 16), ("X", 1), ("#", 1)])
        let traps = row(width, [("#", 14), ("T", 4), ("#", 18)])
        let steelFloor = row(width, [("S", width)])
        let rows = [air, air, entranceRow, air, air, walk, traps, steelFloor]
        return LevelDefinition(
            id: "level3",
            nameKey: .levelEmberGauntlet,
            pack: .taxing,
            rows: rows,
            totalLemmings: 14,
            neededToSave: 7,
            minReleaseRate: 8,
            timeLimitSeconds: 220,
            skillCounts: [.builder: 4, .bomber: 3, .blocker: 2, .floater: 2]
        )
    }()

    /// A diagonal escape route through a deep earth shelf. A single Miner
    /// opens the way for the crowd; the whole group must reach the lower exit.
    static let level4: LevelDefinition = {
        let width = 34
        let air = row(width, [(".", width)])
        let entrance = row(width, [("S", 1), (".", 1), ("E", 1), (".", width - 3)])
        let earth = row(width, [("S", 1), ("#", width - 1)])
        let passage = row(width, [("S", 1), (".", 29), ("X", 1), (".", 3)])
        return LevelDefinition(
            id: "level4", nameKey: .levelObsidianDescent, pack: .mayhem,
            rows: [air, entrance, earth, earth, earth, passage, row(width, [("S", width)])],
            totalLemmings: 16, neededToSave: 16, minReleaseRate: 8,
            timeLimitSeconds: 180, skillCounts: [.miner: 1]
        )
    }()

    /// Builder must bridge a water pit. Floater does not save you from drowning.
    static let level5: LevelDefinition = {
        let width = 26
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", width - 3)])
        // Four-tile water (not six): a Builder climbs one row per brick and
        // this map only has five rows of sky, so a 6-wide gap always left
        // the last tile open and everyone drowned.
        let platform = row(width, [("#", 9), (".", 4), ("#", 10), ("X", 1), ("#", 2)])
        let water = row(width, [("#", 9), ("W", 4), ("#", 13)])
        let bed = row(width, [("S", width)])
        var rows: [String] = [air, air, entranceRow, air, air, platform]
        rows.append(contentsOf: Array(repeating: water, count: 3))
        rows.append(bed)
        return LevelDefinition(
            id: "level5",
            nameKey: .levelStillWater,
            pack: .fun,
            rows: rows,
            totalLemmings: 10,
            neededToSave: 6,
            minReleaseRate: 8,
            timeLimitSeconds: 180,
            skillCounts: [.builder: 5, .blocker: 2, .floater: 2]
        )
    }()

    /// Steel wall too tall to hop: Climber (or a long Builder ramp from the left).
    static let level6: LevelDefinition = {
        let width = 28
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 2), ("E", 1), (".", 6), ("S", 2), (".", 17)])
        // Steel post at the left edge: lemmings turned by the gate pace
        // back and forth waiting for a Climber instead of walking off the map.
        let steelFace = row(width, [("S", 1), (".", 8), ("S", 2), (".", 17)])
        let walk = row(width, [("#", 9), ("S", 2), ("#", 14), ("X", 1), ("#", 2)])
        let floor = row(width, [("S", width)])
        // Three steel-face rows (not six): after the Climber pulls over the
        // top, the drop onto the exit ledge must be ≤ 6 tiles or they splat,
        // and this level had no Floaters.
        var rows: [String] = [air, entranceRow]
        rows.append(contentsOf: Array(repeating: steelFace, count: 3))
        rows.append(contentsOf: [walk, floor])
        return LevelDefinition(
            id: "level6",
            nameKey: .levelIronGate,
            pack: .tricky,
            rows: rows,
            totalLemmings: 12,
            neededToSave: 8,
            minReleaseRate: 66,
            timeLimitSeconds: 200,
            skillCounts: [.climber: 12, .builder: 2, .blocker: 1, .floater: 2]
        )
    }()

    /// Remove the plug under the hatch with one Digger, then let the whole
    /// crowd fall safely into the lower gallery. Preserves the existing ID.
    static let level7: LevelDefinition = {
        let width = 32
        let air = row(width, [(".", width)])
        let entrance = row(width, [("S", 1), (".", 1), ("E", 1), (".", width - 3)])
        let earth = row(width, [("S", 1), ("#", width - 1)])
        let passage = row(width, [("S", 1), (".", 27), ("X", 1), (".", 3)])
        return LevelDefinition(
            id: "level7", nameKey: .levelSunkenPlug, pack: .taxing,
            rows: [air, entrance, earth, earth, earth, passage, row(width, [("S", width)])],
            totalLemmings: 14, neededToSave: 14, minReleaseRate: 8,
            timeLimitSeconds: 180, skillCounts: [.digger: 1]
        )
    }()

    /// The final water crossing combines crowd control and bridge building.
    static let level8: LevelDefinition = {
        let width = 34
        let air = row(width, [(".", width)])
        let entranceRow = row(width, [(".", 3), ("E", 1), (".", width - 4)])
        let platform = row(width, [("#", 14), (".", 3), ("#", 14), ("X", 1), ("#", 2)])
        let shaft = row(width, [("#", 14), (".", 3), ("#", 17)])
        let floor = row(width, [("#", 14), ("W", 3), ("#", 17)])
        var rows: [String] = [air, air, entranceRow, air, air, platform]
        rows.append(contentsOf: Array(repeating: shaft, count: 8))
        rows.append(floor)
        return LevelDefinition(
            id: "level8",
            nameKey: .levelLastBridge,
            pack: .mayhem,
            rows: rows,
            totalLemmings: 16,
            neededToSave: 10,
            minReleaseRate: 8,
            timeLimitSeconds: 240,
            skillCounts: [.builder: 5, .blocker: 2, .floater: 2, .climber: 1]
        )
    }()

    static let all: [LevelDefinition] = [
        level1, level5, level2, level6, level3, level7, level4, level8,
    ]

    /// The level "Play" should open: the first one not finished yet, or the
    /// first level of all once every one of them is done.
    ///
    /// Driven by stars earned rather than by the unlock counter. That
    /// counter only ever counts up, so once everything was unlocked it
    /// saturated and pinned "Play" to the final level: finish it, land back
    /// on the menu, press Play, and get the very same level again with no
    /// way onward. A win always earns at least one star, so "no stars" is
    /// exactly "not finished".
    static func continueIndex(stars: (String) -> Int) -> Int {
        all.firstIndex { stars($0.id) == 0 } ?? 0
    }
}
