import SwiftUI

/// A few lemmings strolling across the bottom of the main menu, purely
/// decorative — the same pixel-art texture used in-game.
struct DecorativeWalkersView: View {
    private struct Walker: Identifiable {
        let id = UUID()
        let delay: Double
        let duration: Double
        let y: CGFloat
        let scale: CGFloat
    }

    private let walkers: [Walker] = [
        Walker(delay: 0, duration: 9, y: 0.15, scale: 1.0),
        Walker(delay: 3, duration: 11, y: 0.55, scale: 0.8),
        Walker(delay: 6, duration: 8, y: 0.85, scale: 1.1),
    ]

    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(walkers.enumerated()), id: \.offset) { _, walker in
                    walkerImage
                        .frame(width: 24 * walker.scale, height: 24 * walker.scale)
                        .position(
                            x: animate ? proxy.size.width + 30 : -30,
                            y: proxy.size.height * walker.y
                        )
                        .animation(
                            .linear(duration: walker.duration).repeatForever(autoreverses: false).delay(walker.delay),
                            value: animate
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .opacity(0.35)
        .onAppear { animate = true }
    }

    @ViewBuilder
    private var walkerImage: some View {
        if let cgImage = LemmingSprites.standCGImageForUI {
            Image(cgImage, scale: 1, orientation: .up, label: Text("lemming"))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            EmptyView()
        }
    }
}
