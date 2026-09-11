import Foundation

/// Pure-Swift, deterministic tick-based simulation. No UI/rendering here —
/// `GameScene` (SpriteKit) reads this engine's published state to draw frames.
final class GameEngine: ObservableObject {
    let level: LevelDefinition
    @Published private(set) var grid: [[Tile]]
    @Published private(set) var lemmings: [Lemming] = []
    @Published private(set) var savedCount = 0
    @Published private(set) var deadCount = 0
    @Published private(set) var spawnedCount = 0
    @Published private(set) var secondsRemaining: Int
    @Published private(set) var isWon = false
    @Published private(set) var isLost = false
    @Published var skillInventory: [LemSkill: Int]
    @Published var selectedSkill: LemSkill?

    private var tickCounter = 0
    private var nextID = 0
    private let entrance: (row: Int, col: Int)
    private let maxSafeFall = 6
    /// One walking step (one column) every 4 ticks — 5 tiles/sec at 20
    /// ticks/sec, instead of the previous 1 tile/tick (20 tiles/sec) which
    /// let a lemming cross an entire level and die before it was visible.
    private let walkTicksPerStep = 4

    var ticksPerSecond: Double { 20 }

    init(level: LevelDefinition) {
        self.level = level
        let parsedGrid = level.rows.map { row in row.compactMap { Tile(rawValue: $0) } }
        self.grid = parsedGrid
        self.secondsRemaining = level.timeLimitSeconds
        self.skillInventory = level.skillCounts
        var found = (row: 1, col: 1)
        for (r, row) in parsedGrid.enumerated() {
            for (c, t) in row.enumerated() where t == .entrance {
                found = (r, c)
            }
        }
        self.entrance = found
    }

    /// Reinitializes all mutable state in place (same instance, same level)
    /// so SwiftUI views bound to this engine via @StateObject keep working
    /// after a restart instead of going stale against a replaced instance.
    func reset() {
        grid = level.rows.map { row in row.compactMap { Tile(rawValue: $0) } }
        lemmings = []
        savedCount = 0
        deadCount = 0
        spawnedCount = 0
        secondsRemaining = level.timeLimitSeconds
        isWon = false
        isLost = false
        skillInventory = level.skillCounts
        selectedSkill = nil
        tickCounter = 0
        nextID = 0
    }

    var width: Int { level.width }
    var height: Int { level.height }
    var entranceColumn: Int { entrance.col }
    var entranceRow: Int { entrance.row }

    func tile(_ row: Int, _ col: Int) -> Tile {
        guard row >= 0, row < height, col >= 0, col < width else { return .steel }
        return grid[row][col]
    }

    private func setTile(_ row: Int, _ col: Int, _ tile: Tile) {
        guard row >= 0, row < height, col >= 0, col < width else { return }
        grid[row][col] = tile
    }

    func selectSkill(_ skill: LemSkill) {
        guard (skillInventory[skill] ?? 0) > 0 else { return }
        selectedSkill = (selectedSkill == skill) ? nil : skill
    }

    /// Attempts to assign the currently selected skill to the lemming at index.
    func applySelectedSkill(to lemmingID: Int) {
        guard let skill = selectedSkill,
              let idx = lemmings.firstIndex(where: { $0.id == lemmingID }),
              (skillInventory[skill] ?? 0) > 0 else { return }
        var lem = lemmings[idx]
        guard lem.isAlive else { return }

        switch skill {
        case .climber:
            guard !lem.hasClimber else { return }
            lem.hasClimber = true
        case .floater:
            guard !lem.hasFloater else { return }
            lem.hasFloater = true
        case .blocker:
            guard lem.state == .walking else { return }
            lem.state = .blocking
        case .builder:
            guard lem.state == .walking else { return }
            lem.state = .building(stepsLeft: 8)
        case .basher:
            guard lem.state == .walking else { return }
            lem.state = .basher(stepsLeft: 10)
        case .miner:
            guard lem.state == .walking else { return }
            lem.state = .miner(stepsLeft: 10)
        case .digger:
            guard lem.state == .walking else { return }
            lem.state = .digger(stepsLeft: 8)
        case .bomber:
            if case .exploding = lem.state { return } // already counting down, don't reset the timer
            lem.state = .exploding(ticksLeft: Int(ticksPerSecond * 3))
        }

        lemmings[idx] = lem
        skillInventory[skill] = (skillInventory[skill] ?? 1) - 1
        selectedSkill = nil
    }

    func tick() {
        guard !isWon, !isLost else { return }
        tickCounter += 1

        if tickCounter % Int(ticksPerSecond) == 0 {
            secondsRemaining -= 1
        }

        if spawnedCount < level.totalLemmings, tickCounter % level.spawnIntervalTicks == 0 || spawnedCount == 0 {
            spawn()
        }

        for i in lemmings.indices {
            stepLemming(&lemmings[i])
        }

        evaluateEndConditions()
    }

    private func spawn() {
        let lem = Lemming(id: nextID, x: Double(entrance.col), y: entrance.row, state: .falling)
        nextID += 1
        lemmings.append(lem)
        spawnedCount += 1
    }

    /// Matches the original: the level keeps running (so more lemmings can
    /// still be saved for a higher star rating) until either the clock runs
    /// out or every spawned lemming has been resolved (saved or dead) —
    /// reaching the minimum save count doesn't end the level early.
    private func evaluateEndConditions() {
        let allLemmingsResolved = spawnedCount >= level.totalLemmings && lemmings.allSatisfy { !$0.isAlive }
        guard allLemmingsResolved || secondsRemaining <= 0 else { return }
        if savedCount >= level.neededToSave {
            isWon = true
        } else {
            isLost = true
        }
    }

