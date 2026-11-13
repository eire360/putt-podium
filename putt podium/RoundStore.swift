import Foundation
import Combine

/// One local round, with a versioned envelope and a non-destructive legacy migration.
@MainActor
final class RoundStore: ObservableObject {
    @Published private(set) var round: RoundData?
    @Published var notice: String?
    private let defaults: UserDefaults
    private let key = "puttpodium.round.v2"
    private let legacyKey = "puttparty.round.v1"
    private let recoveryKey = "puttpodium.round.recovery"
    private var blockedByRecovery = false

    private struct Envelope: Codable {
        var schemaVersion = 2
        let round: RoundData
    }
    private struct LegacyGolfer: Codable { let id: UUID; let name: String; let scores: [Int] }
    private struct LegacyRound: Codable { let players: [LegacyGolfer]; let holes: Int; let currentHole: Int; let finished: Bool }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    @discardableResult
    func start(names: [String], holes: Int) -> Bool {
        perform {
            guard [9,18].contains(holes) else { throw RoundError.invalidHoles }
            let clean = names.enumerated().map { index, value in
                let name = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                return name.isEmpty ? "Player \(index + 1)" : name
            }
            let value = RoundData(players: clean.map { Golfer(name: $0, scores: Array(repeating: nil, count: holes)) }, holes: holes)
            try value.validate()
            blockedByRecovery = false
            try persist(value)
            round = value
        }
    }

    @discardableResult
    func setScore(playerID: UUID, hole: Int, value: Int?) -> Bool {
        update { try $0.setScore(playerID: playerID, hole: hole, value: value) }
    }

    @discardableResult
    func move(to hole: Int) -> Bool { update { try $0.move(to: hole) } }

    @discardableResult
    func finish() -> Bool { update { try $0.finish() } }

    @discardableResult
    func reset() -> Bool {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: legacyKey)
        // Keep recovery bytes until a future deliberate recovery/deletion feature.
        blockedByRecovery = false
        round = nil
        notice = nil
        return true
    }

    private func update(_ mutation: (inout RoundData) throws -> Void) -> Bool {
        perform {
            guard !blockedByRecovery, var value = round else { throw RoundError.invalidPlayers }
            try mutation(&value)
            try value.validate()
            try persist(value)
            round = value
        }
    }

    private func perform(_ action: () throws -> Void) -> Bool {
        notice = nil
        do { try action(); return true }
        catch { notice = error.localizedDescription; return false }
    }

    private func persist(_ value: RoundData) throws {
        let data = try JSONEncoder().encode(Envelope(round: value))
        defaults.set(data, forKey: key)
        // UserDefaults has no throwing disk-write API. This checks the immediate value,
        // not durable storage, and never forces synchronous disk I/O.
        guard defaults.data(forKey: key) == data else { throw StoreError.writeFailed }
    }

    private func load() {
        if let original = defaults.object(forKey: key), defaults.data(forKey: key) == nil {
            preserveRecovery(original)
            blockedByRecovery = true
            notice = "Your saved round has an unsupported format. Its original data is preserved; start a new round when you’re ready."
            return
        }
        if let data = defaults.data(forKey: key) {
            do {
                let envelope = try JSONDecoder().decode(Envelope.self, from: data)
                guard envelope.schemaVersion == 2 else { throw StoreError.unsupportedVersion }
                try envelope.round.validate()
                round = envelope.round
            } catch { quarantine(data, message: "Your saved round couldn’t be opened. Its original data is preserved. You can start a new round without changing that recovery copy.") }
            return
        }
        guard let data = defaults.data(forKey: legacyKey) else {
            if let original = defaults.object(forKey: legacyKey) {
                preserveRecovery(original)
                blockedByRecovery = true
                notice = "Your previous save has an unsupported format. Start a new round when you’re ready."
            }
            return
        }
        do {
            let legacy = try JSONDecoder().decode(LegacyRound.self, from: data)
            let players = legacy.players.map { old in
                Golfer(id: old.id, name: String(old.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)), scores: old.scores.map { $0 == 0 ? nil : $0 })
            }
            var value = RoundData(players: players, holes: legacy.holes, currentHole: legacy.currentHole, finished: false)
            try value.validate()
            value.finished = legacy.finished && value.isComplete
            try persist(value)
            round = value
            notice = "Your previous round is ready. Old zero scores are now unentered; record them before finishing. The original save is preserved."
        } catch { quarantine(data, message: "Your previous round couldn’t be restored safely. Its original data is preserved. Start a new round when you’re ready.") }
    }

    private func quarantine(_ data: Data, message: String) {
        // Do not overwrite an earlier recovery record with another failed attempt.
        preserveRecovery(data)
        blockedByRecovery = true
        round = nil
        notice = message
    }

    private func preserveRecovery(_ original: Any) {
        if defaults.object(forKey: recoveryKey) == nil { defaults.set(original, forKey: recoveryKey) }
        // Retain distinct subsequent failures too, without replacing the first recovery copy.
        // A binary property list preserves Data and other supported preference value types.
        if let bytes = try? PropertyListSerialization.data(fromPropertyList: ["original": original], format: .binary, options: 0) {
            let archiveKey = recoveryKey + ".history"
            var archive = defaults.array(forKey: archiveKey) as? [Data] ?? []
            if !archive.contains(bytes) { archive.append(bytes); defaults.set(archive, forKey: archiveKey) }
        }
    }

    private enum StoreError: LocalizedError {
        case writeFailed, unsupportedVersion
        var errorDescription: String? {
            switch self {
            case .writeFailed: "The round couldn’t be saved. Please try again."
            case .unsupportedVersion: "This saved round uses a newer format."
            }
        }
    }
}
