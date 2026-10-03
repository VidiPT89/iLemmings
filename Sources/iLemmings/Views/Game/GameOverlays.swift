import SwiftUI

/// The screens laid over a level: the briefing before it starts, the pause
/// menu, and the result at the end.

/// The original's pre-level screen: what you are up against, before the
/// hatch opens. Tap (or press any key) to start.
struct LevelBriefing: View {
    @EnvironmentObject var loc: LocalizationManager
    let level: LevelDefinition
    let number: Int
    let onStart: () -> Void

    private var neededPercent: Int {
        guard level.totalLemmings > 0 else { return 0 }
        return Int((Double(level.neededToSave) / Double(level.totalLemmings) * 100).rounded())
    }

    /// A real button over the whole screen, not a tap gesture: a gesture is
    /// invisible to VoiceOver, which left no way to start the level at all.
    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()
            OverlayScroll {
                Button(action: onStart) {
                    content.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var content: some View {
        VStack(spacing: 18) {
            Text("\(loc.string(.briefingLevel)) \(number)")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(lcdGreen.opacity(0.8))
            Text(loc.string(level.nameKey))
                .font(.system(.largeTitle, design: .monospaced).bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                line(.briefingLemmings, "\(level.totalLemmings)")
                line(.briefingToBeSaved, "\(neededPercent)%")
                line(.briefingReleaseRate, "\(level.minReleaseRate)")
                line(.briefingTime, String(format: "%d-%02d", level.timeLimitSeconds / 60, level.timeLimitSeconds % 60))
                line(.briefingRating, loc.string(level.pack.locKey).uppercased())
            }
            .font(.system(.title3, design: .monospaced).bold())
            .foregroundStyle(lcdGreen)
            Text(loc.string(.gameInstructions))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Text(loc.string(.briefingStart))
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
        }
        .padding(32)
    }

    private func line(_ key: LocKey, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(loc.string(key))
            Spacer(minLength: 24)
            Text(value).fixedSize()
        }
        .frame(maxWidth: 360)
    }
}

struct PauseOverlay: View {
    @EnvironmentObject var loc: LocalizationManager
    let onResume: () -> Void
    let onRestart: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            OverlayScroll {
                VStack(spacing: 20) {
                    Text(loc.string(.pauseTitle)).font(.system(.largeTitle, design: .monospaced).bold()).foregroundStyle(.white)
                    Button(loc.string(.pauseResume), action: onResume).buttonStyle(RetroButtonStyle())
                    Button(loc.string(.pauseRestart), action: onRestart).buttonStyle(RetroButtonStyle())
                    Button(loc.string(.pauseMenu), action: onMenu).buttonStyle(RetroButtonStyle())
                }
                .padding(24)
            }
        }
    }
}

struct ResultView: View {
    @EnvironmentObject var loc: LocalizationManager
    let won: Bool
    let stars: Int
    let rescuedPercent: Int
    let neededPercent: Int
    let hasNextLevel: Bool
    let onNext: () -> Void
    let onRetry: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            OverlayScroll {
                VStack(spacing: 20) {
                    if let image = LemmingSprites.standCGImageForUI {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    }
                    Text(loc.string(won ? .levelWinTitle : .levelLoseTitle))
                        .font(.system(.title, design: .monospaced).bold())
                        .foregroundStyle(lcdGreen)
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
                    // The original's end screen: what you got against what you needed.
                    VStack(spacing: 4) {
                        Text(String(format: loc.string(.resultRescued), rescuedPercent))
                        Text(String(format: loc.string(.resultNeeded), neededPercent))
                    }
                    .font(.system(.title3, design: .monospaced).bold())
                    Text(loc.string(won ? .levelWinBody : .levelLoseBody))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    if won, hasNextLevel {
                        Button(loc.string(.nextLevel), action: onNext)
                            .buttonStyle(RetroButtonStyle())
                    }
                    Button(loc.string(.retryLevel), action: onRetry)
                        .buttonStyle(RetroButtonStyle())
                    Button(loc.string(.backToLevels), action: onExit)
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                }
                .padding(24)
            }
        }
        .frame(minWidth: 280, idealWidth: 520, minHeight: 240, idealHeight: 560)
        .preferredColorScheme(.dark)
        .foregroundStyle(.white)
    }
}

/// Center short content; let it scroll when landscape or large text leaves
/// too little room. In particular, retry and menu must never be cut off.
private struct OverlayScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
            }
        }
    }
}

struct GameHelpView: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(loc.string(.gameInstructions))
                    Text(loc.string(.keyboardInstructions))
                }
                ForEach(LemSkill.allCases) { skill in
                    HStack(alignment: .top, spacing: 12) {
                        if let image = LemmingSprites.iconImage(for: skill) {
                            Image(decorative: image, scale: 1)
                                .resizable().interpolation(.none)
                                .frame(width: 40, height: 40)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc.string(skill.locKey)).font(.headline)
                            Text(loc.string(skill.helpKey)).font(.body)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(loc.string(.helpTitle))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.string(.settingsClose)) { dismiss() }
                }
            }
        }
        .frame(minWidth: 280, idealWidth: 480, minHeight: 240, idealHeight: 560)
    }
}

private struct RetroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .monospaced).bold())
            .frame(maxWidth: 260)
            .padding(14)
            .foregroundStyle(lcdGreen)
            .background(configuration.isPressed ? Color(white: 0.20) : Color(white: 0.08))
            .overlay(Rectangle().strokeBorder(lcdGreen.opacity(configuration.isPressed ? 1 : 0.5), lineWidth: 2))
    }
}
