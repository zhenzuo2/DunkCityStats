import SwiftUI

struct RankMetric: Identifiable, Hashable {
    let id: String
    let nameKey: String
    let value: (Player) -> Double
    let format: (Double) -> String

    init(
        id: String,
        nameKey: String,
        value: @escaping (Player) -> Double,
        format: @escaping (Double) -> String = { String(Int($0)) }
    ) {
        self.id = id
        self.nameKey = nameKey
        self.value = value
        self.format = format
    }

    static func == (lhs: RankMetric, rhs: RankMetric) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func displayName(locale: Locale) -> String {
        L10n.string(nameKey, locale: locale)
    }
}

struct StatsRankView: View {
    @EnvironmentObject private var dataLoader: DataLoader
    @Environment(\.locale) private var locale
    @State private var selectedMetricID = "total"
    @State private var selectedRoleID = "all"

    private let metrics: [RankMetric] = [
        RankMetric(id: "total", nameKey: "rank.metric.total", value: { Double($0.total) }),
        RankMetric(id: "avg", nameKey: "rank.metric.avg", value: { $0.avgAttribute }, format: { String(format: "%.1f", $0) }),
        RankMetric(id: "offense", nameKey: "rank.metric.offense", value: { Double($0.offense) }),
        RankMetric(id: "defense", nameKey: "rank.metric.defense", value: { Double($0.defense) }),
        RankMetric(id: "athleticism", nameKey: "rank.metric.athleticism", value: { Double($0.athleticism) }),
        RankMetric(id: "dunk", nameKey: "rank.metric.dunk", value: { Double($0.dunk) }),
        RankMetric(id: "layupClose", nameKey: "rank.metric.layup_close", value: { Double($0.layupClose) }),
        RankMetric(id: "midRange", nameKey: "rank.metric.mid_range", value: { Double($0.midRange) }),
        RankMetric(id: "threePoint", nameKey: "rank.metric.three_pt", value: { Double($0.threePoint) }),
        RankMetric(id: "dribble", nameKey: "rank.metric.dribble", value: { Double($0.dribble) }),
        RankMetric(id: "steal", nameKey: "rank.metric.steal", value: { Double($0.steal) }),
        RankMetric(id: "block", nameKey: "rank.metric.block", value: { Double($0.block) }),
        RankMetric(id: "rebound", nameKey: "rank.metric.rebound", value: { Double($0.rebound) }),
        RankMetric(id: "contest", nameKey: "rank.metric.contest", value: { Double($0.contest) }),
        RankMetric(id: "pass", nameKey: "rank.metric.pass", value: { Double($0.pass) }),
        RankMetric(id: "vertical", nameKey: "rank.metric.vertical", value: { Double($0.vertical) }),
        RankMetric(id: "movement", nameKey: "rank.metric.movement", value: { Double($0.movement) }),
        RankMetric(id: "consistency", nameKey: "rank.metric.consistency", value: { Double($0.consistency) }),
        RankMetric(id: "strength", nameKey: "rank.metric.strength", value: { Double($0.strength) })
    ]

    private var selectedMetric: RankMetric {
        metrics.first(where: { $0.id == selectedMetricID }) ?? metrics[0]
    }

