import SwiftUI
import AuthenticationServices

struct FavoritesView: View {
    @EnvironmentObject private var dataLoader: DataLoader
    @EnvironmentObject private var feedbackStore: PlayerFeedbackStore
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @Environment(\.locale) private var locale
    @State private var searchText = ""

    private var canUseFavorites: Bool {
        feedbackStore.isSignedInWithApple &&
        (feedbackStore.signedInUserIdentifier?.isEmpty == false)
    }

    private var favoritePlayers: [Player] {
        dataLoader.players.filter { favoritesStore.isFavorite($0.name) }
    }

    private var filteredPlayers: [Player] {
        guard !searchText.isEmpty else { return favoritePlayers }
        return favoritePlayers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func totalText(_ total: Int) -> String {
        L10n.format("roster.total_format", locale: locale, total)
    }

    private func avgText(_ avg: Double) -> String {
        L10n.format("roster.avg_format", locale: locale, avg)
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            if !canUseFavorites {
                VStack(spacing: 14) {
                    Text("favorites.sign_in_required")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("favorites.sign_in_hint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        feedbackStore.handleSignInResult(result)
                        favoritesStore.configureSession(
                            isSignedIn: feedbackStore.isSignedInWithApple,
                            userIdentifier: feedbackStore.signedInUserIdentifier
                        )
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .padding(.horizontal, 24)
                }
                .padding()
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                if filteredPlayers.isEmpty {
                    ContentUnavailableView {
                        Label("favorites.empty_title", systemImage: "star.slash")
                    } description: {
                        Text("favorites.empty_message")
                    }
                } else {
                    List(filteredPlayers) { player in
                        NavigationLink(destination: PlayerDetailView(player: player)) {
                            HStack {
                                PlayerHeadshotView(player: player, size: 54, cornerRadius: 12)

                                VStack(alignment: .leading) {
                                    HStack(spacing: 6) {
                                        Text(player.name)
                                            .font(.headline)
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundStyle(.yellow)
                                    }

                                    Text(player.position)
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text(totalText(player.total))
                                        .fontWeight(.bold)
                                        .foregroundStyle(colorForTotal(player.total))
                                    Text(avgText(player.avgAttribute))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.72))
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
        .navigationTitle("favorites.title")
        .searchable(text: $searchText, prompt: Text("favorites.search_prompt"))
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
        .overlay(alignment: .bottom) {
            if let syncStatusMessage = favoritesStore.syncStatusMessage, !syncStatusMessage.isEmpty {
                Text("\(L10n.string("favorites.sync_error", locale: locale)) \(syncStatusMessage)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }

    private func colorForTotal(_ total: Int) -> Color {
        if total >= 1400 { return .purple }
        if total >= 1350 { return .orange }
        if total >= 1300 { return .blue }
        return .green
    }
}
