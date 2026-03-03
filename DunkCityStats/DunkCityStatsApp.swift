import SwiftUI

@main
struct DunkCityStatsApp: App {
    @StateObject private var dataLoader = DataLoader()
    @StateObject private var feedbackStore = PlayerFeedbackStore()
    @StateObject private var favoritesStore = FavoritesStore()
    @AppStorage("app_language_code") private var appLanguageCode = AppLanguage.english.rawValue

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(dataLoader)
                .environmentObject(feedbackStore)
                .environmentObject(favoritesStore)
                .environment(\.locale, Locale(identifier: appLanguageCode))
        }
    }
}
