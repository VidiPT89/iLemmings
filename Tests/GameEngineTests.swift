import XCTest
@testable import iLemmings

final class GameEngineTests: XCTestCase {

    private func tinyLevel(
        rows: [String],
        skills: [LemSkill: Int] = [:],
        total: Int = 1,
        need: Int = 1,
        time: Int = 60
    ) -> LevelDefinition {
        LevelDefinition(
            id: "test",
            nameKey: .levelGreenHills,
            pack: .fun,
            rows: rows,
            totalLemmings: total,
            neededToSave: need,
            spawnIntervalTicks: 20,
            timeLimitSeconds: time,
            skillCounts: skills
        )
    }

    private func isSolid(_ t: Tile) -> Bool { t == .dirt || t == .steel }

    /// Walking off a ledge has to start the fall on the same tick as the
    /// step that left the ground. Re-checking the footing only on the *next*
    /// walk step left the lemming standing on thin air for the whole gap
    /// between steps, which is plainly visible on screen.
    func testWalkingOffALedgeStartsFallingImmediately() {
        let level = tinyLevel(rows: [
            "E.....",
            "###...",
            "###...",
            "SSSSSS",
        ])
        let engine = GameEngine(level: level)
        var sawWalkerOverThinAir = false

        for _ in 0..<400 {
            engine.tick()
            for lem in engine.lemmings where lem.state == .walking {
                let col = Int(lem.x.rounded())
                if !isSolid(engine.tile(lem.y + 1, col)) {
                    sawWalkerOverThinAir = true
                }
            }
        }

        XCTAssertFalse(
            sawWalkerOverThinAir,
            "a lemming was in .walking with nothing under it — it should already be .falling"
        )
    }

    /// Finishing a level plays on into the next one on the same engine
    /// instance (`@StateObject` cannot be swapped out), so `load` has to
    /// bring across the new grid, entrance, skills and clock — and clear
    /// everything the finished level left behind.
    func testLoadingAnotherLevelReplacesTheWholeGameState() {
        let first = tinyLevel(rows: ["E..X", "####"], skills: [.digger: 1], total: 1, time: 60)
        let engine = GameEngine(level: first)
        for _ in 0..<600 { engine.tick() }
        XCTAssertTrue(engine.isWon || engine.isLost, "the first level should have finished")

        let second = tinyLevel(
            rows: ["..E...", "######", "....X.", "SSSSSS"],
            skills: [.builder: 3],
            total: 4,
            need: 2,
            time: 90
        )
        engine.load(second)

        XCTAssertFalse(engine.isWon)
        XCTAssertFalse(engine.isLost)
        XCTAssertEqual(engine.savedCount, 0)
        XCTAssertEqual(engine.deadCount, 0)
        XCTAssertEqual(engine.spawnedCount, 0)
        XCTAssertTrue(engine.lemmings.isEmpty)
        XCTAssertEqual(engine.secondsRemaining, 90)
        XCTAssertEqual(engine.skillInventory[.builder], 3)
        XCTAssertNil(engine.skillInventory[.digger])
        XCTAssertEqual(engine.width, 6)
        XCTAssertEqual(engine.height, 4)
        XCTAssertEqual(engine.entranceRow, 0)
        XCTAssertEqual(engine.entranceColumn, 2)

        // And it actually runs: lemmings come out of the *new* hatch.
        for _ in 0..<200 { engine.tick() }
        XCTAssertGreaterThan(engine.spawnedCount, 0)
    }

    /// Nuke shuts the hatch, so the level has to end once the lemmings that
    /// did come out are resolved. Waiting for the full crowd to spawn left
    /// the player staring at an empty level until the clock ran out.
    func testNukeEndsTheLevelWithoutWaitingForTheClock() {
        let level = tinyLevel(rows: ["E....X", "######"], total: 20, need: 20, time: 300)
        let engine = GameEngine(level: level)
        for _ in 0..<60 { engine.tick() }
        XCTAssertGreaterThan(engine.spawnedCount, 0)
        XCTAssertLessThan(engine.spawnedCount, level.totalLemmings)

        engine.nukeAll()
        for _ in 0..<400 { engine.tick() }

        XCTAssertTrue(engine.isWon || engine.isLost, "the level should be over once the nuke resolves")
        XCTAssertGreaterThan(engine.secondsRemaining, 0, "it should not have had to wait out the clock")
    }

    func testStarsThresholds() {
        let level = tinyLevel(rows: ["E..X", "####"])
        XCTAssertEqual(level.stars(saved: 0, secondsRemaining: 60), 0)
        XCTAssertEqual(level.stars(saved: 1, secondsRemaining: 0), 3)
    }

    func testReleaseRateFloorMatchesLemmingsJSFormula() {
        let level = tinyLevel(rows: ["E..X", "####"])
        XCTAssertEqual(level.minReleaseRate, min(99, max(1, 104 - 20)))
    }

    func testWaterDrownsEvenWithFloater() {
        let level = tinyLevel(
            rows: [
                "E...",
                "....",
                "WWWW",
                "SSSS",
            ],
            skills: [.floater: 1],
            time: 30
        )
        let engine = GameEngine(level: level)
        engine.selectSkill(.floater)
        for _ in 0..<400 {
            engine.tick()
            if let id = engine.lemmings.first?.id {
                engine.applySelectedSkill(to: id)
            }
        }
        XCTAssertGreaterThan(engine.deadCount, 0)
        XCTAssertEqual(engine.savedCount, 0)
    }

