import SwiftUI

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var titleKey: LocKey {
        switch self {
        case .system: return .settingsThemeSystem
        case .light: return .settingsThemeLight
        case .dark: return .settingsThemeDark
        }
    }
}

final class ThemeManager: ObservableObject {
    @AppStorage("appColorScheme") var storedScheme: String = AppColorScheme.system.rawValue

    var scheme: AppColorScheme {
        get { AppColorScheme(rawValue: storedScheme) ?? .system }
        set { storedScheme = newValue.rawValue; objectWillChange.send() }
    }
}

extension Color {
    /// Brand palette derived from ividi.dev — orange, burnt amber, near-black.
    /// Backed by Asset Catalog color sets (`Assets.xcassets`), never hardcoded hex.
    static let brandOrange = Color("BrandOrange")
    static let brandAmber = Color("BrandAmber")
    static let brandDeepAmber = Color("BrandDeepAmber")
    static let brandBlack = Color("BrandBlack")
    static let brandCharcoal = Color("BrandCharcoal")
    static let brandCream = Color("BrandCream")

    static let brandGradient = LinearGradient(
        colors: [.brandOrange, .brandAmber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func brandBackground(for scheme: ColorScheme) -> LinearGradient {
        switch scheme {
        case .dark:
            return LinearGradient(colors: [.brandBlack, .brandCharcoal, .brandDeepAmber.opacity(0.35)],
                                   startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [.brandCream, Color.brandAmber.opacity(0.18)],
                                   startPoint: .top, endPoint: .bottom)
        }
    }
}
