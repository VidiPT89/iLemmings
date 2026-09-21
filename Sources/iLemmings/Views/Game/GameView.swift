import SwiftUI
import SpriteKit

struct GameView: View {
    @EnvironmentObject var sound: SoundManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("unlockedLevelIndex") private var unlockedIndex = 0

    /// The level in play. Held as state rather than passed in once, because
    /// finishing a level plays straight on into the next one instead of
    /// throwing the player back to the menu.
    @State private var levelIndex: Int
    private var level: LevelDefinition { LevelLibrary.all[levelIndex] }
    private var hasNextLevel: Bool { levelIndex + 1 < LevelLibrary.all.count }

    @StateObject private var engine: GameEngine
    @State private var scene: GameScene
    @State private var isPaused = false
    @State private var showResult = false
    @State private var earnedStars = 0
    @State private var lastSkillTotal: Int
    @State private var viewport: ClosedRange<Double>?

    init(level: LevelDefinition, levelIndex: Int) {
        _levelIndex = State(initialValue: levelIndex)
        let eng = GameEngine(level: level)
        _engine = StateObject(wrappedValue: eng)
        _scene = State(initialValue: GameScene(engine: eng))
        _lastSkillTotal = State(initialValue: eng.skillInventory.values.reduce(0, +))
    }

    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                GeometryReader { proxy in
                    SpriteView(scene: scene)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .onAppear { scene.resizeViewport(to: proxy.size) }
                        .onChange(of: proxy.size) { _, newSize in
                            scene.resizeViewport(to: newSize)
                        }
                }

                BottomControlPanel(engine: engine, isPaused: $isPaused, viewport: viewport)
            }

            if isPaused {
                PauseOverlay(
                    onResume: { isPaused = false },
                    onRestart: { restart() },
                    onMenu: { dismiss() }
                )
            }
        }
        .onChange(of: isPaused) { _, newValue in scene.setEnginePaused(newValue) }
        .onChange(of: engine.skillInventory) { _, newValue in
            let total = newValue.values.reduce(0, +)
            if total < lastSkillTotal {
                sound.play(.assign)
                Haptics.skillAssigned()
            }
            lastSkillTotal = total
        }
        .onChange(of: engine.selectedSkill) { _, newValue in
            if newValue != nil { sound.play(.select) }
        }
        .onChange(of: engine.isWon) { _, newValue in
            guard newValue else { return }
            // Show what this run earned, not the best ever stored for the
            // level — `record` returns the running best, so replaying a level
            // you'd already 3-starred used to claim 3 stars for a 1-star run.
            earnedStars = level.stars(saved: engine.savedCount, secondsRemaining: engine.secondsRemaining)
            StarsStore.record(earnedStars, for: level.id)
            // Unlocking belongs to winning, not to pressing a particular
            // button on the result sheet: leaving it on "next level" meant
            // that backing out to the menu after a win lost the unlock.
            unlockedIndex = max(unlockedIndex, levelIndex + 1)
            sound.play(.win)
            Haptics.levelComplete()
            showResult = true
        }
        .onChange(of: engine.isLost) { _, newValue in
            guard newValue else { return }
            sound.play(.lose)
            Haptics.levelFailed()
            showResult = true
        }
        .onAppear { bindCallbacks(to: scene) }
        .sheet(isPresented: $showResult) {
            ResultView(
                won: engine.isWon,
                stars: earnedStars,
                hasNextLevel: hasNextLevel,
                onNext: { advanceToNextLevel() },
                onRetry: { showResult = false; restart() },
                onExit: { dismiss() }
            )
            .interactiveDismissDisabled()
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// A restart swaps in a fresh scene, which needs the same wiring as the
    /// first one — keeping it in one place so the two can't drift apart.
    private func bindCallbacks(to scene: GameScene) {
        scene.onLemmingTapped = { id in engine.applySelectedSkill(to: id) }
        scene.onExplosion = { sound.play(.explode) }
        scene.onSplat = { sound.play(.splat) }
        scene.onDrown = { sound.play(.drown) }
        scene.onTogglePause = { isPaused.toggle() }
        scene.onViewportChanged = { viewport = $0 }
    }

    /// Plays straight on into the next level on this same screen. Dismissing
    /// instead sent the player back out to the menu after every win, which
    /// made finishing a level feel like losing your place.
    private func advanceToNextLevel() {
        guard hasNextLevel else { dismiss(); return }
        let next = levelIndex + 1
        levelIndex = next
        // Loaded from the index rather than from `level`, so this never
        // depends on when SwiftUI makes the new @State value readable.
        engine.load(LevelLibrary.all[next])
        startFreshScene()
    }

    private func restart() {
        engine.reset()
        startFreshScene()
    }

    /// A restart and a level change both need a brand-new scene wired up and
    /// every bit of per-level view state cleared; keeping that in one place
    /// stops the two drifting apart.
    private func startFreshScene() {
        let fresh = GameScene(engine: engine)
        bindCallbacks(to: fresh)
        scene = fresh
        isPaused = false
        showResult = false
        earnedStars = 0
        viewport = nil
        lastSkillTotal = engine.skillInventory.values.reduce(0, +)
    }
}

