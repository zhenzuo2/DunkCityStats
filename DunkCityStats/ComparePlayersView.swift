import SwiftUI

struct ComparePlayersView: View {
    @EnvironmentObject private var dataLoader: DataLoader
    @Environment(\.locale) private var locale
    @State private var selectedPlayer1ID: Player.ID?
    @State private var selectedPlayer2ID: Player.ID?

    private var player1: Player? {
        dataLoader.players.first { $0.id == selectedPlayer1ID }
    }

    private var player2: Player? {
        dataLoader.players.first { $0.id == selectedPlayer2ID }
    }

    private var player1Options: [Player] {
        dataLoader.players.filter { $0.id != selectedPlayer2ID }
    }

    private var player2Options: [Player] {
        dataLoader.players.filter { $0.id != selectedPlayer1ID }
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        selectorCard(
                            titleKey: "compare.player1",
                            tint: .blue,
                            selection: $selectedPlayer1ID,
                            options: player1Options,
                            selectedPlayer: player1
                        )
                        selectorCard(
                            titleKey: "compare.player2",
                            tint: .orange,
                            selection: $selectedPlayer2ID,
                            options: player2Options,
                            selectedPlayer: player2
                        )
                    }

                    if let player1, let player2 {
                        VStack(spacing: 16) {
                            RadarChartView(
                                player1: player1,
                                player2: player2,
                                metrics: Player.radarMetrics
                            )
                            .frame(height: 390)

                            HStack(spacing: 16) {
                                legend(name: player1.name, color: .blue)
                                legend(name: player2.name, color: .orange)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        comparisonSummary(player1: player1, player2: player2)
                        comparisonInsights(player1: player1, player2: player2)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.pie")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("compare.empty_prompt")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .background(Color.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("compare.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setDefaultSelectionIfNeeded()
        }
        .onChange(of: dataLoader.players.count) { _, _ in
            setDefaultSelectionIfNeeded()
        }
        .onChange(of: selectedPlayer1ID) { _, _ in
            ensureDistinctSelection(changedPlayer1: true)
        }
        .onChange(of: selectedPlayer2ID) { _, _ in
            ensureDistinctSelection(changedPlayer1: false)
        }
    }

    @ViewBuilder
    private func selectorCard(
        titleKey: String,
        tint: Color,
        selection: Binding<Player.ID?>,
        options: [Player],
        selectedPlayer: Player?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(titleKey))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
            if let selectedPlayer {
                HStack(spacing: 8) {
                    PlayerHeadshotView(player: selectedPlayer, size: 44, cornerRadius: 10)
                    Text(selectedPlayer.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
            }
            Picker(LocalizedStringKey(titleKey), selection: selection) {
                Text("compare.select").tag(Optional<Player.ID>.none)
                ForEach(options) { player in
                    Text(player.name).tag(Optional(player.id))
                }
            }
            .pickerStyle(.menu)
            .tint(tint)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func legend(name: String, color: Color) -> some View {
        let player = dataLoader.players.first(where: { $0.name == name })
        return HStack(spacing: 6) {
            if let player {
                PlayerHeadshotView(player: player, size: 24, cornerRadius: 6)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 24, height: 24)
            }
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .lineLimit(1)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func comparisonSummary(player1: Player, player2: Player) -> some View {
        let rows = [
            ("stat.full.total", player1.total, player2.total),
            ("stat.full.offense", player1.offense, player2.offense),
            ("stat.full.defense", player1.defense, player2.defense),
            ("stat.full.athleticism", player1.athleticism, player2.athleticism)
        ]

        return VStack(spacing: 10) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text("\(row.1)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(LocalizedStringKey(row.0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(row.2)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func comparisonInsights(player1: Player, player2: Player) -> some View {
        let points = keyComparisonPoints(player1: player1, player2: player2)

        return VStack(alignment: .leading, spacing: 10) {
            Text("compare.insights.title")
                .font(.headline)

            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .fontWeight(.bold)
                    Text(point)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func keyComparisonPoints(player1: Player, player2: Player) -> [String] {
        struct DiffMetric {
            let nameKey: String
            let v1: Int
            let v2: Int
            var deltaForP1: Int { v1 - v2 }
            var combined: Int { v1 + v2 }
        }

        let metrics: [DiffMetric] = Player.radarMetrics.map { metric in
            DiffMetric(
                nameKey: metric.nameKey,
                v1: player1[keyPath: metric.keyPath],
                v2: player2[keyPath: metric.keyPath]
            )
        }

        var points: [String] = []

        let totalDiff = player1.total - player2.total
        if totalDiff > 0 {
            points.append(localizedFormat("compare.insight.total_edge", player1.name, totalDiff))
        } else if totalDiff < 0 {
            points.append(localizedFormat("compare.insight.total_edge", player2.name, abs(totalDiff)))
        } else {
            points.append(localized("compare.insight.total_tied"))
        }

        let offenseDiff = player1.offense - player2.offense
        let defenseDiff = player1.defense - player2.defense
        let offenseLeader = offenseDiff >= 0 ? player1.name : player2.name
        let defenseLeader = defenseDiff >= 0 ? player1.name : player2.name
        points.append(
            localizedFormat(
                "compare.insight.offense_defense",
                offenseLeader,
                abs(offenseDiff),
                defenseLeader,
                abs(defenseDiff)
            )
        )

        if let p1Best = metrics.max(by: { $0.deltaForP1 < $1.deltaForP1 }), p1Best.deltaForP1 > 0 {
            points.append(
                localizedFormat(
                    "compare.insight.biggest_edge",
                    player1.name,
                    localized(p1Best.nameKey),
                    p1Best.deltaForP1
                )
            )
        }

        if let p2Best = metrics.min(by: { $0.deltaForP1 < $1.deltaForP1 }), p2Best.deltaForP1 < 0 {
            points.append(
                localizedFormat(
                    "compare.insight.biggest_edge",
                    player2.name,
                    localized(p2Best.nameKey),
                    abs(p2Best.deltaForP1)
                )
            )
        }

        let sharedStrong = metrics
            .sorted(by: { $0.combined > $1.combined })
            .prefix(2)
            .map { localized($0.nameKey) }
        if !sharedStrong.isEmpty {
            points.append(localizedFormat("compare.insight.shared_strength", joinedMetricNames(sharedStrong)))
        }

        let sharedWeak = metrics
            .sorted(by: { $0.combined < $1.combined })
            .prefix(2)
            .map { localized($0.nameKey) }
        if !sharedWeak.isEmpty {
            points.append(localizedFormat("compare.insight.shared_weak", joinedMetricNames(sharedWeak)))
        }

        return points
    }

    private func localized(_ key: String) -> String {
        L10n.string(key, locale: locale)
    }

    private func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        L10n.format(key, locale: locale, arguments: args)
    }

    private func joinedMetricNames(_ names: [String]) -> String {
        ListFormatter.localizedString(byJoining: names) ?? names.joined(separator: ", ")
    }

    private func setDefaultSelectionIfNeeded() {
        guard !dataLoader.players.isEmpty else { return }

        if selectedPlayer1ID == nil {
            selectedPlayer1ID = dataLoader.players.first?.id
        }

        if selectedPlayer2ID == nil || selectedPlayer2ID == selectedPlayer1ID {
            selectedPlayer2ID = dataLoader.players.first(where: { $0.id != selectedPlayer1ID })?.id
        }
    }

    private func ensureDistinctSelection(changedPlayer1: Bool) {
        guard selectedPlayer1ID == selectedPlayer2ID else { return }

        if changedPlayer1 {
            selectedPlayer2ID = dataLoader.players.first(where: { $0.id != selectedPlayer1ID })?.id
        } else {
            selectedPlayer1ID = dataLoader.players.first(where: { $0.id != selectedPlayer2ID })?.id
        }
    }
}
