import SwiftUI

struct RosterView: View {
    @EnvironmentObject private var dataLoader: DataLoader
    @Environment(\.locale) private var locale
    @State private var searchText = ""

    private func totalText(_ total: Int) -> String {
        L10n.format("roster.total_format", locale: locale, total)
    }

    private func avgText(_ avg: Double) -> String {
        L10n.format("roster.avg_format", locale: locale, avg)
    }

    var filteredPlayers: [Player] {
        let base = dataLoader.players
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            List(filteredPlayers) { player in
                NavigationLink(destination: PlayerDetailView(player: player)) {
                    HStack {
                        PlayerHeadshotView(player: player, size: 54, cornerRadius: 12)

                        VStack(alignment: .leading) {
                            Text(player.name)
                                .font(.headline)
                            Text(player.position)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(totalText(player.total))
                                .fontWeight(.bold)
                                .foregroundColor(colorForTotal(player.total))
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
        .navigationTitle("roster.title")
        .searchable(text: $searchText, prompt: Text("roster.search_prompt"))
    }
    
    func colorForTotal(_ total: Int) -> Color {
        if total >= 1400 { return .purple }
        if total >= 1350 { return .orange }
        if total >= 1300 { return .blue }
        return .green
    }
}