/// The bright green "LCD"/dot-matrix look of the original counters
/// (OUT / IN / TIME), instead of a brand-colored UI font.
private let lcdGreen = Color(red: 0.35, green: 0.95, blue: 0.35)

/// The level at a glance, sized to its own proportions and sitting inside
/// the control panel — which is where the original keeps it.
///
/// It used to be a full-width strip above the playfield, which forced a
/// choice between two bad options: scale uniformly and get a postage stamp
/// adrift in a very wide black bar, or stretch to fill and give a 26-column
/// level tiles 56 points wide and 5 tall. A level here is far squarer than
/// the original's long scrolling maps, so the honest answer is to let the
/// minimap be as small as it wants to be and give the height back to the
/// game.
private struct MiniMap: View {
    @ObservedObject var engine: GameEngine
    /// The columns currently on screen, drawn as a box like the original's.
    let viewport: ClosedRange<Double>?

    private var aspect: CGFloat {
        CGFloat(max(engine.width, 1)) / CGFloat(max(engine.height, 1))
    }

    var body: some View {
        let height = controlButtonSize - 4
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let cols = CGFloat(max(engine.width, 1))
            let rows = CGFloat(max(engine.height, 1))
            let cellW = size.width / cols
            let cellH = size.height / rows
            for r in 0..<engine.height {
                for c in 0..<engine.width {
                    guard let color = miniColor(engine.tile(r, c)) else { continue }
                    let rect = CGRect(
                        x: CGFloat(c) * cellW, y: CGFloat(r) * cellH,
                        width: max(1, cellW), height: max(1, cellH)
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
            for lem in engine.lemmings where lem.isAlive {
                let rect = CGRect(
                    x: CGFloat(lem.x) * cellW, y: CGFloat(lem.y) * cellH,
                    width: max(1.5, cellW), height: max(1.5, cellH)
                )
                context.fill(Path(rect), with: .color(lcdGreen))
            }
            // Clamped to the level: on a map narrower than the window the
            // camera shows sky past both ends, and an unclamped box would be
            // drawn off the edge instead of around everything.
            if let viewport {
                let lo = max(0, min(Double(cols), viewport.lowerBound))
                let hi = max(0, min(Double(cols), viewport.upperBound))
                if hi > lo {
                    let box = CGRect(
                        x: CGFloat(lo) * cellW + 0.5, y: 0.5,
                        width: max(2, CGFloat(hi - lo) * cellW - 1), height: size.height - 1
                    )
                    context.stroke(Path(box), with: .color(.white.opacity(0.9)), lineWidth: 1)
                }
            }
        }
        .frame(width: min(max(height * aspect, 72), 220), height: height)
        .overlay(Rectangle().strokeBorder(Color(red: 0.4, green: 0.42, blue: 0.46), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func miniColor(_ tile: Tile) -> Color? {
        switch tile {
        case .dirt: return Color(red: 0.55, green: 0.34, blue: 0.10)
        case .steel: return Color(red: 0.62, green: 0.62, blue: 0.68)
        case .trap: return Color(red: 0.85, green: 0.15, blue: 0.12)
        case .water: return Color(red: 0.18, green: 0.45, blue: 0.78)
        case .exit: return Color(red: 1, green: 0.85, blue: 0.2)
        case .entrance: return Color(red: 0.25, green: 0.92, blue: 0.35)
        case .empty: return Color(red: 0.08, green: 0.07, blue: 0.10)
        }
    }
}

/// A dithered/stippled brown-tan tile, like the original's skill button
/// background (verified against an actual screenshot of the original) — a
/// flat gold fill reads as a modern app icon, and the original's buttons
/// are brown/tan, not bright yellow.
private struct DitheredSkillBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.22, green: 0.15, blue: 0.09)))
            let dot = 2.0
            var y = 0.0
            var row = 0
            while y < size.height {
                var x = row.isMultiple(of: 2) ? 0.0 : dot
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: y, width: dot, height: dot)), with: .color(Color(red: 0.34, green: 0.24, blue: 0.14)))
                    x += dot * 2
                }
                y += dot
                row += 1
            }
        }
    }
}

