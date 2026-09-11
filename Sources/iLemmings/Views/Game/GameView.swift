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
        isPaused = false
        showResult = false
        earnedStars = 0
        lastSkillTotal = engine.skillInventory.values.reduce(0, +)
    }
}

private struct HUDTopBar: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var sound: SoundManager
    @ObservedObject var engine: GameEngine
    @Binding var isPaused: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button {
                isPaused = true
            } label: {
                Image(systemName: "pause.fill")
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }

            statBadge(loc.string(.hudLemmingsOut), "\(engine.spawnedCount - engine.savedCount - engine.deadCount)")
            statBadge(loc.string(.hudLemmingsSaved), "\(engine.savedCount)/\(engine.level.neededToSave)", animated: true)
            statBadge(loc.string(.hudTimeLeft), timeString(engine.secondsRemaining))

            Spacer()

            Button {
                sound.isMuted.toggle()
            } label: {
                Image(systemName: sound.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
        }
        .foregroundStyle(.white)
    }

    private func statBadge(_ title: String, _ value: String, animated: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).opacity(0.8)
            Text(value)
                .font(.headline.monospacedDigit())
                .contentTransition(animated ? .numericText() : .identity)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.brandGradient.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
    }

    private func timeString(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct ZoomControls: View {
    let scene: GameScene

    var body: some View {
        VStack(spacing: 8) {
            Button { scene.zoom(byFactor: 1 / 1.25) } label: {
                Image(systemName: "plus.magnifyingglass").padding(8).background(.thinMaterial, in: Circle())
            }
            Button { scene.zoom(byFactor: 1.25) } label: {
                Image(systemName: "minus.magnifyingglass").padding(8).background(.thinMaterial, in: Circle())
            }
        }
        .foregroundStyle(.white)
    }
}

private struct SkillTray: View {
    @ObservedObject var engine: GameEngine
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        HStack(spacing: 10) {
            ForEach(LemSkill.allCases) { skill in
                let count = engine.skillInventory[skill] ?? 0
                Button {
                    engine.selectSkill(skill)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: skill.symbol)
                            .font(.title3)
                        Text("\(count)").font(.caption2.monospacedDigit())
                    }
                    .frame(width: 52, height: 52)
                    .background(
                        engine.selectedSkill == skill ? AnyShapeStyle(Color.brandGradient) : AnyShapeStyle(.thinMaterial),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(engine.selectedSkill == skill ? .white : .primary)
                }
                .disabled(count == 0)
                .opacity(count == 0 ? 0.35 : 1)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
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
