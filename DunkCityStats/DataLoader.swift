import Foundation
import Combine

final class DataLoader: ObservableObject {
    enum StatsMode: String, CaseIterable, Identifiable {
        case max = "Max"
        case initial = "Init"

        var id: String { rawValue }

        var displayNameKey: String {
            switch self {
            case .max:
                return "stats_mode.max"
            case .initial:
                return "stats_mode.init"
            }
        }
    }

    @Published private(set) var players: [Player] = []
    @Published var statsMode: StatsMode = .max {
        didSet {
            guard oldValue != statsMode else { return }
            loadData()
        }
    }

    init() {
        loadData()
    }

    func loadData() {
        guard let url = Bundle.main.url(forResource: "DunkCityStats", withExtension: "csv") else {
            print("CSV file not found")
            return
        }

        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            players = parsePlayers(from: data, mode: statsMode)
        } catch {
            print("Error parsing CSV: \(error)")
        }
    }

    private func parsePlayers(from csv: String, mode: StatsMode) -> [Player] {
        let rows = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard rows.count > 1 else { return [] }

        let headers = parseCSVRow(rows[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var headerIndex: [String: Int] = [:]
        for (index, name) in headers.enumerated() {
            let key = normalizedHeader(name)
            // Keep the first occurrence to avoid duplicate-key crashes.
            if headerIndex[key] == nil {
                headerIndex[key] = index
            }
        }

        var parsedPlayers: [Player] = []

        for row in rows.dropFirst() {
            let trimmedRow = row.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedRow.isEmpty {
                continue
            }

            let columns = parseCSVRow(trimmedRow)

            func parsedInt(_ value: String?) -> Int? {
                let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                if let intValue = Int(trimmed) {
                    return intValue
                }
                if let doubleValue = Double(trimmed) {
                    return Int(doubleValue.rounded())
                }
                return nil
            }

            func csvValue(_ aliases: [String]) -> String {
                for alias in aliases {
                    let key = normalizedHeader(alias)
                    if let idx = headerIndex[key], idx < columns.count {
                        return columns[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                return ""
            }

            func intValueOptional(_ aliases: [String]) -> Int? {
                for alias in aliases {
                    let key = normalizedHeader(alias)
                    if let idx = headerIndex[key], idx < columns.count,
                       let parsed = parsedInt(columns[idx]) {
                        return parsed
                    }
                }
                return nil
            }

            func intValue(_ aliases: [String], default defaultValue: Int = 0) -> Int {
                intValueOptional(aliases) ?? defaultValue
            }

            func initAliases(_ names: [String]) -> [String] {
                var aliases: [String] = []
                for name in names {
                    aliases.append("\(name) Init")
                    aliases.append("\(name) Initial")
                    aliases.append("Init \(name)")
                    aliases.append("Initial \(name)")
                    aliases.append("\(name)_init")
                }
                return aliases
            }

            func maxAliases(_ names: [String]) -> [String] {
                var aliases: [String] = []
                for name in names {
                    aliases.append("\(name) Max")
                    aliases.append("Max \(name)")
                    aliases.append("\(name)_max")
                }
                return aliases
            }

            func statValue(_ names: [String]) -> Int {
                switch mode {
                case .initial:
                    if let value = intValueOptional(initAliases(names)) {
                        return value
                    }
                    return intValue(names)
                case .max:
                    if let value = intValueOptional(maxAliases(names)) {
                        return value
                    }
                    return intValue(names)
                }
            }

            let dunk = statValue(["Dunk"])
            let layupClose = statValue(["Layup/Close", "Layup Close", "Layup"])
            let midRange = statValue(["Mid-range", "Midrange", "Mid"])
            let threePoint = statValue(["3-pt", "3pt", "Three Point"])
            let dribble = statValue(["Dribble"])
            let steal = statValue(["Steal", "STL"])
            let block = statValue(["Block", "BLK"])
            let rebound = statValue(["Rebound", "REB"])
            let contest = statValue(["Contest"])
            let pass = statValue(["Pass"])
            let vertical = statValue(["Vertical"])
            let movement = statValue(["Movement", "Speed"])
            let consistency = statValue(["Consistency"])
            let strength = statValue(["Strength"])

            let player = Player(
                name: csvValue(["Player"]),
                position: csvValue(["Position"]),
                dunk: dunk,
                layupClose: layupClose,
                midRange: midRange,
                threePoint: threePoint,
                dribble: dribble,
                steal: steal,
                block: block,
                rebound: rebound,
                contest: contest,
                pass: pass,
                vertical: vertical,
                movement: movement,
                consistency: consistency,
                strength: strength
            )
            if !player.name.isEmpty {
                parsedPlayers.append(player)
            }
        }

        return parsedPlayers.sorted { $0.total > $1.total }
    }

    private func normalizedHeader(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "#", with: " number ")
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var isInsideQuotes = false

        for character in row {
            if character == "\"" {
                isInsideQuotes.toggle()
            } else if character == "," && !isInsideQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(character)
            }
        }

        values.append(currentValue)
        return values
    }
}