/// The original's single control panel fixed at the bottom of the screen —
/// one row with the 8 skill buttons, Pause, Nuke and Mute on the left, and
/// the green LCD counters (out/saved/time) on the right, all on the same
/// line. Verified against an actual screenshot of the original (Wikipedia's
/// Amiga_Lemmings.png) — a stacked stats-strip-above-icons layout, a
/// floating top bar, a separate bottom tray, and floating zoom buttons were
/// all earlier guesses that didn't match the real thing.
private struct BottomControlPanel: View {
    @ObservedObject var engine: GameEngine
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var sound: SoundManager
    @Binding var isPaused: Bool
    let viewport: ClosedRange<Double>?
    @State private var showNukeConfirm = false

    var body: some View {
        HStack(spacing: 2) {
            ControlButton(systemImage: "minus") { engine.changeReleaseRate(-1) }
            Text("\(engine.releaseRate)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(lcdGreen)
                .frame(width: 22)
            ControlButton(systemImage: "plus") { engine.changeReleaseRate(1) }
            ForEach(LemSkill.allCases) { skill in
                SkillButton(skill: skill, engine: engine)
            }
            ControlButton(systemImage: "pause.fill") { isPaused = true }
            ControlButton(systemImage: "flame.fill") { showNukeConfirm = true }
            ControlButton(systemImage: engine.gameSpeed == 1 ? "forward.fill" : "forward.end.fill") {
                engine.toggleFastForward()
            }
            ControlButton(systemImage: sound.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                sound.isMuted.toggle()
            }
            Spacer(minLength: 8)
            MiniMap(engine: engine, viewport: viewport)
            Spacer(minLength: 8)
            statsRow
        }
        .background(Color.black)
        .overlay(Rectangle().strokeBorder(Color(red: 0.55, green: 0.6, blue: 0.65).opacity(0.6), lineWidth: 1))
        .confirmationDialog(loc.string(.nukeConfirm), isPresented: $showNukeConfirm, titleVisibility: .visible) {
            Button(loc.string(.nukeConfirmAction), role: .destructive) { engine.nukeAll() }
        }
    }

    private var statsRow: some View {
        let out = engine.spawnedCount - engine.savedCount - engine.deadCount
        let inPercent = engine.level.totalLemmings == 0
            ? 0
            : Int((Double(engine.savedCount) / Double(engine.level.totalLemmings) * 100).rounded())
        return HStack(spacing: 10) {
            statCell("OUT", "\(out)")
            statCell("IN", "\(inPercent)%", animated: true)
            statCell("TIME", timeString(engine.secondsRemaining))
        }
        .foregroundStyle(lcdGreen)
        .padding(.trailing, 12)
    }

    private func statCell(_ title: String, _ value: String, animated: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.system(size: 8, weight: .medium, design: .monospaced)).opacity(0.7)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .contentTransition(animated ? .numericText() : .identity)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d-%02d", s / 60, s % 60)
    }
}