    func testBomberDoesNotDestroySteel() {
        let level = tinyLevel(
            rows: [
                "E...",
                "SSSS",
                "...X",
                "SSSS",
            ],
            skills: [.bomber: 1],
            time: 40
        )
        let engine = GameEngine(level: level)
        var armed = false
        for _ in 0..<800 {
            engine.tick()
            if !armed, let lem = engine.lemmings.first, lem.state == .walking {
                engine.selectSkill(.bomber)
                engine.applySelectedSkill(to: lem.id)
                armed = true
            }
        }
        XCTAssertEqual(engine.tile(1, 0), .steel)
        XCTAssertEqual(engine.tile(1, 1), .steel)
    }

    func testBlockerTurnsWalker() {
        let level = tinyLevel(
            rows: [
                "E........X",
                "##########",
            ],
            skills: [.blocker: 1],
            total: 2,
            need: 1,
            time: 40
        )
        let engine = GameEngine(level: level)
        var blocked = false
        for _ in 0..<200 {
            engine.tick()
            if !blocked, let lem = engine.lemmings.first(where: { $0.state == .walking }) {
                engine.selectSkill(.blocker)
                engine.applySelectedSkill(to: lem.id)
                blocked = true
            }
        }
        XCTAssertTrue(blocked)
        XCTAssertTrue(engine.lemmings.contains { $0.state == .blocking })
        XCTAssertGreaterThanOrEqual(engine.spawnedCount, 2)
    }

    /// A blocker whose footing is mined away falls, like the original — it
    /// does not hang in mid-air still turning walkers around.
    func testBlockerFallsWhenItsFootingIsMinedAway() {
        let level = tinyLevel(
            rows: [
                "E.........",
                "##########",
                "##########",
                "SSSSSSSSSS",
            ],
            skills: [.blocker: 1, .miner: 1],
            total: 2,
            need: 1,
            time: 120
        )
        let engine = GameEngine(level: level)
        var blocker: Lemming?
        var minerAssigned = false

        for _ in 0..<600 {
            engine.tick()

            if blocker == nil,
               let lem = engine.lemmings.first(where: { $0.state == .walking && Int($0.x.rounded()) >= 5 }) {
                engine.selectSkill(.blocker)
                engine.applySelectedSkill(to: lem.id)
                blocker = engine.lemmings.first { $0.id == lem.id }
                continue
            }

            // A Miner one tile behind the blocker clears the tile the blocker
            // is standing on with its very first stroke.
            if let blocker, !minerAssigned {
                let target = engine.lemmings.first {
                    $0.id != blocker.id && $0.state == .walking && $0.facingRight
                        && $0.y == blocker.y && Int($0.x.rounded()) == Int(blocker.x.rounded()) - 1
                }
                if let target {
                    engine.selectSkill(.miner)
                    engine.applySelectedSkill(to: target.id)
                    minerAssigned = true
                }
            }

            if minerAssigned, let blocker, !isSolid(engine.tile(blocker.y + 1, Int(blocker.x.rounded()))) {
                break
            }
        }

        guard let blocker else { return XCTFail("no blocker was assigned") }
        XCTAssertTrue(minerAssigned, "the miner was never assigned behind the blocker")
        XCTAssertFalse(
            isSolid(engine.tile(blocker.y + 1, Int(blocker.x.rounded()))),
            "the miner never cleared the blocker's footing"
        )

        engine.tick()
        let after = engine.lemmings.first { $0.id == blocker.id }
        XCTAssertNotEqual(after?.state, .blocking, "blocker kept blocking with no ground under it")
    }

    func testClimberScalesATallWall() {
        let level = tinyLevel(
            rows: [
                "......X",
                "E.S....",
                "..S....",
                "..S....",
                "#######",
            ],
            skills: [.climber: 1],
            time: 90
        )
        let engine = GameEngine(level: level)
        for _ in 0..<2500 {
            engine.tick()
            if let lem = engine.lemmings.first, lem.state == .walking || lem.state == .climbing {
                engine.selectSkill(.climber)
                engine.applySelectedSkill(to: lem.id)
            }
        }
        XCTAssertGreaterThan(engine.savedCount, 0)
    }

    func testNukeStopsTheHatch() {
        let level = tinyLevel(
            rows: ["E...X", "#####"],
            total: 8,
            need: 1,
            time: 40
        )
        let engine = GameEngine(level: level)
        for _ in 0..<5 { engine.tick() }
        let before = engine.spawnedCount
        XCTAssertGreaterThan(before, 0)
        engine.nukeAll()
        for _ in 0..<80 { engine.tick() }
        XCTAssertEqual(engine.spawnedCount, before)
    }

    func testBuiltInLevelsAreWellFormed() {
        for level in LevelLibrary.all {
            XCTAssertTrue(level.rows.allSatisfy { $0.count == level.width }, level.id)
            XCTAssertTrue(level.rows.joined().contains("E"), level.id)
            XCTAssertTrue(level.rows.joined().contains("X"), level.id)
            XCTAssertLessThanOrEqual(level.neededToSave, level.totalLemmings, level.id)
        }
        XCTAssertEqual(LevelLibrary.all.count, 8)
    }
}
