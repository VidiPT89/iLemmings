import Foundation

/// Pure-Swift, deterministic tick-based simulation. No UI/rendering here —
/// `GameScene` (SpriteKit) reads this engine's published state to draw frames.
final class GameEngine: ObservableObject {
    private(set) var level: LevelDefinition
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
    /// Classic 1-99 release rate: higher lets lemmings out faster.
    @Published private(set) var releaseRate: Int
    /// 1 = normal, 3 = fast-forward like the original speed control.
    @Published var gameSpeed: Int = 1

    private var tickCounter = 0
    private var nextID = 0
    /// Ticks until the next lemming drops. Starts long enough to cover the
    /// hatch opening, then reloads from the release rate after every spawn.
    private var releaseCountdown = GameTuning.hatchOpenTicks + GameTuning.firstLemmingDelayTicks
    private var nukeArmed = false
    private var nextNukeIndex = 0
    private var entrance: (row: Int, col: Int)

    var ticksPerSecond: Double { 20 }

    init(level: LevelDefinition) {
        self.level = level
        let parsedGrid = level.rows.map { row in row.compactMap { Tile(rawValue: $0) } }
        self.grid = parsedGrid
        self.secondsRemaining = level.timeLimitSeconds
        self.skillInventory = level.skillCounts
        self.releaseRate = level.minReleaseRate
        self.entrance = Self.findEntrance(in: parsedGrid)
    }

    private static func findEntrance(in grid: [[Tile]]) -> (row: Int, col: Int) {
        var found = (row: 1, col: 1)
        for (r, row) in grid.enumerated() {
            for (c, t) in row.enumerated() where t == .entrance {
                found = (r, c)
            }
        }
        return found
    }

    /// Swaps in a different level on the *same* instance, then resets.
    ///
    /// Playing on from the result screen has to reuse this engine: `@StateObject`
    /// has no setter for the object itself, so building a new engine would
    /// leave the HUD and the win/lose bindings attached to the old one.
    func load(_ level: LevelDefinition) {
        self.level = level
        self.entrance = Self.findEntrance(in: level.rows.map { row in row.compactMap { Tile(rawValue: $0) } })
        reset()
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
        releaseCountdown = GameTuning.hatchOpenTicks + GameTuning.firstLemmingDelayTicks
        nukeArmed = false
        nextNukeIndex = 0
    }

    var width: Int { level.width }
    var height: Int { level.height }
    var entranceColumn: Int { entrance.col }
    var entranceRow: Int { entrance.row }
    /// The scene swings the hatch doors open off this, so they stay in step
    /// with the simulation through pauses and fast-forward.
    var isHatchOpen: Bool { tickCounter >= GameTuning.hatchOpenTicks }

    /// Above the level is a ceiling; past either side or below the floor is
    /// open air, and a lemming that ends up there is lost — as in the
    /// original. Treating everything outside as steel gave every level an
    /// invisible floor to land on and invisible walls to turn around at.
    func tile(_ row: Int, _ col: Int) -> Tile {
        if row < 0 { return .steel }
        guard row < height, col >= 0, col < width else { return .empty }
        return grid[row][col]
    }

