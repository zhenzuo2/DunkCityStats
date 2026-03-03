import SwiftUI

struct SettingsView: View {
    @AppStorage("app_language_code") private var appLanguageCode = AppLanguage.english.rawValue

    var body: some View {
        ZStack {
            AppBackgroundView()

            Form {
                Section("settings.section.language") {
                    Picker("settings.language", selection: $appLanguageCode) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(LocalizedStringKey(language.localizedNameKey))
                                .tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Text("settings.language_hint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.white.opacity(0.72))
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !AppLanguage.allCases.contains(where: { $0.rawValue == appLanguageCode }) {
                appLanguageCode = AppLanguage.english.rawValue
            }
        }
    }
}