/// Fixed, small button size — the original's panel buttons are a compact
/// strip that never stretches to fill the window width. `maxWidth: .infinity`
/// on each button here used to do exactly that on a wide macOS window,
/// which is why the whole panel read as oversized.
private let controlButtonSize: CGFloat = 32

private struct ControlButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(lcdGreen)
                .frame(width: controlButtonSize, height: controlButtonSize)
        }
        .buttonStyle(.plain)
        .overlay(Rectangle().strokeBorder(Color(red: 0.4, green: 0.42, blue: 0.46), lineWidth: 1))
    }
}

private struct SkillButton: View {
    let skill: LemSkill
    @ObservedObject var engine: GameEngine
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        let count = engine.skillInventory[skill] ?? 0
        let selected = engine.selectedSkill == skill
        Button {
            engine.selectSkill(skill)
        } label: {
            ZStack(alignment: .topLeading) {
                DitheredSkillBackground()
                if let icon = LemmingSprites.iconImage(for: skill) {
                    Image(decorative: icon, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(lcdGreen)
                    .padding(.horizontal, 2)
                    .background(Color.black.opacity(0.85))
                    .padding(1)
            }
            .frame(width: controlButtonSize, height: controlButtonSize)
            .overlay(Rectangle().strokeBorder(selected ? Color.red : Color(red: 0.4, green: 0.42, blue: 0.46), lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .opacity(count == 0 ? 0.35 : 1)
        .accessibilityLabel(loc.string(skill.locKey))
        .accessibilityValue("\(count)")
    }
}

private struct PauseOverlay: View {
    @EnvironmentObject var loc: LocalizationManager
    let onResume: () -> Void
    let onRestart: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(loc.string(.pauseTitle)).font(.largeTitle.bold()).foregroundStyle(.white)
                Button(loc.string(.pauseResume), action: onResume).buttonStyle(BrandButtonStyle())
                Button(loc.string(.pauseRestart), action: onRestart).buttonStyle(BrandButtonStyle())
                Button(loc.string(.pauseMenu), action: onMenu).buttonStyle(BrandButtonStyle())
            }
            .padding(32)
        }
    }
}

private struct ResultView: View {
    @EnvironmentObject var loc: LocalizationManager
    let won: Bool
    let stars: Int
    let hasNextLevel: Bool
    let onNext: () -> Void
    let onRetry: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            if won {
                ConfettiView()
            }

            VStack(spacing: 20) {
                Image(systemName: won ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(won ? Color.green : Color.red)
                    .transition(.scale.combined(with: .opacity))
                Text(loc.string(won ? .levelWinTitle : .levelLoseTitle)).font(.title.bold())
                if won {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < stars ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(i < stars ? Color.brandAmber : .secondary.opacity(0.3))
                                .scaleEffect(i < stars ? 1 : 0.85)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.12), value: stars)
                        }
                    }
                }
                Text(loc.string(won ? .levelWinBody : .levelLoseBody))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                // Three distinct outcomes, not two: play on, try again, or
                // leave. "Back to levels" used to run the same action as
                // "next level", so both buttons did the same thing.
                if won, hasNextLevel {
                    Button(loc.string(.nextLevel), action: onNext)
                        .buttonStyle(BrandButtonStyle())
                    Button(loc.string(.backToLevels), action: onExit)
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                } else if won {
                    // Last level: there is nowhere to play on to.
                    Button(loc.string(.backToLevels), action: onExit)
                        .buttonStyle(BrandButtonStyle())
                } else {
                    Button(loc.string(.retryLevel), action: onRetry)
                        .buttonStyle(BrandButtonStyle())
                    Button(loc.string(.backToLevels), action: onExit)
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                }
            }
            .padding(32)
        }
    }
}

private struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .frame(maxWidth: 260)
            .padding()
            .background(Color.brandGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
