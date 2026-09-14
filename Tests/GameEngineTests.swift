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
            nameKey: "test",
            pack: .fun,
            rows: rows,
            totalLemmings: total,
            neededToSave: need,
            spawnIntervalTicks: 20,
            timeLimitSeconds: time,
            skillCounts: skills
        )
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
