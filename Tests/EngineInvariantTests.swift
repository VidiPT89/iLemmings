import XCTest
@testable import iLemmings

/// Plays every built-in level many times with skills handed out at random,
/// checking after every tick the things that must never happen whatever the
/// player does: a lemming counted twice, one buried in the ground, or a
/// level that never ends.
final class EngineInvariantTests: XCTestCase {

    func testRandomPlayNeverBreaksTheRules() {
        var rng = SeededGenerator(seed: 1991)
        for level in LevelLibrary.all {
            for _ in 0..<25 {
                play(level, rng: &rng)
            }
        }
    }

    private func play(_ level: LevelDefinition, rng: inout SeededGenerator) {
        let engine = GameEngine(level: level)
        let limit = level.timeLimitSeconds * 20 + 400
        var ticks = 0
        let nukeAt = Int.random(in: 0..<(limit * 2), using: &rng)

        while !engine.isWon && !engine.isLost {
            ticks += 1
            guard ticks <= limit else {
                return XCTFail("\(level.id): still running after \(limit) ticks")
            }
            if ticks == nukeAt { engine.nukeAll() }
            if Int.random(in: 0..<12, using: &rng) == 0, !engine.lemmings.isEmpty,
               let skill = LemSkill.allCases.randomElement(using: &rng) {
                let target = engine.lemmings.randomElement(using: &rng)!
                engine.selectSkill(skill)
                engine.applySelectedSkill(to: target.id)
            }
            if Int.random(in: 0..<200, using: &rng) == 0 {
                engine.changeReleaseRate(Int.random(in: -20...40, using: &rng))
            }
            engine.tick()
            check(engine, level: level)
        }
    }

    private func check(_ engine: GameEngine, level: LevelDefinition) {
        var saved = 0, dead = 0
        for lem in engine.lemmings {
            switch lem.state {
            case .saved: saved += 1
            case .dead, .drowning, .splatting: dead += 1
            default:
                // Diggers, miners and bashers included: they always stand in
                // the tile they have just cleared, never inside the ground.
                let tile = engine.tile(lem.y, Int(lem.x.rounded()))
                if tile.isSolid {
                    XCTFail("\(level.id): a \(lem.state) lemming is inside \(tile)")
                }
            }
        }
        XCTAssertEqual(engine.savedCount, saved, level.id)
        XCTAssertEqual(engine.deadCount, dead, level.id)
        XCTAssertEqual(engine.spawnedCount, engine.lemmings.count, level.id)
        XCTAssertLessThanOrEqual(engine.spawnedCount, level.totalLemmings, level.id)
        for (skill, count) in engine.skillInventory {
            XCTAssertGreaterThanOrEqual(count, 0, "\(level.id): \(skill) went negative")
        }
    }
}
