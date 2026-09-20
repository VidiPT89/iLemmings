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
    /// Classic 1-99 release rate (LemmingsJS `GameVictoryCondition`).
    @Published private(set) var releaseRate: Int
    /// 1 = normal, 3 = fast-forward like the original speed control.
    @Published var gameSpeed: Int = 1

    private var tickCounter = 0
    private var nextID = 0
    private var releaseTickIndex = 0
    private var nukeArmed = false
    private var nextNukeIndex = 0
    private let entrance: (row: Int, col: Int)
    private let maxSafeFall = 6
    private let bomberFuseTicks = 100
    private let ohNoTicks = 16
    private let fallTicksPerStep = 4
    private let floatTicksPerStep = 8
    private let climbTicksPerStep = 8
    /// Derived from the original's actual source (LemmingsJS's ActionWalkSystem):
    /// it moves 1px/tick at a 60ms tick (~16.67 ticks/sec) — about 0.6s to
    /// cross one lemming-height of ground. At this engine's 20 ticks/sec,
    /// one tile every 12 ticks lands on the same ~0.6s pace. Also used for
    /// Digger, whose original cadence (1 row/8 ticks ≈ 0.48s) is close to
    /// walking speed.
    private let walkTicksPerStep = 12
    /// Basher/Miner/Builder tunnel through solid ground far slower than a
    /// lemming walks — the original's ActionBashSystem/ActionBuildSystem
    /// only advance once every 16-24 ticks (vs. walking's every tick).
    private let workTicksPerStep = 24

    var ticksPerSecond: Double { 20 }

    init(level: LevelDefinition) {
        self.level = level
        let parsedGrid = level.rows.map { row in row.compactMap { Tile(rawValue: $0) } }
        self.grid = parsedGrid
        self.secondsRemaining = level.timeLimitSeconds
        self.skillInventory = level.skillCounts
        self.releaseRate = level.minReleaseRate
        self.releaseTickIndex = level.minReleaseRate - 30
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
        releaseRate = level.minReleaseRate
        gameSpeed = 1
        tickCounter = 0
        nextID = 0
        releaseTickIndex = level.minReleaseRate - 30
        nukeArmed = false
        nextNukeIndex = 0
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
        // Original never toggles a skill off: clicking the same button again
        // keeps it selected so you can assign it to many lemmings in a row.
        selectedSkill = skill
    }

    func changeReleaseRate(_ delta: Int) {
        let next = releaseRate + delta
        releaseRate = min(99, max(level.minReleaseRate, next))
    }

    func toggleFastForward() {
        gameSpeed = gameSpeed == 1 ? 3 : 1
    }

    /// Attempts to assign the currently selected skill to the lemming at index.
    func applySelectedSkill(to lemmingID: Int) {
        guard let skill = selectedSkill,
              let idx = lemmings.firstIndex(where: { $0.id == lemmingID }),
              (skillInventory[skill] ?? 0) > 0 else { return }
        var lem = lemmings[idx]
        guard lem.canReceiveSkill else { return }

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
            // The original always builds exactly 12 bricks before reverting to a walker.
            guard lem.state == .walking else { return }
            lem.state = .building(stepsLeft: 12)
        case .basher:
            // Unlimited, like the original — stops at steel, open air, or a missing floor.
            guard lem.state == .walking else { return }
            lem.state = .basher
        case .miner:
            guard lem.state == .walking else { return }
            lem.state = .miner
        case .digger:
            guard lem.state == .walking else { return }
            lem.state = .digger
        case .bomber:
            guard lem.countdownTicks == 0 else { return }
            lem.countdownTicks = bomberFuseTicks
        }

        lemmings[idx] = lem
        let remaining = (skillInventory[skill] ?? 1) - 1
        skillInventory[skill] = remaining
        if remaining <= 0, selectedSkill == skill {
            selectedSkill = nil
        }
    }

    /// Classic Nuke: arms one living lemming per tick, like LemmingsJS.
    func nukeAll() {
        nukeArmed = true
        nextNukeIndex = 0
    }

    func tick() {
        guard !isWon, !isLost else { return }
        tickCounter += 1

        if tickCounter % Int(ticksPerSecond) == 0, secondsRemaining > 0 {
            secondsRemaining -= 1
        }

        // LemmingsJS: spawn when releaseTickIndex >= (104 - releaseRate).
        if spawnedCount < level.totalLemmings, !nukeArmed {
            releaseTickIndex += 1
            if releaseTickIndex >= (104 - releaseRate) {
                releaseTickIndex = 0
                spawn()
            }
        }

        if nukeArmed {
            armNextNukeTarget()
        }

        for i in lemmings.indices {
            stepLemming(&lemmings[i])
        }

        evaluateEndConditions()
    }

    /// Original nuke arms one living lemming per tick, not the whole crowd
    /// in a single frame.
    private func armNextNukeTarget() {
        while nextNukeIndex < lemmings.count {
            let i = nextNukeIndex
            nextNukeIndex += 1
            guard lemmings[i].isAlive, lemmings[i].countdownTicks == 0 else { continue }
            if case .ohNo = lemmings[i].state { continue }
            lemmings[i].countdownTicks = bomberFuseTicks
            return
        }
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
        let finishingAnimation = lemmings.contains {
            switch $0.state {
            case .splatting, .drowning, .ohNo: return true
            default: return false
            }
        }
        // Wait for splat/Oh-No so the last death is visible; otherwise end
        // when everyone is resolved or the clock hits zero.
        guard allLemmingsResolved || (secondsRemaining <= 0 && !finishingAnimation) else { return }
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

        if lem.countdownTicks > 0 {
            lem.countdownTicks -= 1
            if lem.countdownTicks == 0 {
                lem.state = .ohNo(ticksLeft: ohNoTicks)
                return
            }
        }

        if case .drowning(let ticksLeft) = lem.state {
            lem.state = ticksLeft <= 0 ? .dead : .drowning(ticksLeft: ticksLeft - 1)
            return
        }
        if case .splatting(let ticksLeft) = lem.state {
            lem.state = ticksLeft <= 0 ? .dead : .splatting(ticksLeft: ticksLeft - 1)
            return
        }
        if case .shrugging(let ticksLeft) = lem.state {
            lem.state = ticksLeft <= 0 ? .walking : .shrugging(ticksLeft: ticksLeft - 1)
            return
        }

        if tile(lem.y, col) == .water {
            drown(&lem)
            return
        }
        if tile(lem.y, col) == .trap {
            splat(&lem)
            return
        }
        if tile(lem.y, col) == .exit {
            lem.state = .saved
            savedCount += 1
            return
        }

        switch lem.state {
        case .falling:
            lem.actionProgress += 1
            guard lem.actionProgress >= fallTicksPerStep else { break }
            lem.actionProgress = 0
            let below = lem.y + 1
            if isSolid(tile(below, col)) {
                if lem.fallDistance > maxSafeFall && !lem.hasFloater {
                    splat(&lem)
                } else {
                    lem.state = .walking
                    lem.fallDistance = 0
                }
            } else {
                lem.y = below
                lem.fallDistance += 1
                lem.state = lem.hasFloater && lem.fallDistance > 1 ? .floating : .falling
            }

        case .floating:
            lem.actionProgress += 1
            guard lem.actionProgress >= floatTicksPerStep else { break }
            lem.actionProgress = 0
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
            // Stands still indefinitely, acting as an obstacle in walk() — but
            // only while it still has ground. Every other state re-checks its
            // own footing as it moves; a blocker never moves, so without this
            // a Miner/Basher/Bomber clearing the tile underneath left it
            // hanging in mid-air, still turning walkers around.
            if !isSolid(tile(lem.y + 1, col)) {
                lem.state = .falling
                lem.actionProgress = 0
                lem.fallDistance = 0
            }

        case .building(let steps):
            lem.actionProgress += 1
            guard lem.actionProgress >= workTicksPerStep else { break }
            lem.actionProgress = 0
            let dir = lem.facingRight ? 1 : -1
            let frontCol = col + dir
            // Each step moves the lemming one tile forward and one row up,
            // to (lem.y - 1, frontCol); the tile that supports that new spot
            // is one row *below* it (this engine's convention throughout:
            // footing for row R is at row R+1), which is exactly the OLD
            // row, at the NEW column — so the brick goes at (lem.y, frontCol)
            // before y is decremented. The previous version moved x by only
            // 0.5/step and y only every other step, which desynced brick
            // placement from the lemming's actual column once climbing got
            // capped at row 0 — bricks kept landing one row too low to
            // support the still-advancing lemming, so it ended up walking
            // over nothing until it fell. Moving a full tile every step
            // keeps brick and position locked together, every step.
            if steps <= 0 {
                lem.state = .shrugging(ticksLeft: 16)
            } else if lem.y - 1 < 0 {
                lem.state = .shrugging(ticksLeft: 16)
            } else if isSolid(tile(lem.y - 1, frontCol)) {
                lem.state = .shrugging(ticksLeft: 16)
            } else {
                setTile(lem.y, frontCol, .dirt)
                lem.y -= 1
                lem.x = Double(frontCol)
                lem.state = .building(stepsLeft: steps - 1)
            }

        case .basher:
            lem.actionProgress += 1
            guard lem.actionProgress >= workTicksPerStep else { break }
            lem.actionProgress = 0
            let dir = lem.facingRight ? 1 : -1
            let frontCol = col + dir
            let noFloorAhead = !isSolid(tile(lem.y + 1, frontCol))
            if tile(lem.y, frontCol) == .steel || noFloorAhead {
                lem.state = .walking
            } else if !isSolid(tile(lem.y, frontCol)) {
                lem.state = .walking
            } else {
                setTile(lem.y, frontCol, .empty)
                lem.x = Double(frontCol)
            }

        case .miner:
            lem.actionProgress += 1
            guard lem.actionProgress >= workTicksPerStep else { break }
            lem.actionProgress = 0
            let dir = lem.facingRight ? 1 : -1
            let frontCol = col + dir
            if tile(lem.y, frontCol) == .steel || tile(lem.y + 1, frontCol) == .steel {
                lem.state = .walking
            } else {
                setTile(lem.y, frontCol, .empty)
                setTile(lem.y + 1, frontCol, .empty)
                lem.x = Double(frontCol)
                lem.y += 1
            }

        case .digger:
            lem.actionProgress += 1
            guard lem.actionProgress >= walkTicksPerStep else { break }
            lem.actionProgress = 0
            let below = tile(lem.y + 1, col)
            if below == .steel || !isSolid(below) {
                lem.state = .falling
                lem.actionProgress = 0
            } else {
                setTile(lem.y + 1, col, .empty)
                lem.y += 1
            }

        case .climbing:
            lem.actionProgress += 1
            guard lem.actionProgress >= climbTicksPerStep else { break }
            lem.actionProgress = 0
            let dir = lem.facingRight ? 1 : -1
            let wallCol = col + dir
            let above = lem.y - 1
            if above < 0 {
                lem.facingRight.toggle()
                lem.state = .walking
            } else if isSolid(tile(above, wallCol)) {
                lem.y = above
            } else {
                lem.y = above
                lem.x = Double(wallCol)
                lem.state = .walking
            }

        case .ohNo(let ticksLeft):
            if ticksLeft <= 0 {
                explode(atRow: lem.y, col: col)
                lem.state = .dead
                deadCount += 1
            } else {
                lem.state = .ohNo(ticksLeft: ticksLeft - 1)
            }

        case .shrugging, .splatting, .drowning, .saved, .dead:
            break
        }
    }

    private func drown(_ lem: inout Lemming) {
        guard lem.isAlive else { return }
        if case .drowning = lem.state { return }
        if case .splatting = lem.state { return }
        lem.state = .drowning(ticksLeft: 16)
        lem.countdownTicks = 0
        deadCount += 1
    }

    private func splat(_ lem: inout Lemming) {
        guard lem.isAlive else { return }
        if case .splatting = lem.state { return }
        lem.state = .splatting(ticksLeft: 16)
        lem.countdownTicks = 0
        deadCount += 1
    }

    /// Crater clears diggable ground only. Steel, exits and hatches stay,
    /// matching LemmingsJS `clearGroundWithMask` (steel is not terrain).
    private func explode(atRow row: Int, col: Int) {
        for dr in -1...1 {
            for dc in -1...1 {
                let t = tile(row + dr, col + dc)
                if t == .dirt || t == .trap {
                    setTile(row + dr, col + dc, .empty)
                }
            }
        }
    }

    private func walk(_ lem: inout Lemming) {
        let col = Int(lem.x.rounded())
        let dir = lem.facingRight ? 1 : -1
        let frontCol = col + dir

        let blockedByLemming = lemmings.contains { other in
            guard other.id != lem.id, other.state == .blocking, other.y == lem.y else { return false }
            let otherCol = Int(other.x.rounded())
            return otherCol == col || otherCol == frontCol
        }
        if blockedByLemming {
            lem.facingRight.toggle()
            return
        }

        let below = lem.y + 1
        if !isSolid(tile(below, col)) {
            lem.state = .falling
            lem.actionProgress = 0
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
