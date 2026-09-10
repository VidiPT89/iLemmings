import SwiftUI

struct LevelsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.colorScheme) private var scheme
    @AppStorage("unlockedLevelIndex") private var unlockedIndex = 0

    var body: some View {
        ZStack {
            Color.brandBackground(for: scheme).ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(LevelLibrary.all.enumerated()), id: \.element.id) { index, level in
                        let unlocked = index <= unlockedIndex
                        NavigationLink(destination: GameView(level: level, levelIndex: index)) {
                            LevelRow(level: level, index: index, unlocked: unlocked)
                        }
                        .disabled(!unlocked)
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
                Text(level.nameKey).font(.headline)
                Text("\(loc.string(.hudLemmingsNeeded)): \(level.neededToSave)/\(level.totalLemmings)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    }
}
