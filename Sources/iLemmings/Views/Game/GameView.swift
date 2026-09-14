import SwiftUI
import SpriteKit

struct GameView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var sound: SoundManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("unlockedLevelIndex") private var unlockedIndex = 0

    let level: LevelDefinition
    let levelIndex: Int

    @StateObject private var engine: GameEngine
    @State private var scene: GameScene
    @State private var isPaused = false
    @State private var showResult = false
    @State private var earnedStars = 0
    @State private var lastSkillTotal: Int

    init(level: LevelDefinition, levelIndex: Int) {
        self.level = level
        self.levelIndex = levelIndex
        let eng = GameEngine(level: level)
        _engine = StateObject(wrappedValue: eng)
        _scene = State(initialValue: GameScene(engine: eng))
        _lastSkillTotal = State(initialValue: eng.skillInventory.values.reduce(0, +))
    }

    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()

            GeometryReader { proxy in
                SpriteView(scene: scene)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear { scene.resizeViewport(to: proxy.size) }
            .onChange(of: proxy.size) { _, newSize in scene.resizeViewport(to: newSize) }
            .focusable()
            .onKeyPress(.space) {
                isPaused.toggle()
                return .handled
            }
            .onKeyPress("f") {
                engine.toggleFastForward()
                return .handled
            }
            .onKeyPress("-") {
                engine.changeReleaseRate(-1)
                return .handled
            }
            .onKeyPress("=") {
                engine.changeReleaseRate(1)
                return .handled
            }
            .onKeyPress("1") { engine.selectSkill(.climber); return .handled }
            .onKeyPress("2") { engine.selectSkill(.floater); return .handled }
            .onKeyPress("3") { engine.selectSkill(.bomber); return .handled }
            .onKeyPress("4") { engine.selectSkill(.blocker); return .handled }
            .onKeyPress("5") { engine.selectSkill(.builder); return .handled }
            .onKeyPress("6") { engine.selectSkill(.basher); return .handled }
            .onKeyPress("7") { engine.selectSkill(.miner); return .handled }
            .onKeyPress("8") { engine.selectSkill(.digger); return .handled }
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                BottomControlPanel(engine: engine, isPaused: $isPaused)
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
            earnedStars = StarsStore.record(
                level.stars(saved: engine.savedCount, secondsRemaining: engine.secondsRemaining),
                for: level.id
            )
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
        .onAppear {
            scene.onLemmingTapped = { id in engine.applySelectedSkill(to: id) }
            scene.onExplosion = { sound.play(.explode) }
            scene.onSplat = { sound.play(.splat) }
        }
        .sheet(isPresented: $showResult) {
            ResultView(
                won: engine.isWon,
                stars: earnedStars,
                onNext: {
                    if engine.isWon { unlockedIndex = max(unlockedIndex, levelIndex + 1) }
                    dismiss()
                },
                onRetry: { showResult = false; restart() }
            )
            .interactiveDismissDisabled()
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private func restart() {
        engine.reset()
        scene = GameScene(engine: engine)
        scene.onLemmingTapped = { id in engine.applySelectedSkill(to: id) }
        scene.onExplosion = { sound.play(.explode) }
        scene.onSplat = { sound.play(.splat) }
        isPaused = false
        showResult = false
        earnedStars = 0
        lastSkillTotal = engine.skillInventory.values.reduce(0, +)
    }
}

/// The bright green "LCD"/dot-matrix look of the original counters
/// (OUT / IN / TIME), instead of a brand-colored UI font.
private let lcdGreen = Color(red: 0.35, green: 0.95, blue: 0.35)

/// A dithered/stippled brown-tan tile, like the original's skill button
/// background (verified against an actual screenshot of the original) — a
/// flat gold fill reads as a modern app icon, and the original's buttons
/// are brown/tan, not bright yellow.
private struct DitheredSkillBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.32, green: 0.22, blue: 0.13)))
            let dot = 3.0
            var y = 0.0
            var row = 0
            while y < size.height {
                var x = row.isMultiple(of: 2) ? 0.0 : dot
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: y, width: dot, height: dot)), with: .color(Color(red: 0.45, green: 0.33, blue: 0.19)))
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
    @State private var showNukeConfirm = false

    var body: some View {
        HStack(spacing: 2) {
            ControlButton(systemImage: "minus") { engine.changeReleaseRate(-1) }
            Text("\(engine.releaseRate)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
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
private let controlButtonSize: CGFloat = 34

private struct ControlButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
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
                Image(systemName: skill.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.15, green: 0.62, blue: 0.20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("\(count)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 2)
                    .background(Color.black.opacity(0.75))
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
    let onNext: () -> Void
    let onRetry: () -> Void

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

                Button(won ? loc.string(.nextLevel) : loc.string(.retryLevel), action: won ? onNext : onRetry)
                    .buttonStyle(BrandButtonStyle())
                Button(loc.string(.backToLevels), action: onNext)
                    .buttonStyle(.plain)
                    .padding(.top, 4)
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
