import SwiftUI

struct SplashView: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.colorScheme) private var scheme
    let onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var creditsOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.brandBackground(for: scheme).ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Image("LemmingMark")
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .brandOrange.opacity(0.5), radius: 20)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Text(loc.string(.appName))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.brandGradient)
                    .opacity(logoOpacity)

                Text(loc.string(.tagline))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .opacity(logoOpacity)

                Spacer()

                VStack(spacing: 6) {
                    Text(loc.string(.developedBy))
                        .font(.footnote.weight(.semibold))
                    Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                        .font(.footnote)
                    Link("github.com/VidiPT89", destination: URL(string: "https://github.com/VidiPT89/")!)
                        .font(.footnote)
                }
                .tint(.brandOrange)
                .opacity(creditsOpacity)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.5)) {
                creditsOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeOut(duration: 0.4)) {
                    onFinished()
                }
            }
        }
    }
}
