import XCTest
import SpriteKit
import SwiftUI
@testable import iLemmings

/// Draws the game without a window: the SpriteKit scene through an
/// off-screen `SKView`, the SwiftUI overlays through `ImageRenderer`.
///
/// Always a smoke test (the scene has to build and draw). With
/// `ILEMMINGS_SNAPSHOT_DIR` set — `TEST_RUNNER_ILEMMINGS_SNAPSHOT_DIR` on
/// the xcodebuild line — it also writes PNGs to look at.
@MainActor
final class SceneSnapshotTests: XCTestCase {

    func testLevelOnePlaysOutOnScreen() throws {
        let level = LevelLibrary.all[0]
        let engine = GameEngine(level: level)
        let size = CGSize(width: 900, height: 520)
        let scene = GameScene(engine: engine)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        scene.resizeViewport(to: size)
        XCTAssertFalse(scene.children.isEmpty, "the scene built no nodes")

        var time: TimeInterval = 1
        func advance(seconds: Double) {
            for _ in 0..<Int(seconds * 60) {
                scene.update(time)
                time += 1.0 / 60
                buildAtTheEdge(engine)
            }
            settleLemmings(scene, engine: engine)
        }

        try snapshot(view, scene, "1-hatch-closed")
        advance(seconds: 6)
        try snapshot(view, scene, "2-first-lemmings")
        advance(seconds: 30)
        try snapshot(view, scene, "3-bridge")
        XCTAssertGreaterThan(engine.savedCount, 0, "nobody crossed the bridge")
    }

    /// Every level has to be drawn at the same size. Fitting each map's
    /// height to the window blew a 4-row level up to four times the size of
    /// a 17-row one: giant lemmings, and only a quarter of the map on screen.
    func testEveryLevelIsDrawnAtTheSameScaleAndFitsTheWindow() throws {
        for size in [CGSize(width: 1466, height: 745), CGSize(width: 844, height: 300)] {
            var scales: [CGFloat] = []
            for (index, level) in LevelLibrary.all.enumerated() {
                let engine = GameEngine(level: level)
                let scene = GameScene(engine: engine)
                let view = SKView(frame: CGRect(origin: .zero, size: size))
                view.presentScene(scene)
                scene.resizeViewport(to: size)
                scales.append(scene.gameCamera.yScale)

                let visibleHeight = size.height * scene.gameCamera.yScale
                let bottom = scene.gameCamera.position.y - visibleHeight / 2
                XCTAssertLessThanOrEqual(bottom, 0.5, "\(level.id): the floor is cut off")
                XCTAssertGreaterThanOrEqual(
                    bottom + visibleHeight, scene.worldHeight - 0.5,
                    "\(level.id): the top of the level is cut off"
                )
                if index == 2 {
                    try snapshot(view, scene, "6-level3-\(Int(size.width))")
                }
            }
            XCTAssertEqual(Set(scales).count, 1, "levels drawn at different sizes: \(scales)")
        }
    }

    func testOverlaysRender() throws {
        let loc = LocalizationManager()
        let level = LevelLibrary.all[0]
        try render(LevelBriefing(level: level, number: 1, onStart: {}).environmentObject(loc), "4-briefing")
        try render(
            ResultView(won: true, stars: 2, rescuedPercent: 70, neededPercent: 50,
                       hasNextLevel: true, onNext: {}, onRetry: {}, onExit: {})
                .environmentObject(loc)
                .background(Color.white),
            "5-result"
        )
    }

