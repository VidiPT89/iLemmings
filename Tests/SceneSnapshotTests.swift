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
