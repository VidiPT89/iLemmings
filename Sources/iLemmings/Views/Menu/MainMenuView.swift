import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.colorScheme) private var scheme
    @AppStorage("unlockedLevelIndex") private var unlockedIndex = 0
    @State private var showLevels = false
    @State private var showPlay = false
    @State private var showSettings = false
    @State private var floatOffset: CGFloat = 0

    /// "Play" jumps straight into the next level the player hasn't beaten yet.
    private var nextLevelIndex: Int {
        min(unlockedIndex, LevelLibrary.all.count - 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBackground(for: scheme).ignoresSafeArea()
                DecorativeWalkersView().ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(Color.brandGradient)
                            .offset(y: floatOffset)
                        Text(loc.string(.appName))
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.brandGradient)
                        Text(loc.string(.tagline))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        MenuButton(title: loc.string(.menuPlay), icon: "play.fill") { showPlay = true }
                        MenuButton(title: loc.string(.menuLevels), icon: "list.bullet") { showLevels = true }
                        MenuButton(title: loc.string(.menuSettings), icon: "gearshape.fill") { showSettings = true }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                    Text(loc.string(.developedBy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }
            }
            .navigationDestination(isPresented: $showLevels) { LevelsView() }
            .navigationDestination(isPresented: $showPlay) {
                GameView(level: LevelLibrary.all[nextLevelIndex], levelIndex: nextLevelIndex)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    floatOffset = -10
                }
            }
        }
    }
}

private struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title).fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right").font(.caption)
            }
            .padding()
            .background(Color.brandGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
            withAnimation(.easeOut(duration: 0.15)) { pressed = isPressing }
        }, perform: {})
    }
}
