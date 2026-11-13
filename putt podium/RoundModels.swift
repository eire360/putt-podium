import Foundation

enum FlexStyle: String, CaseIterable, Identifiable {
    case champion, roast, receipts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .champion: "Champion Flex"
        case .roast: "Friendly Trash Talk"
        case .receipts: "The Receipts"
        }
    }
    var shortName: String {
        switch self {
        case .champion: "CHAMPION"
        case .roast: "TRASH TALK"
        case .receipts: "RECEIPTS"
        }
    }
    var symbol: String {
        switch self {
        case .champion: "crown.fill"
        case .roast: "flame.fill"
        case .receipts: "list.number"
        }
    }
}

struct Golfer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var scores: [Int?]
    /// Recorded subtotal; a missing hole is never presented as a completed score.
    var total: Int { scores.compactMap { $0 }.reduce(0) { sum, value in
        let result = sum.addingReportingOverflow(value)
        return result.overflow ? Int.max : result.partialValue
    } }
    var enteredCount: Int { scores.compactMap { $0 }.count }
}

enum RoundError: LocalizedError {
    case invalidPlayers, invalidHoles, invalidIndex, invalidScores, invalidNames, incomplete, missingPlayer
    var errorDescription: String? {
        switch self {
        case .invalidPlayers: "A round needs 2–8 different players."
        case .invalidHoles: "Choose a 9- or 18-hole round."
        case .invalidIndex: "That hole isn’t in this round."
        case .invalidScores: "Scores must be whole numbers from 1 to 999, or left unentered."
        case .invalidNames: "Use player names with 1–40 characters."
        case .incomplete: "Record every player’s score on every hole before finishing."
        case .missingPlayer: "That player isn’t in this round."
        }
    }
}

struct RoundData: Codable, Equatable {
    var players: [Golfer]
    var holes: Int
    var currentHole: Int = 0
    var finished: Bool = false

    var isComplete: Bool {
        !players.isEmpty && [9, 18].contains(holes) && players.allSatisfy {
            $0.scores.count == holes && $0.scores.allSatisfy { $0 != nil }
        }
    }
    var missingCount: Int {
        guard [9,18].contains(holes), players.count <= 8 else { return 0 }
        return players.reduce(0) { $0 + max(0, holes - $1.enteredCount) }
    }
    var completedHoles: Int {
        guard !players.isEmpty, [9,18].contains(holes), players.allSatisfy({ $0.scores.count == holes }) else { return 0 }
        return (0..<holes).filter { hole in players.allSatisfy { $0.scores[hole] != nil } }.count
    }

    func validate() throws {
        guard (2...8).contains(players.count), Set(players.map(\.id)).count == players.count else { throw RoundError.invalidPlayers }
        guard [9,18].contains(holes) else { throw RoundError.invalidHoles }
        guard (0..<holes).contains(currentHole) else { throw RoundError.invalidIndex }
        for player in players {
            let trimmed = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed == player.name, player.name.count <= 40 else { throw RoundError.invalidNames }
            guard player.scores.count == holes else { throw RoundError.invalidScores }
            var total = 0
            for value in player.scores.compactMap({ $0 }) {
                guard (1...999).contains(value) else { throw RoundError.invalidScores }
                let result = total.addingReportingOverflow(value)
                guard !result.overflow else { throw RoundError.invalidScores }
                total = result.partialValue
            }
        }
        guard !finished || isComplete else { throw RoundError.incomplete }
    }

    mutating func setScore(playerID: UUID, hole: Int, value: Int?) throws {
        try validate()
        guard (0..<holes).contains(hole) else { throw RoundError.invalidIndex }
        if let value, !(1...999).contains(value) { throw RoundError.invalidScores }
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { throw RoundError.missingPlayer }
        if players[index].scores[hole] != value {
            players[index].scores[hole] = value
            finished = false
        }
    }

    mutating func move(to hole: Int) throws {
        try validate()
        guard (0..<holes).contains(hole) else { throw RoundError.invalidIndex }
        currentHole = hole
    }

    mutating func finish() throws {
        try validate()
        guard isComplete else { throw RoundError.incomplete }
        finished = true
    }
}

struct Standing: Identifiable, Equatable {
    let player: Golfer
    let rank: Int
    let label: String
    var id: UUID { player.id }
}