    func setTile(_ row: Int, _ col: Int, _ tile: Tile) {
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

    /// Attempts to assign the currently selected skill to the lemming with
    /// this id, following the original's rules (Lemmix `AssignSkill`): the
    /// digging/building jobs can be handed to any lemming working on the
    /// ground — so a Digger can be switched to a Builder mid-hole — but not
    /// to one that is falling, climbing, floating or blocking.
    /// Shared by assignment and hit testing: an ineligible lemming must not
    /// hide an eligible neighbour under the same cursor.
    func canAssign(_ skill: LemSkill, to lem: Lemming) -> Bool {
        guard !isWon, !isLost, lem.canReceiveSkill,
              (skillInventory[skill] ?? 0) > 0 else { return false }
        switch skill {
        case .climber: return !lem.hasClimber
        case .floater: return !lem.hasFloater
        case .bomber: return lem.countdownTicks == 0
        case .blocker:
            return Self.isWorkingOnTheGround(lem.state) && !lemmings.contains {
                $0.id != lem.id && $0.state == .blocking && $0.y == lem.y
                    && Int($0.x.rounded()) == Int(lem.x.rounded())
            }
        case .builder:
            if case .building = lem.state { return false }
            return Self.isWorkingOnTheGround(lem.state)
        case .basher: return lem.state != .basher && Self.isWorkingOnTheGround(lem.state)
        case .miner: return lem.state != .miner && Self.isWorkingOnTheGround(lem.state)
        case .digger: return lem.state != .digger && Self.isWorkingOnTheGround(lem.state)
        }
    }

    func applySelectedSkill(to lemmingID: Int) {
        guard let skill = selectedSkill,
              let idx = lemmings.firstIndex(where: { $0.id == lemmingID }),
              canAssign(skill, to: lemmings[idx]) else { return }
        var lem = lemmings[idx]
        switch skill {
        case .climber: lem.hasClimber = true
        case .floater: lem.hasFloater = true
        case .bomber: lem.countdownTicks = GameTuning.bomberFuseTicks
        case .blocker: lem.state = .blocking
        case .builder: lem.state = .building(stepsLeft: 12)
        case .basher: lem.state = .basher
        case .miner: lem.state = .miner
        case .digger: lem.state = .digger
        }
        if [.blocker, .builder, .basher, .miner, .digger].contains(skill) {
            lem.actionProgress = 0
        }
        lemmings[idx] = lem
        skillInventory[skill, default: 0] -= 1
        // Keep the slot selected even at zero, like a physical control panel.
    }

    private static func isWorkingOnTheGround(_ state: LemState) -> Bool {
        switch state {
        case .walking, .shrugging, .building, .basher, .miner, .digger: return true
        default: return false
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

        if spawnedCount < level.totalLemmings, !nukeArmed {
            releaseCountdown -= 1
            if releaseCountdown <= 0 {
                spawn()
                releaseCountdown = GameTuning.releaseIntervalTicks(rate: releaseRate)
            }
        }

        if nukeArmed {
            armNextNukeTarget()
        }

        // Stepped on a local copy and published once: going through the
        // @Published array element by element copied the whole crowd and
        // fired a change notification for every lemming, every tick.
        // `walk()` reads `lemmings` for blockers, which is this tick's
        // starting positions — exactly what it needs.
        var crowd = lemmings
        for i in crowd.indices {
            stepLemming(&crowd[i])
        }
        // A builder can lay a brick right where another lemming is standing.
        // That lemming ends up on top of the new brick, as in the original,
        // rather than buried inside it. The builder only lays a brick with
        // clear space above it, so there is always room to step up.
        for i in crowd.indices where crowd[i].isAlive {
            let col = Int(crowd[i].x.rounded())
            if tile(crowd[i].y, col).isSolid, !tile(crowd[i].y - 1, col).isSolid {
                crowd[i].y -= 1
            }
        }
        lemmings = crowd

        evaluateEndConditions()
    }

    /// Original nuke arms one living lemming per tick, not the whole crowd
    /// in a single frame. Lemmings already splatting or drowning are skipped:
    /// arming them used to bring them back as an Oh-No, and count them dead
    /// a second time when they blew up.
    private func armNextNukeTarget() {
        while nextNukeIndex < lemmings.count {
            let i = nextNukeIndex
            nextNukeIndex += 1
            guard lemmings[i].canReceiveSkill, lemmings[i].countdownTicks == 0 else { continue }
            lemmings[i].countdownTicks = GameTuning.bomberFuseTicks
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
        // Nuke stops the hatch, so the rest of the crowd is never coming out:
        // without it in this condition, nuking early left the level running
        // against a full clock with nothing alive on screen.
        let everyoneIsOut = spawnedCount >= level.totalLemmings || nukeArmed
        let allLemmingsResolved = everyoneIsOut && lemmings.allSatisfy { !$0.isAlive }
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

    // MARK: - Hooks for the lemming state machine (GameEngineLemmings.swift)
    //
    // Internal rather than private only because Swift's `private` is
    // file-scoped and the state machine lives in its own file.

    func countDeath() { deadCount += 1 }
    func countSaved() { savedCount += 1 }
}
