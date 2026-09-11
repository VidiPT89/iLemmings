import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case pt
    case en

    var id: String { rawValue }

    /// Matches the `.lproj` folder name shipped in Resources.
    var lprojName: String {
        switch self {
        case .pt: return "pt-PT"
        case .en: return "en"
        }
    }

    var displayName: String {
        switch self {
        case .pt: return "Português"
        case .en: return "English"
        }
    }
}

enum LocKey: String {
    case appName
    case tagline
    case developedBy
    case menuPlay
    case menuLevels
    case menuSettings
    case settingsTitle
    case settingsLanguage
    case settingsTheme
    case settingsThemeSystem
    case settingsThemeLight
    case settingsThemeDark
    case settingsSound
    case settingsClose
    case levelsTitle
    case hudLemmingsOut
    case hudLemmingsSaved
    case hudLemmingsNeeded
    case hudTimeLeft
    case skillClimber
    case skillFloater
    case skillBomber
    case skillBlocker
    case skillBuilder
    case skillBasher
    case skillMiner
    case skillDigger
    case pauseTitle
    case pauseResume
    case pauseRestart
    case pauseMenu
    case levelWinTitle
    case levelWinBody
    case levelLoseTitle
    case levelLoseBody
    case nextLevel
    case retryLevel
    case backToLevels
    case packFun
    case packTricky
    case packTaxing
    case packMayhem
}

/// Loads strings from the real `pt-PT.lproj` / `en.lproj` bundles bundled
/// with the app, so the in-app language switch doesn't depend on the
/// device's system language and can flip instantly at runtime.
final class LocalizationManager: ObservableObject {
    @AppStorage("appLanguage") private var storedLanguage: String = AppLanguage.pt.rawValue

    var language: AppLanguage {
        get { AppLanguage(rawValue: storedLanguage) ?? .pt }
        set { storedLanguage = newValue.rawValue; objectWillChange.send() }
    }

    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.lprojName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    func string(_ key: LocKey) -> String {
        bundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: "Localizable")
    }
}