    private func isSolid(_ t: Tile) -> Bool {
        t == .dirt || t == .steel
    }

    private func stepLemming(_ lem: inout Lemming) {
        guard lem.isAlive else { return }
        let col = Int(lem.x.rounded())

        if tile(lem.y, col) == .trap {
            lem.state = .dead
            deadCount += 1
            return
        }
        if tile(lem.y, col) == .exit {
            lem.state = .saved
            savedCount += 1
            return
        }

        switch lem.state {
        case .falling:
            let below = lem.y + 1
            if isSolid(tile(below, col)) {
                if lem.fallDistance > maxSafeFall && !lem.hasFloater {
                    lem.state = .dead
                    deadCount += 1
                } else {
                    lem.state = .walking
                    lem.fallDistance = 0
                }
            } else {
                lem.y = below
                lem.fallDistance += 1
                lem.state = lem.hasFloater && lem.fallDistance > maxSafeFall ? .floating : .falling
            }

        case .floating:
            let below = lem.y + 1
            if isSolid(tile(below, col)) {
                lem.state = .walking
                lem.fallDistance = 0
            } else {
                lem.y = below
            }

        case .walking:
            lem.actionProgress += 1
            if lem.actionProgress >= walkTicksPerStep {
                lem.actionProgress = 0
                walk(&lem)
            }

        case .blocking:
            break // stands still forever, acts as an obstacle in walk()

        case .building(let steps):
            let dir = lem.facingRight ? 1 : -1
            let frontCol = col + dir
            if steps <= 0 {
                lem.state = .walking
            } else if lem.y - 1 >= 0 && isSolid(tile(lem.y - 1, frontCol)) {
                // Blocked by a real wall/steel ahead — the original stops the builder
                // here. `lem.y - 1 >= 0` matters because `tile()` returns `.steel` for
                // any out-of-bounds row (including above the map), so a tall bridge
                // climbing toward row 0 would otherwise read the open sky above the
                // level as a wall and stop dead, stranding the lemming mid-air.
                lem.state = .walking
            } else {
                setTile(lem.y, frontCol, .dirt)
                lem.x += Double(dir) * 0.5
                lem.state = .building(stepsLeft: steps - 1)
                // Never climb above row 0 — a staircase that reached the top of
                // the map used to keep decrementing y past it, leaving the
                // lemming permanently stuck at an invalid negative row.
                if steps % 2 == 0 && lem.y > 0 { lem.y -= 1 }
            }

        case .basher(let steps):
            lem.actionProgress += 1
            guard lem.actionProgress >= walkTicksPerStep else { break }
            lem.actionProgress = 0
            let dir = lem.facingRight ? 1 : -1
            let frontCol = col + dir
            let noFloorAhead = !isSolid(tile(lem.y + 1, frontCol))
            if steps <= 0 || tile(lem.y, frontCol) == .steel || noFloorAhead {
                lem.state = .walking
            } else if !isSolid(tile(lem.y, frontCol)) {
                lem.state = .walking
            } else {
                setTile(lem.y, frontCol, .empty)
                lem.x += Double(dir)
                lem.state = .basher(stepsLeft: steps - 1)
            }

        case .miner(let steps):
            lem.actionProgress += 1
            guard lem.actionProgress >= walkTicksPerStep else { break }
            lem.actionProgress = 0
            let dir = lem.facingRight ? 1 : -1
            let frontCol = col + dir
            if steps <= 0 || tile(lem.y, frontCol) == .steel || tile(lem.y + 1, frontCol) == .steel {
                lem.state = .walking
            } else {
                setTile(lem.y, frontCol, .empty)
                setTile(lem.y + 1, frontCol, .empty)
                lem.x += Double(dir)
                lem.y += 1
                lem.state = .miner(stepsLeft: steps - 1)
            }

        case .digger(let steps):
            if steps <= 0 || tile(lem.y + 1, col) == .steel {
                lem.state = .falling
            } else {
                setTile(lem.y + 1, col, .empty)
                lem.y += 1
                lem.state = .digger(stepsLeft: steps - 1)
            }

        case .climbing:
            let above = lem.y - 1
            if !isSolid(tile(above, col)) {
                lem.y = above
                lem.state = .walking
            } else if above <= 0 {
                lem.facingRight.toggle()
                lem.state = .walking
            } else {
                lem.y = above
            }

        case .exploding(let ticksLeft):
            if ticksLeft <= 0 {
                for dr in -1...1 {
                    for dc in -1...1 {
                        setTile(lem.y + dr, col + dc, .empty)
                    }
                }
                lem.state = .dead
                deadCount += 1
            } else {
                lem.state = .exploding(ticksLeft: ticksLeft - 1)
            }

        case .saved, .dead:
            break
        }
    }

    private func walk(_ lem: inout Lemming) {
        let col = Int(lem.x.rounded())
        let dir = lem.facingRight ? 1 : -1
        let frontCol = col + dir

        let blockedByLemming = lemmings.contains { $0.y == lem.y && Int($0.x.rounded()) == frontCol && $0.state == .blocking }
        if blockedByLemming {
            lem.facingRight.toggle()
            return
        }

        let below = lem.y + 1
        if !isSolid(tile(below, col)) {
            lem.state = .falling
            return
        }

        if isSolid(tile(lem.y, frontCol)) {
            if isSolid(tile(lem.y - 1, frontCol)) {
                if lem.hasClimber {
                    lem.state = .climbing
                } else {
                    lem.facingRight.toggle()
                }
            } else {
                lem.y -= 1
                lem.x += Double(dir)
            }
        } else {
            lem.x += Double(dir)
        }
    }
}
