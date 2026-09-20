import SwiftUI

struct LevelsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.colorScheme) private var scheme
    @AppStorage("unlockedLevelIndex") private var unlockedIndex = 0

    var body: some View {
        ZStack {
            Color.brandBackground(for: scheme).ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(LevelPack.allCases, id: \.self) { pack in
                        let levelsInPack = Array(LevelLibrary.all.enumerated()).filter { $0.element.pack == pack }
                        if !levelsInPack.isEmpty {
                            Text(loc.string(pack.locKey))
                                .font(.title3.bold())
                                .foregroundStyle(Color.brandGradient)
                                .padding(.horizontal, 4)

                            ForEach(levelsInPack, id: \.element.id) { index, level in
                                let unlocked = index <= unlockedIndex
                                NavigationLink(destination: GameView(level: level, levelIndex: index)) {
                                    LevelRow(level: level, index: index, unlocked: unlocked)
                                }
                                .disabled(!unlocked)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(loc.string(.levelsTitle))
    }
}

private struct LevelRow: View {
    @EnvironmentObject var loc: LocalizationManager
    let level: LevelDefinition
    let index: Int
    let unlocked: Bool
    @State private var stars = 0

    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(unlocked ? AnyShapeStyle(Color.brandGradient) : AnyShapeStyle(Color.gray.opacity(0.4)))
                    .frame(width: 54, height: 54)
                Text("\(index + 1)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.string(level.nameKey)).font(.headline)
                Text("\(loc.string(.hudLemmingsNeeded)): \(level.neededToSave)/\(level.totalLemmings)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if unlocked {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < stars ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(i < stars ? Color.brandAmber : .secondary.opacity(0.4))
                        }
                    }
                }
            }
            Spacer()
            if !unlocked {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(unlocked ? 1 : 0.6)
        .onAppear { stars = StarsStore.stars(for: level.id) }
    }
}
