import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(loc.string(.settingsLanguage)) {
                    Picker(loc.string(.settingsLanguage), selection: Binding(
                        get: { loc.language },
                        set: { loc.language = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(loc.string(.settingsTheme)) {
                    Picker(loc.string(.settingsTheme), selection: Binding(
                        get: { theme.scheme },
                        set: { theme.scheme = $0 }
                    )) {
                        ForEach(AppColorScheme.allCases) { s in
                            Text(loc.string(s.titleKey)).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(loc.string(.developedBy)).font(.footnote.weight(.semibold))
                        Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                        Link("github.com/VidiPT89", destination: URL(string: "https://github.com/VidiPT89/")!)
                    }
                    .tint(.brandOrange)
                }
            }
            .navigationTitle(loc.string(.settingsTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.string(.settingsClose)) { dismiss() }
                }
            }
        }
    }
}
