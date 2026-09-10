import SwiftUI

/// Lightweight SwiftUI confetti burst for the win screen — no SpriteKit
/// scene switch needed just for a celebration effect.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let duration: Double
        let color: Color
        let rotation: Double
    }

    private let pieces: [Piece] = (0..<28).map { _ in
        Piece(
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...0.4),
            duration: Double.random(in: 1.2...2.0),
            color: [Color.brandOrange, Color.brandAmber, .white, .green].randomElement()!,
            rotation: Double.random(in: 0...360)
        )
    }

    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: 7, height: 10)
                        .rotationEffect(.degrees(animate ? piece.rotation + 180 : piece.rotation))
                        .position(x: piece.x * proxy.size.width, y: animate ? proxy.size.height + 20 : -20)
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
