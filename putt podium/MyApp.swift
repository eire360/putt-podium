import SwiftUI

@main struct MyApp: App {
    init() {
        #if DEBUG
        // Fixtures are opt-in, debug-only, and restricted to the separate Studio app.
        if Bundle.main.bundleIdentifier == "com.calvinorourke.puttpodium.studiov22" {
            let arguments = ProcessInfo.processInfo.arguments
            let defaults = UserDefaults.standard
            if arguments.contains("--studio-reset") {
                for key in ["puttpodium.round.v2", "puttparty.round.v1", "puttpodium.round.recovery", "puttpodium.round.recovery.history", "puttpodium.haptics"] { defaults.removeObject(forKey: key) }
            }
            if arguments.contains(where: { $0.hasPrefix("--studio-fixture-") }) {
                let eight = arguments.contains("--studio-fixture-eight") || arguments.contains("--studio-fixture-play8")
                let stress = arguments.contains("--studio-fixture-stress")
                let playing = arguments.contains("--studio-fixture-play2") || arguments.contains("--studio-fixture-play8") || stress
                let ready = arguments.contains("--studio-fixture-finish-ready")
                var names = eight ? ["Alex", "Blair", "Casey", "Devin", "Elliot", "Francesca Longname", "Gabriel", "Harper"] : ["Alex", "Blair"]
                if stress { names[0] = String(repeating: "W", count: 40) }
                let players = names.enumerated().map { index, name in
                    Golfer(name: name, scores: (0..<9).map { hole in playing && hole > 0 ? nil : Optional(stress && index == 0 && hole == 0 ? 999 : eight ? (index < 2 ? 2 : index + 1) : index + 2) })
                }
                let round = RoundData(players: players, holes: 9, currentHole: playing ? 0 : 8, finished: !playing && !ready)
                struct FixtureEnvelope: Encodable { let schemaVersion = 2; let round: RoundData }
                if let data = try? JSONEncoder().encode(FixtureEnvelope(round: round)) { defaults.set(data, forKey: "puttpodium.round.v2") }
            }
        }
        #endif
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