    private var roleOptions: [String] {
        let preferredOrder = ["C", "PF", "SF", "SG", "PG"]
        let roles = Set(
            dataLoader.players
                .map { $0.position.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        return ["all"] + roles.sorted { lhs, rhs in
            let leftIndex = preferredOrder.firstIndex(of: lhs) ?? Int.max
            let rightIndex = preferredOrder.firstIndex(of: rhs) ?? Int.max
            if leftIndex == rightIndex {
                return lhs < rhs
            }
            return leftIndex < rightIndex
        }
    }

    private func roleDisplayName(_ role: String) -> String {
        if role == "all" {
            return L10n.string("rank.role.all", locale: locale)
        }
        return role
    }

    private let attributeExplanations: [String: [String]] = [
        "total": [
            "rank.explain.total.1"
        ],
        "avg": [
            "rank.explain.avg.1"
        ],
        "offense": [
            "rank.explain.offense.1"
        ],
        "defense": [
            "rank.explain.defense.1"
        ],
        "athleticism": [
            "rank.explain.athleticism.1"
        ],
        "dunk": [
            "rank.explain.dunk.1",
            "rank.explain.dunk.2",
            "rank.explain.dunk.3",
            "rank.explain.dunk.4"
        ],
        "layupClose": [
            "rank.explain.layup_close.1",
            "rank.explain.layup_close.2",
            "rank.explain.layup_close.3",
            "rank.explain.layup_close.4",
            "rank.explain.layup_close.5"
        ],
        "midRange": [
            "rank.explain.mid_range.1",
            "rank.explain.mid_range.2",
            "rank.explain.mid_range.3"
        ],
        "threePoint": [
            "rank.explain.three_pt.1",
            "rank.explain.three_pt.2",
            "rank.explain.three_pt.3"
        ],
        "dribble": [
            "rank.explain.dribble.1",
            "rank.explain.dribble.2",
            "rank.explain.dribble.3"
        ],
        "steal": [
            "rank.explain.steal.1",
            "rank.explain.steal.2",
            "rank.explain.steal.3",
            "rank.explain.steal.4"
        ],
        "block": [
            "rank.explain.block.1",
            "rank.explain.block.2",
            "rank.explain.block.3",
            "rank.explain.block.4"
        ],
        "rebound": [
            "rank.explain.rebound.1",
            "rank.explain.rebound.2"
        ],
        "contest": [
            "rank.explain.contest.1"
        ],
        "movement": [
            "rank.explain.movement.1"
        ],
        "pass": [
            "rank.explain.pass.1",
            "rank.explain.pass.2",
            "rank.explain.pass.3",
            "rank.explain.pass.4",
            "rank.explain.pass.5",
            "rank.explain.pass.6",
            "rank.explain.pass.7",
            "rank.explain.pass.8"
        ],
        "vertical": [
            "rank.explain.vertical.1",
            "rank.explain.vertical.2",
            "rank.explain.vertical.3",
            "rank.explain.vertical.4",
            "rank.explain.vertical.5",
            "rank.explain.vertical.6"
        ],
        "strength": [
            "rank.explain.strength.1",
            "rank.explain.strength.2",
            "rank.explain.strength.3",
            "rank.explain.strength.4",
            "rank.explain.strength.5",
            "rank.explain.strength.6"
        ],
        "consistency": [
            "rank.explain.consistency.1",
            "rank.explain.consistency.2",
            "rank.explain.consistency.3",
            "rank.explain.consistency.4",
            "rank.explain.consistency.5",
            "rank.explain.consistency.6"
        ]
    ]

    private var selectedExplanationLines: [String] {
        (attributeExplanations[selectedMetricID] ?? []).map { L10n.string($0, locale: locale) }
    }

    private var explanationTitle: String {
        L10n.format("rank.explanation_title", locale: locale, selectedMetric.displayName(locale: locale))
    }

    private var filteredPlayers: [Player] {
        if selectedRoleID == "all" {
            return dataLoader.players
        }
        return dataLoader.players.filter {
            $0.position.trimmingCharacters(in: .whitespacesAndNewlines) == selectedRoleID
        }
    }

    private var sortedPlayers: [Player] {
        filteredPlayers.sorted { lhs, rhs in
            let leftValue = selectedMetric.value(lhs)
            let rightValue = selectedMetric.value(rhs)
            if leftValue == rightValue {
                return lhs.total > rhs.total
            }
            return leftValue > rightValue
        }
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Text("rank.role")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Picker("rank.filter_role", selection: $selectedRoleID) {
                        ForEach(roleOptions, id: \.self) { role in
                            Text(roleDisplayName(role)).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.green)
                }

                HStack {
                    Text("rank.by")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Picker("rank.sort_by", selection: $selectedMetricID) {
                        ForEach(metrics) { metric in
                            Text(metric.displayName(locale: locale)).tag(metric.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.green)
                }
            }
            .padding()
            .background(Color.white.opacity(0.72))

            if !selectedExplanationLines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(explanationTitle)
                        .font(.headline)
                    ForEach(Array(selectedExplanationLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .fontWeight(.bold)
                            Text(line)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
            }

            List(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                NavigationLink(destination: PlayerDetailView(player: player)) {
                    HStack {
                        Text("#\(index + 1)")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .frame(width: 35, alignment: .leading)

                        PlayerHeadshotView(player: player, size: 42, cornerRadius: 9)

                        VStack(alignment: .leading) {
                            Text(player.name)
                                .font(.headline)
                            Text(player.position)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Text(selectedMetric.format(selectedMetric.value(player)))
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }
                .listRowBackground(Color.white.opacity(0.72))
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.plain)
        }
        }
        .navigationTitle("rank.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
