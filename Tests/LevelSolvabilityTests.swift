import XCTest
@testable import iLemmings

/// Each built-in level must have at least one line that saves the quota.
final class LevelSolvabilityTests: XCTestCase {

    func testEveryBuiltInLevelIsWinnable() {
        for level in LevelLibrary.all {
            let engine = play(level)
            XCTAssertGreaterThanOrEqual(
                engine.savedCount,
                level.neededToSave,
                "\(level.id) (\(level.nameKey.rawValue)): saved \(engine.savedCount)/\(level.neededToSave), dead \(engine.deadCount)"
            )
        }
    }

    private func play(_ level: LevelDefinition) -> GameEngine {
        let engine = GameEngine(level: level)
        let limit = level.timeLimitSeconds * 20 + 800
        for _ in 0..<limit {
            if engine.isWon || engine.isLost { break }
            engine.tick()
            assertNobodyIsInsideTheGround(engine, levelID: level.id)
            act(engine, levelID: level.id)
        }
        return engine
    }

    /// Only Basher, Miner and Digger are ever inside solid terrain. Anyone
    /// else standing in dirt or steel is being drawn buried up to the neck,
    /// which is what it looks like on screen.
    private func assertNobodyIsInsideTheGround(_ engine: GameEngine, levelID: String) {
        for lem in engine.lemmings {
            switch lem.state {
            case .basher, .miner, .digger, .dead, .saved:
                continue
            default:
                break
            }
            let col = Int(lem.x.rounded())
            let here = engine.tile(lem.y, col)
            XCTAssertFalse(
                isSolid(here),
                "\(levelID): a \(lem.state) lemming is inside \(here) at row \(lem.y), col \(col)"
            )
        }
    }

    private func isSolid(_ t: Tile) -> Bool { t == .dirt || t == .steel }

    @discardableResult
    private func assign(_ engine: GameEngine, _ skill: LemSkill, to id: Int) -> Bool {
        let before = engine.skillInventory[skill] ?? 0
        guard before > 0 else { return false }
        engine.selectSkill(skill)
        engine.applySelectedSkill(to: id)
        return (engine.skillInventory[skill] ?? 0) < before
    }

    private func act(_ engine: GameEngine, levelID: String) {
        for lem in engine.lemmings {
            switch lem.state {
            case .falling, .floating:
                assign(engine, .floater, to: lem.id)
            default:
                break
            }
        }

        let walkers = engine.lemmings.filter { $0.state == .walking }

        if levelID == "level6" {
            for lem in walkers where !lem.hasClimber {
                assign(engine, .climber, to: lem.id)
            }
            return
        }

        if levelID == "level2" {
            for lem in walkers {
                let col = Int(lem.x.rounded())
                let dir = lem.facingRight ? 1 : -1
                let front = engine.tile(lem.y, col + dir)
                let up = engine.tile(lem.y - 1, col + dir)
                if isSolid(front) && isSolid(up) {
                    assign(engine, .basher, to: lem.id)
                    if !lem.hasClimber { assign(engine, .climber, to: lem.id) }
                }
            }
            return
        }

        guard let lead = walkers.max(by: { $0.x < $1.x }) else { return }
        let col = Int(lead.x.rounded())
        let dir = lead.facingRight ? 1 : -1
        let front = col + dir
        let frontTile = engine.tile(lead.y, front)
        let belowFront = engine.tile(lead.y + 1, front)
        if frontTile == .trap || frontTile == .water || !isSolid(belowFront) {
            assign(engine, .builder, to: lead.id)
        }
    }
}
