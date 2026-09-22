import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.colorScheme) private var scheme
    @State private var showLevels = false
    @State private var showPlay = false
    @State private var showSettings = false
    @State private var floatOffset: CGFloat = 0

    /// "Play" jumps straight into the next level the player hasn't beaten yet.
    private var nextLevelIndex: Int {
        LevelLibrary.continueIndex(stars: StarsStore.stars(for:))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBackground(for: scheme).ignoresSafeArea()
                DecorativeWalkersView().ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    VStack(spacing: 8) {
                        Image("LemmingMark")
                            .interpolation(.high)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .brandOrange.opacity(0.45), radius: 16)
                            .offset(y: floatOffset)
                        Text(loc.string(.appName))
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.brandGradient)
                        Text(loc.string(.tagline))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        MenuButton(title: loc.string(.menuPlay), icon: "play.fill") { showPlay = true }
                        MenuButton(title: loc.string(.menuLevels), icon: "list.bullet") { showLevels = true }
                        MenuButton(title: loc.string(.menuSettings), icon: "gearshape.fill") { showSettings = true }
                    }
                    .frame(maxWidth: 280)
                    .frame(maxWidth: .infinity)

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
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 18)
                Text(title).fontWeight(.semibold)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.brandGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
            withAnimation(.easeOut(duration: 0.15)) { pressed = isPressing }
        }, perform: {})
    }
}