    func testPauseFreezesTheWholeSceneAndClock() {
        let engine = GameEngine(level: LevelLibrary.all[1])
        let scene = GameScene(engine: engine)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 900, height: 520))
        view.presentScene(scene)
        scene.setEnginePaused(true)
        let remaining = engine.secondsRemaining
        for frame in 0..<120 { scene.update(Double(frame) / 60 + 1) }
        XCTAssertEqual(engine.secondsRemaining, remaining)
        XCTAssertEqual(engine.spawnedCount, 0)
        XCTAssertTrue(scene.children.allSatisfy(\.isPaused))
        scene.setEnginePaused(false)
        XCTAssertTrue(scene.children.allSatisfy { !$0.isPaused })
    }

    func testEdgeScrollIsIndependentOfDisplayRefreshRate() {
        func distance(fps: Int) -> CGFloat {
            let scene = GameScene(engine: GameEngine(level: LevelLibrary.all[0]))
            scene.resizeViewport(to: CGSize(width: 100, height: 500))
            scene.centerCamera(onColumn: 5)
            let before = scene.gameCamera.position.x
            for _ in 0..<fps {
                scene.lastPointer = CGPoint(
                    x: scene.gameCamera.position.x + scene.size.width * scene.gameCamera.xScale / 2 - 1,
                    y: 100)
                scene.edgeScroll(deltaTime: 1.0 / Double(fps))
            }
            return scene.gameCamera.position.x - before
        }
        XCTAssertEqual(distance(fps: 30), distance(fps: 120), accuracy: 0.001)
        XCTAssertGreaterThan(distance(fps: 60), 0)
    }

    func testCrowdSelectionSkipsLemmingsThatAlreadyHaveTheSkill() {
        let level = LevelDefinition(id: "crowd", nameKey: .levelGreenHills, pack: .fun,
                                    rows: ["E...X", "#####"], totalLemmings: 2, neededToSave: 1,
                                    minReleaseRate: 99, timeLimitSeconds: 60, skillCounts: [.climber: 2])
        let engine = GameEngine(level: level)
        while engine.spawnedCount < 2 { engine.tick() }
        engine.selectSkill(.climber)
        let first = engine.lemmings[0]
        engine.applySelectedSkill(to: first.id)
        let scene = GameScene(engine: engine)
        let point = CGPoint(x: CGFloat(first.x) * scene.tileSize + scene.tileSize / 2,
                            y: scene.flipRow(first.y) + scene.tileSize * 0.35)
        XCTAssertEqual(scene.nearestLiving(to: point), engine.lemmings[1].id)
    }

    func testBuilderWarnsExactlyForItsLastThreeBricks() {
        var rows = Array(repeating: String(repeating: ".", count: 30), count: 15)
        rows.append("E.............................")
        rows.append(String(repeating: "#", count: 30))
        let level = LevelDefinition(id: "builder", nameKey: .levelGreenHills, pack: .fun,
                                    rows: rows, totalLemmings: 1, neededToSave: 1,
                                    minReleaseRate: 99, timeLimitSeconds: 60, skillCounts: [.builder: 1])
        let engine = GameEngine(level: level)
        let scene = GameScene(engine: engine)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 900, height: 520))
        view.presentScene(scene)
        var warnings = 0
        scene.onBuilderWarning = { warnings += 1 }
        for frame in 0..<1500 {
            scene.update(Double(frame) / 60 + 1)
            if let lem = engine.lemmings.first, lem.state == .walking {
                engine.selectSkill(.builder)
                engine.applySelectedSkill(to: lem.id)
            }
        }
        XCTAssertEqual(warnings, 3)
    }

    func testControlPanelFitsPhoneAndDesktopWidths() throws {
        for width: CGFloat in [320, 390, 844, 1466] {
            for level in [LevelLibrary.all[0], LevelLibrary.all[2]] {
                let panel = BottomControlPanel(engine: GameEngine(level: level),
                                               isPaused: .constant(false), viewport: nil,
                                               onJumpToColumn: { _ in })
                    .environmentObject(LocalizationManager())
                    .environmentObject(SoundManager())
                let renderer = ImageRenderer(content: panel)
                renderer.proposedSize = ProposedViewSize(width: width, height: nil)
                let image = try XCTUnwrap(renderer.cgImage)
                XCTAssertLessThanOrEqual(CGFloat(image.width), width, "panel overflows at \(width)")
                XCTAssertLessThanOrEqual(image.height, 130)
                write(image, "panel-\(level.id)-\(Int(width))")
            }
        }
    }

    // MARK: - Helpers

    /// The level-1 line: a Builder at the lip of the pit.
    private func buildAtTheEdge(_ engine: GameEngine) {
        for lem in engine.lemmings where lem.state == .walking && lem.facingRight {
            let col = Int(lem.x.rounded())
            let belowFront = engine.tile(lem.y + 1, col + 1)
            if !belowFront.isSolid {
                engine.selectSkill(.builder)
                engine.applySelectedSkill(to: lem.id)
            }
        }
    }

    /// SKActions only run inside a live display loop, which an off-screen
    /// view never has, so the eased moves are finished by hand before a shot.
    private func settleLemmings(_ scene: GameScene, engine: GameEngine) {
        for lem in engine.lemmings {
            guard let node = scene.childNode(withName: "lem-\(lem.id)") else { continue }
            node.removeAction(forKey: "move")
            node.position = CGPoint(
                x: CGFloat(lem.x) * scene.tileSize + scene.tileSize / 2,
                y: scene.flipRow(lem.y)
            )
        }
    }

    private func snapshot(_ view: SKView, _ scene: GameScene, _ name: String) throws {
        guard let image = view.texture(from: scene)?.cgImage() else {
            throw XCTSkip("no renderer available here")
        }
        write(image, name)
    }

    private func render(_ content: some View, _ name: String) throws {
        let renderer = ImageRenderer(content: content.frame(width: 600, height: 520))
        guard let image = renderer.cgImage else { throw XCTSkip("no renderer available here") }
        write(image, name)
    }

    private func write(_ image: CGImage, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["ILEMMINGS_SNAPSHOT_DIR"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            return
        }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
