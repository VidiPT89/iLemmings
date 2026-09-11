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
            }
            .ignoresSafeArea()

            VStack {
                HUDTopBar(engine: engine, isPaused: $isPaused)
                Spacer()
                HStack {
                    Spacer()
                    ZoomControls(scene: scene)
                }
                SkillTray(engine: engine)
            }
            .padding()

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
        isPaused = false
        showResult = false
        earnedStars = 0
        lastSkillTotal = engine.skillInventory.values.reduce(0, +)
    }
}

/// The classic Lemmings control panel: flat black, hard corners, a thin
/// grey-blue frame — no rounding, no blur, no gradients. Matches the
/// original's DOS/Amiga panel far more closely than the frosted iOS chrome
/// used in the rest of this app.
private struct RetroPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.black.opacity(0.9))
            .overlay(Rectangle().strokeBorder(Color(red: 0.55, green: 0.6, blue: 0.65).opacity(0.6), lineWidth: 1))
    }
}

private extension View {
    func retroPanel() -> some View { modifier(RetroPanel()) }
}

/// The bright green "LCD"/dot-matrix look of the original counters
/// (OUT / IN / TIME), instead of a brand-colored UI font.
private let lcdGreen = Color(red: 0.35, green: 0.95, blue: 0.35)

private struct HUDTopBar: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var sound: SoundManager
    @ObservedObject var engine: GameEngine
    @Binding var isPaused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isPaused = true
            } label: {
                Image(systemName: "pause.fill").frame(width: 20, height: 20)
            }
            .padding(10)
            .retroPanel()

            HStack(spacing: 0) {
                statCell(loc.string(.hudLemmingsOut), "\(engine.spawnedCount - engine.savedCount - engine.deadCount)")
                divider
                statCell(loc.string(.hudLemmingsSaved), "\(engine.savedCount)/\(engine.level.neededToSave)", animated: true)
                divider
                statCell(loc.string(.hudTimeLeft), timeString(engine.secondsRemaining))
            }
            .retroPanel()

            Spacer()

            Button {
                sound.isMuted.toggle()
            } label: {
                Image(systemName: sound.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 20, height: 20)
            }
            .padding(10)
            .retroPanel()
        }
        .foregroundStyle(lcdGreen)
        .buttonStyle(.plain)
    }

    private var divider: some View {
        // Explicit height matters: a bare Rectangle() has no intrinsic size,
        // so without it the shape (and the whole HStack around it) stretches
        // to fill all available vertical space instead of hugging the text.
        Rectangle().fill(lcdGreen.opacity(0.25)).frame(width: 1, height: 36)
    }

    private func statCell(_ title: String, _ value: String, animated: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(title).font(.system(size: 9, weight: .medium, design: .monospaced)).opacity(0.7)
            Text(value)
                .font(.system(.headline, design: .monospaced)).bold()
                .contentTransition(animated ? .numericText() : .identity)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func timeString(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct ZoomControls: View {
    let scene: GameScene

    var body: some View {
        VStack(spacing: 6) {
            Button { scene.zoom(byFactor: 1 / 1.25) } label: {
                Image(systemName: "plus.magnifyingglass").frame(width: 18, height: 18)
            }
            .padding(8)
            .retroPanel()
            Button { scene.zoom(byFactor: 1.25) } label: {
                Image(systemName: "minus.magnifyingglass").frame(width: 18, height: 18)
            }
            .padding(8)
            .retroPanel()
        }
        .foregroundStyle(lcdGreen)
        .buttonStyle(.plain)
    }
}

/// A dithered/stippled yellow tile, like the original's skill button
/// background — a flat gold fill reads as a modern app icon, not the game.
private struct DitheredYellowBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.62, green: 0.5, blue: 0.14)))
            let dot = 3.0
            var y = 0.0
            var row = 0
            while y < size.height {
                var x = row.isMultiple(of: 2) ? 0.0 : dot
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: y, width: dot, height: dot)), with: .color(Color(red: 0.78, green: 0.66, blue: 0.2)))
                    x += dot * 2
                }
                y += dot
                row += 1
            }
        }
    }
}

private struct SkillTray: View {
    @ObservedObject var engine: GameEngine
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LemSkill.allCases) { skill in
                let count = engine.skillInventory[skill] ?? 0
                let selected = engine.selectedSkill == skill
                Button {
                    engine.selectSkill(skill)
                } label: {
                    ZStack(alignment: .topLeading) {
                        DitheredYellowBackground()
                        Image(systemName: skill.symbol)
                            .font(.title3)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .background(Color.black.opacity(0.75))
                            .padding(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .overlay(Rectangle().strokeBorder(selected ? Color.red : Color(red: 0.4, green: 0.42, blue: 0.46), lineWidth: selected ? 3 : 1))
                }
                .disabled(count == 0)
                .opacity(count == 0 ? 0.35 : 1)
            }
        }
        .buttonStyle(.plain)
        .background(Color.black)
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