struct GameOutcome {
    let game: RoundData
    private var validCompletion: Bool {
        do { try game.validate(); return game.isComplete } catch { return false }
    }
    /// Do not compare unequal progress: until complete, keep the crew in entry order.
    var ranked: [Golfer] {
        guard validCompletion else { return game.players }
        return game.players.enumerated().sorted {
            $0.element.total == $1.element.total ? $0.offset < $1.offset : $0.element.total < $1.element.total
        }.map(\.element)
    }
    var standings: [Standing] {
        let ordered = ranked
        guard validCompletion else { return ordered.map { Standing(player: $0, rank: 0, label: "—") } }
        return ordered.enumerated().map { index, player in
            let rank = (ordered.firstIndex { $0.total == player.total } ?? index) + 1
            let tied = ordered.filter { $0.total == player.total }.count > 1
            return Standing(player: player, rank: rank, label: tied ? "T\(rank)" : "\(rank)")
        }
    }
    var leaders: [Golfer] {
        guard validCompletion, let first = ranked.first else { return [] }
        return ranked.filter { $0.total == first.total }
    }
    var isTie: Bool { leaders.count > 1 }
    var winnerNames: String { leaders.map(\.name).joined(separator: " & ") }
    var margin: Int {
        guard let first = leaders.first, !isTie,
              let second = ranked.first(where: { $0.total > first.total }) else { return 0 }
        return second.total - first.total
    }
    /// The notable putting achievement belongs to the winner, not another player.
    var aces: Int { leaders.count == 1 ? leaders[0].scores.filter { $0 == 1 }.count : 0 }
    var headline: String {
        guard validCompletion else { return "THE STORY\nISN’T FINISHED." }
        if isTie { return "ALL THAT TALK.\nFOR A TIE." }
        if margin >= 10 { return "THIS WASN’T\nA COMPETITION." }
        if margin == 1 { return "ONE STROKE.\nENDLESS BRAGGING." }
        if aces >= 2 { return "CHECK\nTHAT PUTTER." }
        return "THE GREEN\nHAS A CHAMP." 
    }
    func caption(for style: FlexStyle) -> String {
        guard validCompletion, let first = leaders.first else {
            return "Round in progress · \(game.missingCount) scores still to record. No final standings yet. #PuttPodium"
        }
        switch style {
        case .champion:
            return isTie
                ? "⛳ \(winnerNames) share the crown at \(first.total) strokes. Rematch required. #PuttPodium"
                : "👑 \(winnerNames) owns the green! \(first.total) strokes across \(game.holes) holes. #PuttPodium"
        case .roast:
            return "🔥 \(headline.replacingOccurrences(of: "\n", with: " ")) \(isTie ? "\(winnerNames) share the crown." : "\(winnerNames) wins by \(margin) stroke\(margin == 1 ? "" : "s").") #PuttPodium"
        case .receipts:
            let rows = standings.map { "\($0.label). \($0.player.name) — \($0.player.total)" }.joined(separator: "\n")
            return "🧾 PUTT PODIUM RECEIPTS · \(game.holes) HOLES\n\(rows)\nAll scores recorded. #PuttPodium"
        }
    }
}

/// A provisional comparison across only holes recorded by every player.
/// It never substitutes zero for an unentered score or declares a round winner.
struct LiveStandings {
    let game: RoundData

    private var commonHoles: [Int] {
        guard (try? game.validate()) != nil else { return [] }
        return (0..<game.holes).filter { hole in
            game.players.allSatisfy { $0.scores[hole] != nil }
        }
    }

    var completedHoleCount: Int { commonHoles.count }

    var standings: [Standing] {
        let common = commonHoles
        let comparable = game.players.map { player in
            Golfer(id: player.id, name: player.name, scores: common.map { player.scores[$0] })
        }
        guard !common.isEmpty else {
            return comparable.map { Standing(player: $0, rank: 0, label: "—") }
        }
        let ordered = comparable.enumerated().sorted {
            $0.element.total == $1.element.total ? $0.offset < $1.offset : $0.element.total < $1.element.total
        }.map(\.element)
        return ordered.enumerated().map { index, player in
            let rank = (ordered.firstIndex { $0.total == player.total } ?? index) + 1
            let tied = ordered.filter { $0.total == player.total }.count > 1
            return Standing(player: player, rank: rank, label: tied ? "T\(rank)" : "\(rank)")
        }
    }
}
