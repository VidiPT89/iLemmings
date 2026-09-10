import SwiftUI

struct RootView: View {
    @StateObject private var loc = LocalizationManager()
    @StateObject private var theme = ThemeManager()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(onFinished: { showSplash = false })
                    .transition(.opacity)
            } else {
                MainMenuView()
                    .transition(.opacity)
            }
        }
        .environmentObject(loc)
        .environmentObject(theme)
        .preferredColorScheme(theme.scheme.colorScheme)
        .animation(.easeInOut(duration: 0.4), value: showSplash)
    }
}
