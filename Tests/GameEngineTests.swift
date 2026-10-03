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
            minReleaseRate: 84,
            timeLimitSeconds: time,
            skillCounts: skills
        )
    }

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
                if !engine.tile(lem.y + 1, col).isSolid {
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

    /// "Play" has to move the player along. Picking the target from the
    /// unlock counter meant that once everything was unlocked the counter
    /// saturated and the button reopened the final level for ever.
    func testPlayOpensTheFirstUnfinishedLevel() {
        let ids = LevelLibrary.all.map(\.id)

        // Nothing played yet.
        XCTAssertEqual(LevelLibrary.continueIndex(stars: { _ in 0 }), 0)

        // The first three finished: it moves on to the fourth.
        let firstThree = Set(ids.prefix(3))
        XCTAssertEqual(
            LevelLibrary.continueIndex(stars: { firstThree.contains($0) ? 2 : 0 }),
            3
        )

        // A gap counts: an earlier level left unfinished is picked up again.
        let allButSecond = Set(ids).subtracting([ids[1]])
        XCTAssertEqual(
            LevelLibrary.continueIndex(stars: { allButSecond.contains($0) ? 3 : 0 }),
            1
        )

        // Everything done: start the campaign over rather than pinning the
        // button to the last level.
        XCTAssertEqual(LevelLibrary.continueIndex(stars: { _ in 3 }), 0)
    }

    func testStarsThresholds() {
        let level = tinyLevel(rows: ["E..X", "####"])
        XCTAssertEqual(level.stars(saved: 0, secondsRemaining: 60), 0)
        XCTAssertEqual(level.stars(saved: 1, secondsRemaining: 0), 3)
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

            if minerAssigned, let blocker, !engine.tile(blocker.y + 1, Int(blocker.x.rounded())).isSolid {
                break
            }
        }

        guard let blocker else { return XCTFail("no blocker was assigned") }
        XCTAssertTrue(minerAssigned, "the miner was never assigned behind the blocker")
        XCTAssertFalse(
            engine.tile(blocker.y + 1, Int(blocker.x.rounded())).isSolid,
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
                "E.S####",
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
        while engine.spawnedCount == 0 { engine.tick() }
        let before = engine.spawnedCount
        XCTAssertGreaterThan(before, 0)
        engine.nukeAll()
        for _ in 0..<80 { engine.tick() }
        XCTAssertEqual(engine.spawnedCount, before)
    }

    // MARK: - Rules of the original

    private func runUntilDone(_ engine: GameEngine, ticks: Int = 3000, each: (() -> Void)? = nil) {
        for _ in 0..<ticks where !engine.isWon && !engine.isLost {
            engine.tick()
            each?()
        }
    }

    private func assign(_ skill: LemSkill, _ engine: GameEngine, to id: Int) {
        engine.selectSkill(skill)
        engine.applySelectedSkill(to: id)
    }

    /// No lemming may drop out of a hatch whose doors are still shut.
    func testNobodyComesOutBeforeTheHatchOpens() {
        let level = tinyLevel(rows: ["E...X", "#####"], total: 5)
        let engine = GameEngine(level: level)
        while !engine.isHatchOpen {
            engine.tick()
            XCTAssertEqual(engine.spawnedCount, 0)
        }
    }

    /// Faster release rates really do release faster, on the original's curve.
    func testReleaseIntervalFollowsTheOriginalCurve() {
        XCTAssertEqual(GameTuning.releaseIntervalTicks(rate: 1), 64)  // 53 frames
        XCTAssertEqual(GameTuning.releaseIntervalTicks(rate: 99), 5)  // 4 frames
        XCTAssertLessThan(
            GameTuning.releaseIntervalTicks(rate: 80),
            GameTuning.releaseIntervalTicks(rate: 50)
        )
    }

    /// Digging through the bottom of the level is a death, not a landing on
    /// an invisible floor.
    func testDiggingThroughTheBottomOfTheLevelKills() {
        let level = tinyLevel(rows: ["E....", "#####", "#####"], skills: [.digger: 1])
        let engine = GameEngine(level: level)
        runUntilDone(engine) {
            if let lem = engine.lemmings.first, lem.state == .walking {
                self.assign(.digger, engine, to: lem.id)
            }
        }
        XCTAssertEqual(engine.deadCount, 1)
        XCTAssertTrue(engine.isLost)
    }

    /// Walking off the side of the level loses the lemming.
    func testWalkingOffTheSideOfTheLevelKills() {
        let level = tinyLevel(rows: ["E...", "####"])
        let engine = GameEngine(level: level)
        runUntilDone(engine)
        XCTAssertEqual(engine.deadCount, 1)
        XCTAssertEqual(engine.lemmings.first?.state, .dead)
    }

    /// A builder never paves over steel, and walks away when its head hits a
    /// wall instead of shrugging on the spot.
    func testBuilderTurnsAtAWallAndNeverOverwritesSteel() {
        let level = tinyLevel(
            rows: [
                "...S....",
                "E..S....",
                "...S....",
                "########",
            ],
            skills: [.builder: 1],
            time: 30
        )
        let engine = GameEngine(level: level)
        var sawTurnedWalker = false
        runUntilDone(engine) {
            guard let lem = engine.lemmings.first else { return }
            if lem.state == .walking, lem.facingRight, (engine.skillInventory[.builder] ?? 0) > 0 {
                self.assign(.builder, engine, to: lem.id)
            }
            if lem.state == .walking, !lem.facingRight { sawTurnedWalker = true }
        }
        XCTAssertTrue(sawTurnedWalker)
        for r in 0..<3 { XCTAssertEqual(engine.tile(r, 3), .steel) }
    }

    /// A miner that tunnels out into open air falls instead of carving
    /// steps through the sky.
    func testMinerFallsWhenItTunnelsIntoOpenAir() {
        let level = tinyLevel(
            rows: [
                "E.......",
                "###.....",
                "###.....",
                "........",
                "SSSSSSSS",
            ],
            skills: [.miner: 1],
            time: 30
        )
        let engine = GameEngine(level: level)
        var sawFalling = false
        for _ in 0..<600 {
            engine.tick()
            guard let lem = engine.lemmings.first else { continue }
            if lem.state == .walking, (engine.skillInventory[.miner] ?? 0) > 0 {
                assign(.miner, engine, to: lem.id)
            }
            if (engine.skillInventory[.miner] ?? 0) == 0, lem.state == .falling { sawFalling = true }
            if lem.state == .miner {
                XCTAssertTrue(
                    engine.tile(lem.y + 1, Int(lem.x.rounded())).isSolid,
                    "a miner is standing on thin air at row \(lem.y)"
                )
            }
        }
        XCTAssertTrue(sawFalling)
    }

    /// Nuking a lemming that is already drowning must not bring it back as
    /// an Oh-No and count it dead twice.
    func testNukeDoesNotCountADrowningLemmingTwice() {
        let level = tinyLevel(rows: ["E.", "..", "WW", "SS"], total: 1, time: 30)
        let engine = GameEngine(level: level)
        while !engine.lemmings.contains(where: {
            if case .drowning = $0.state { return true } else { return false }
        }) {
            engine.tick()
        }
        engine.nukeAll()
        runUntilDone(engine)
        XCTAssertEqual(engine.deadCount, 1)
        XCTAssertFalse(engine.lemmings.contains { $0.exploded })
    }

    /// Like the original, a digger can be switched straight to a builder.
    func testDiggerCanBeSwitchedToBuilder() {
        let level = tinyLevel(rows: ["E.....", "######", "######", "SSSSSS"], skills: [.digger: 1, .builder: 1])
        let engine = GameEngine(level: level)
        while engine.lemmings.first?.state != .walking { engine.tick() }
        let id = engine.lemmings[0].id
        assign(.digger, engine, to: id)
        XCTAssertEqual(engine.lemmings[0].state, .digger)
        assign(.builder, engine, to: id)
        XCTAssertEqual(engine.lemmings[0].state, .building(stepsLeft: 12))
    }

    /// A bomber whose fuse runs out in mid-air blows up at once, without
    /// stopping for an Oh-No in the sky.
    func testFallingBomberExplodesWithoutOhNo() {
        var rows = ["E..."]
        rows += Array(repeating: "....", count: 40)
        rows.append("SSSS")
        let level = tinyLevel(rows: rows, skills: [.bomber: 1, .floater: 1], time: 60)
        let engine = GameEngine(level: level)
        while engine.lemmings.isEmpty { engine.tick() }
        let id = engine.lemmings[0].id
        assign(.floater, engine, to: id)
        assign(.bomber, engine, to: id)
        var sawOhNo = false
        runUntilDone(engine) {
            if case .ohNo = engine.lemmings[0].state { sawOhNo = true }
        }
        XCTAssertFalse(sawOhNo)
        XCTAssertTrue(engine.lemmings[0].exploded)
    }

    func testExhaustedSkillStaysSelectedAndCannotBeSpentAgain() {
        let engine = GameEngine(level: tinyLevel(rows: ["E...X", "#####"], skills: [.climber: 1]))
        while engine.lemmings.isEmpty { engine.tick() }
        assign(.climber, engine, to: engine.lemmings[0].id)
        XCTAssertEqual(engine.selectedSkill, .climber)
        XCTAssertEqual(engine.skillInventory[.climber], 0)
        engine.applySelectedSkill(to: engine.lemmings[0].id)
        XCTAssertEqual(engine.skillInventory[.climber], 0)
    }

    func testSkillEligibilityMatchesPermanentSkillsAndGroundJobs() {
        let engine = GameEngine(level: tinyLevel(rows: ["E...X", "#####"],
                                                skills: [.climber: 2, .builder: 2, .bomber: 2]))
        var lem = Lemming(id: 0, x: 0, y: 0, state: .falling)
        XCTAssertFalse(engine.canAssign(.builder, to: lem))
        XCTAssertTrue(engine.canAssign(.climber, to: lem))
        lem.hasClimber = true
        XCTAssertFalse(engine.canAssign(.climber, to: lem))
        lem.state = .walking
        XCTAssertTrue(engine.canAssign(.builder, to: lem))
        lem.countdownTicks = 10
        XCTAssertFalse(engine.canAssign(.bomber, to: lem))
        lem.state = .drowning(ticksLeft: 10)
        XCTAssertFalse(engine.canAssign(.builder, to: lem))
    }

    func testExitDoesNotRescueALethalFall() {
        let engine = GameEngine(level: tinyLevel(rows: ["E.X", "###"]))
        var lem = Lemming(id: 0, x: 2, y: 0, state: .falling,
                          fallDistance: GameTuning.maxSafeFall + 1,
                          actionProgress: GameTuning.fallTicksPerStep - 1)
        engine.stepLemming(&lem)
        XCTAssertEqual(engine.savedCount, 0)
        XCTAssertEqual(engine.deadCount, 1)
        if case .splatting = lem.state {} else { XCTFail("lethal fall was rescued") }
    }

    func testSafeLandingAtExitIsRescuedAfterLanding() {
        let engine = GameEngine(level: tinyLevel(rows: ["E.X", "###"]))
        var lem = Lemming(id: 0, x: 2, y: 0, state: .falling,
                          fallDistance: 2, actionProgress: GameTuning.fallTicksPerStep - 1)
        engine.stepLemming(&lem)
        XCTAssertEqual(lem.state, .walking)
        engine.stepLemming(&lem)
        XCTAssertEqual(engine.savedCount, 1)
    }

    func testGroundWorkersFallWhenTheirSupportDisappears() {
        for state: LemState in [.walking, .shrugging(ticksLeft: 16), .basher, .miner, .digger,
                               .building(stepsLeft: 5), .blocking] {
            let engine = GameEngine(level: tinyLevel(rows: ["E...", "....", "####"]))
            var lem = Lemming(id: 0, x: 1, y: 0, state: state)
            engine.stepLemming(&lem)
            XCTAssertEqual(lem.state, .falling, "unsupported \(state)")
            XCTAssertEqual(engine.grid[0][2], .empty, "worker built in the air")
        }
    }

    func testShruggingLemmingStillTriggersWater() {
        let engine = GameEngine(level: tinyLevel(rows: ["EW..", "####"]))
        var lem = Lemming(id: 0, x: 1, y: 0, state: .shrugging(ticksLeft: 16))
        engine.stepLemming(&lem)
        XCTAssertEqual(engine.deadCount, 1)
    }

    func testDeadlineEndsGameEvenDuringDeathAnimation() {
        let level = tinyLevel(rows: ["EW..", "####"], total: 10, time: 4)
        let engine = GameEngine(level: level)
        for _ in 0..<80 { engine.tick() }
        XCTAssertEqual(engine.secondsRemaining, 0)
        XCTAssertTrue(engine.isLost)
        let crowd = engine.lemmings.map(\.state)
        let spawned = engine.spawnedCount
        for _ in 0..<60 { engine.tick() }
        XCTAssertEqual(engine.lemmings.map(\.state), crowd)
        XCTAssertEqual(engine.spawnedCount, spawned)
    }

    func testEveryLocalizedStringExistsInBothLanguages() throws {
        for language in ["pt-PT", "en"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in LocKey.allCases {
                let value = bundle.localizedString(forKey: key.rawValue, value: "MISSING", table: "Localizable")
                XCTAssertNotEqual(value, "MISSING", "\(language): \(key)")
                XCTAssertFalse(value.isEmpty)
            }
        }
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
