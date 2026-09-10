import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case pt
    case en

    var id: String { rawValue }

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
    case menuContinue
    case menuQuit
    case settingsTitle
    case settingsLanguage
    case settingsTheme
    case settingsThemeSystem
    case settingsThemeLight
    case settingsThemeDark
    case settingsClose
    case levelsTitle
    case levelLocked
    case hudLemmingsOut
    case hudLemmingsSaved
    case hudLemmingsNeeded
    case hudTimeLeft
    case hudPause
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
}

private let translations: [AppLanguage: [LocKey: String]] = [
    .en: [
        .appName: "iLemmings",
        .tagline: "Guide them. Save them.",
        .developedBy: "Developed by David Arsénio Martins",
        .menuPlay: "Play",
        .menuLevels: "Levels",
        .menuSettings: "Settings",
        .menuContinue: "Continue",
        .menuQuit: "Quit",
        .settingsTitle: "Settings",
        .settingsLanguage: "Language",
        .settingsTheme: "Appearance",
        .settingsThemeSystem: "System",
        .settingsThemeLight: "Light",
        .settingsThemeDark: "Dark",
        .settingsClose: "Done",
        .levelsTitle: "Levels",
        .levelLocked: "Locked",
        .hudLemmingsOut: "Out",
        .hudLemmingsSaved: "Saved",
        .hudLemmingsNeeded: "Needed",
        .hudTimeLeft: "Time",
        .hudPause: "Pause",
        .skillClimber: "Climber",
        .skillFloater: "Floater",
        .skillBomber: "Bomber",
        .skillBlocker: "Blocker",
        .skillBuilder: "Builder",
        .skillBasher: "Basher",
        .skillMiner: "Miner",
        .skillDigger: "Digger",
        .pauseTitle: "Paused",
        .pauseResume: "Resume",
        .pauseRestart: "Restart",
        .pauseMenu: "Main Menu",
        .levelWinTitle: "Level Complete!",
        .levelWinBody: "You saved enough lemmings.",
        .levelLoseTitle: "Level Failed",
        .levelLoseBody: "Not enough lemmings made it out.",
        .nextLevel: "Next Level",
        .retryLevel: "Retry",
        .backToLevels: "Levels",
    ],
    .pt: [
        .appName: "iLemmings",
        .tagline: "Guia-os. Salva-os.",
        .developedBy: "Criado por David Arsénio Martins",
        .menuPlay: "Jogar",
        .menuLevels: "Níveis",
        .menuSettings: "Definições",
        .menuContinue: "Continuar",
        .menuQuit: "Sair",
        .settingsTitle: "Definições",
        .settingsLanguage: "Idioma",
        .settingsTheme: "Aparência",
        .settingsThemeSystem: "Sistema",
        .settingsThemeLight: "Claro",
        .settingsThemeDark: "Escuro",
        .settingsClose: "Concluído",
        .levelsTitle: "Níveis",
        .levelLocked: "Bloqueado",
        .hudLemmingsOut: "No terreno",
        .hudLemmingsSaved: "Salvos",
        .hudLemmingsNeeded: "Necessários",
        .hudTimeLeft: "Tempo",
        .hudPause: "Pausa",
        .skillClimber: "Escalador",
        .skillFloater: "Paraquedas",
        .skillBomber: "Explosivo",
        .skillBlocker: "Bloqueador",
        .skillBuilder: "Construtor",
        .skillBasher: "Escavador Horizontal",
        .skillMiner: "Mineiro",
        .skillDigger: "Escavador Vertical",
        .pauseTitle: "Em Pausa",
        .pauseResume: "Retomar",
        .pauseRestart: "Reiniciar",
        .pauseMenu: "Menu Principal",
        .levelWinTitle: "Nível Concluído!",
        .levelWinBody: "Salvaste lemmings suficientes.",
        .levelLoseTitle: "Nível Falhado",
        .levelLoseBody: "Não saíram lemmings suficientes.",
        .nextLevel: "Próximo Nível",
        .retryLevel: "Repetir",
        .backToLevels: "Níveis",
    ],
]

final class LocalizationManager: ObservableObject {
    @AppStorage("appLanguage") private var storedLanguage: String = AppLanguage.pt.rawValue

    var language: AppLanguage {
        get { AppLanguage(rawValue: storedLanguage) ?? .pt }
        set { storedLanguage = newValue.rawValue; objectWillChange.send() }
    }

    func string(_ key: LocKey) -> String {
        translations[language]?[key] ?? translations[.en]?[key] ?? key.rawValue
    }
}

extension View {
    func loc(_ key: LocKey, using manager: LocalizationManager) -> String {
        manager.string(key)
    }
}
