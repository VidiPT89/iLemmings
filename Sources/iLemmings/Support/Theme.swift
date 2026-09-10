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
    static let brandOrange = Color(red: 0.98, green: 0.45, blue: 0.09)
    static let brandAmber = Color(red: 0.85, green: 0.58, blue: 0.09)
    static let brandDeepAmber = Color(red: 0.62, green: 0.34, blue: 0.05)
    static let brandBlack = Color(red: 0.07, green: 0.06, blue: 0.05)
    static let brandCharcoal = Color(red: 0.12, green: 0.10, blue: 0.09)
    static let brandCream = Color(red: 0.98, green: 0.94, blue: 0.87)

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
