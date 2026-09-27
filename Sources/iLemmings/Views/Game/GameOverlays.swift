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
        Button(action: onStart) {
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                content
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
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
            Text(value)
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
                // The original's end screen: what you got against what you needed.
                VStack(spacing: 4) {
                    Text(String(format: loc.string(.resultRescued), rescuedPercent))
                    Text(String(format: loc.string(.resultNeeded), neededPercent))
                }
                .font(.system(.title3, design: .monospaced).bold())
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
