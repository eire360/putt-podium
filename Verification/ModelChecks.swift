import Foundation
@main
struct IndependentQA {
    @MainActor static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError("FAIL: " + message) }
            checks += 1
            print("PASS: " + message)
        }
        func invalid(_ round: RoundData) -> Bool { do { try round.validate(); return false } catch { return true } }
        func player(_ name: String, _ value: Int?) -> Golfer { Golfer(name: name, scores: Array(repeating: value, count: 9)) }
        var round = RoundData(players: [player("Alex", nil), player("Blair", nil)], holes: 9)
        try round.validate()
        expect(round.missingCount == 18 && !round.isComplete, "new round has18 missing scores, not a zero completion")
        expect(GameOutcome(game: round).leaders.isEmpty && GameOutcome(game: round).standings.allSatisfy { $0.rank == 0 }, "incomplete round has no leaders or competitive ranks")
        do { try round.finish(); fatalError("FAIL: incomplete finish accepted") } catch { expect(!round.finished, "incomplete finish rejected") }
        try round.setScore(playerID: round.players[0].id, hole: 0, value: 7)
        expect(round.players[0].total == 7 && round.missingCount == 17, "direct high score recorded in subtotal")
        try round.setScore(playerID: round.players[0].id, hole: 0, value: nil)
        expect(round.players[0].enteredCount == 0 && round.missingCount == 18, "clear restores unentered state")
        round.players = [player("Alex", 2),player("Blair",2),player("Casey",3)]
        try round.finish()
        let tied = GameOutcome(game: round)
        expect(tied.standings.map(\.label) == ["T1","T1","3"], "competition ties useT1,T1,3")
        expect(tied.winnerNames == "Alex & Blair" && tied.isTie, "all co-winners named")
        expect(tied.caption(for: .receipts).contains("T1. Blair"), "caption uses same tie rank")
        try round.setScore(playerID: round.players[0].id, hole: 0, value: 8)
        expect(!round.finished && round.players[0].total == 24, "finished correction reopens and recalculates")
        try round.finish()
        expect(GameOutcome(game: round).winnerNames == "Blair", "corrected winner recomputed")
        var full = RoundData(players: [player("a",2),player("B",2),player("c",3)],holes:9,finished:true)
        expect(GameOutcome(game: full).ranked.map(\.name) == ["a","B","c"], "tie display order stable from entry order")
        full.players = [Golfer(name:"Winner",scores:[2,2,2,2,2,2,2,2,2]),Golfer(name:"Other",scores:[1,1,7,2,2,2,2,2,2])]
        expect(GameOutcome(game: full).aces == 0 && !GameOutcome(game: full).headline.contains("PUTTER"), "other player aces not credited to winner")
        expect(invalid(RoundData(players: [],holes:9)), "empty players rejected")
        expect(invalid(RoundData(players: [player("A",2),player("B",2)],holes:12)), "unsupported holes rejected")
        var bad = RoundData(players:[player("A",2),player("B",2)],holes:9,currentHole:9)
        expect(invalid(bad), "invalid current index rejected")
        bad.currentHole = 0; bad.players[1].id = bad.players[0].id
        expect(invalid(bad), "duplicate player IDs rejected")
        bad.players[1].id = UUID(); bad.players[1].scores = []
        expect(invalid(bad), "mismatched score shape rejected")
        bad.players[1] = player(" B ",2)
        expect(invalid(bad), "untrimmed persisted names rejected")
        bad.players[1] = player("B",0)
        expect(invalid(bad), "recorded zero rejected rather than ranked")
        bad.players[1] = player("B",Int.max)
        expect(invalid(bad), "extreme malformed scores rejected")
        expect(GameOutcome(game: RoundData(players:[],holes:9)).caption(for:.champion).contains("No final standings"), "empty outcome caption never indexes missing player")
        let suite = "StudioQA." + UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let store = RoundStore(defaults:defaults)
        expect(store.start(names:["  Alex ",""],holes:9), "store starts normalized names")
        expect(store.round?.players.map(\.name) == ["Alex","Player 2"], "store normalizes blanks and whitespace")
        expect(!store.finish() && store.notice != nil, "store blocks completion and exposes explanation")
        let id = store.round!.players[0].id
        expect(store.setScore(playerID:id,hole:0,value:6), "store mutation persists")
        let reopened = RoundStore(defaults:defaults)
        expect(reopened.round?.players[0].scores[0] == 6, "V2 round restored from actualUserDefaults suite")
        expect(defaults.data(forKey:"puttpodium.round.v2") != nil, "versioned envelope written")
        defaults.removeObject(forKey:"puttpodium.round.v2")
        let ids = [UUID(),UUID()]
        let legacyObject: [String:Any] = ["players": [["id":ids[0].uuidString,"name":"Alex","scores":[0,2,2,2,2,2,2,2,2]],["id":ids[1].uuidString,"name":"Blair","scores":[3,3,3,3,3,3,3,3,3]]],"holes":9,"currentHole":8,"finished":true]
        let legacy = try JSONSerialization.data(withJSONObject:legacyObject)
        defaults.set(legacy,forKey:"puttparty.round.v1")
        let migrated = RoundStore(defaults:defaults)
        expect(migrated.round?.players[0].scores[0] == nil && migrated.round?.players[0].scores[1] == 2, "legacy zeros migrate to missing, positive scores retained")
        expect(migrated.round?.finished == false && migrated.notice != nil, "incomplete legacy finish reopened with notice")
        expect(defaults.data(forKey:"puttparty.round.v1") == legacy, "migration retains original legacy bytes")
        defaults.set(Data("bad json".utf8),forKey:"puttpodium.round.v2")
        let corrupt = RoundStore(defaults:defaults)
        expect(corrupt.round == nil && corrupt.notice != nil, "corrupt save produces recovery state rather than crash")
        expect(defaults.data(forKey:"puttpodium.round.recovery") == Data("bad json".utf8), "corrupt source copied to recovery")
        expect(corrupt.start(names:["NewA","NewB"],holes:18), "deliberate new round can proceed after recovery")
        expect(defaults.data(forKey:"puttpodium.round.recovery") == Data("bad json".utf8), "new round preserves recovery bytes")
        defaults.set(try JSONSerialization.data(withJSONObject:["schemaVersion":999,"round":legacyObject]),forKey:"puttpodium.round.v2")
        let future = RoundStore(defaults:defaults)
        expect(future.round == nil && future.notice != nil, "unknown schema safely rejected")
        defaults.removeObject(forKey:"puttpodium.round.recovery")
        defaults.set("unsupported scalar source",forKey:"puttpodium.round.v2")
        let scalar = RoundStore(defaults:defaults)
        expect(scalar.round == nil && scalar.notice != nil, "wrong-type save rejected with explanation")
        expect(defaults.string(forKey:"puttpodium.round.recovery") == "unsupported scalar source", "wrong-type source preserved asproperty-list recovery")
        expect(scalar.start(names:["A","B"],holes:9), "new round accepted after scalar recovery")
        expect(defaults.string(forKey:"puttpodium.round.recovery") == "unsupported scalar source", "new save does not erase scalar recovery")
        var eighteen = RoundData(players:(1...8).map { Golfer(name:"P\($0)",scores:Array(repeating:3,count:18)) },holes:18,currentHole:17)
        try eighteen.finish()
        expect(eighteen.completedHoles == 18 && GameOutcome(game:eighteen).leaders.count == 8, "eight-player eighteen-hole completion with all-player tie")
        expect(GameOutcome(game:eighteen).standings.allSatisfy { $0.label == "T1" }, "eight-way tie uses same shared rank")
        defaults.set(Data("later independent bad save".utf8),forKey:"puttpodium.round.v2")
        _ = RoundStore(defaults:defaults)
        let archived = (defaults.array(forKey:"puttpodium.round.recovery.history") as? [Data] ?? []).compactMap { try? PropertyListSerialization.propertyList(from:$0,options:[],format:nil) as? [String:Any] }
        expect(archived.contains { ($0["original"] as? Data) == Data("later independent bad save".utf8) } && archived.contains { ($0["original"] as? String) == "unsupported scalar source" }, "distinct consecutive malformed saves retained in recovery archive")
        let noCommon = LiveStandings(game:RoundData(players:[player("Alex",nil),player("Blair",nil)],holes:9))
        expect(noCommon.completedHoleCount == 0 && noCommon.standings.map(\.label) == ["—","—"] && noCommon.standings.map { $0.player.name } == ["Alex","Blair"], "zero common holes means no provisional ranks and stable crew order")
        var liveRound = RoundData(players:[player("Alex",nil),player("Blair",nil),player("Casey",nil)],holes:9)
        liveRound.players[0].scores[0] = 2
        liveRound.players[1].scores[0] = 3
        liveRound.players[1].scores[1] = 1
        liveRound.players[2].scores[0] = 2
        let live = LiveStandings(game:liveRound)
        expect(live.completedHoleCount == 1 && live.standings.map { $0.player.total } == [2,2,3], "provisional totals compare only shared fully scored holes")
        expect(live.standings.map(\.label) == ["T1","T1","3"] && live.standings.map { $0.player.name } == ["Alex","Casey","Blair"] && GameOutcome(game:liveRound).leaders.isEmpty, "provisional competition ranks ignore unmatched extra score and declare no final winner")
        print("Independent exact-source QA: \(checks) assertions passed.")
    }
}
