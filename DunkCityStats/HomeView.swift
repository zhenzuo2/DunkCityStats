import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var dataLoader: DataLoader
    @EnvironmentObject private var feedbackStore: PlayerFeedbackStore
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @Environment(\.locale) private var locale

    private var playersLoadedText: String {
        L10n.format("home.players_loaded", locale: locale, dataLoader.players.count)
    }

    private var showingModeText: String {
        L10n.format(
            "home.showing_mode",
            locale: locale,
            L10n.string(dataLoader.statsMode.displayNameKey, locale: locale)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("home.title")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)

                            Text(playersLoadedText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 8)

                            NavigationLink(destination: StatsRankView()) {
                                Text("home.button_rank")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                            }
                            .padding(.horizontal, 40)

                            NavigationLink(destination: ComparePlayersView()) {
                                Text("home.button_compare")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                            }
                            .padding(.horizontal, 40)

                            NavigationLink(destination: RosterView()) {
                                Text("home.button_all_players")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                            }
                            .padding(.horizontal, 40)

                            NavigationLink(destination: FavoritesView()) {
                                Text("home.button_favorites")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.pink)
                                    .cornerRadius(15)
                                    .shadow(radius: 5)
                            }
                            .padding(.horizontal, 40)

                            VStack(spacing: 10) {
                                Text("home.stats_mode")
                                    .font(.headline)

                                Picker("home.stats_mode", selection: $dataLoader.statsMode) {
                                    ForEach(DataLoader.StatsMode.allCases) { mode in
                                        Text(LocalizedStringKey(mode.displayNameKey)).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Text(showingModeText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 40)

                            Spacer(minLength: 12)
                        }
                        .padding(.bottom, 24)
                        .frame(minHeight: geo.size.height)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Label("home.button_settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .onAppear {
                favoritesStore.configureSession(
                    isSignedIn: feedbackStore.isSignedInWithApple,
                    userIdentifier: feedbackStore.signedInUserIdentifier
                )
            }
            .onChange(of: feedbackStore.isSignedInWithApple) { _, _ in
                favoritesStore.configureSession(
                    isSignedIn: feedbackStore.isSignedInWithApple,
                    userIdentifier: feedbackStore.signedInUserIdentifier
                )
            }
            .onChange(of: feedbackStore.signedInUserIdentifier) { _, _ in
                favoritesStore.configureSession(
                    isSignedIn: feedbackStore.isSignedInWithApple,
                    userIdentifier: feedbackStore.signedInUserIdentifier
                )
            }
        }
    }
}
