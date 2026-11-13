import SwiftUI
import UIKit

private enum PodiumTheme {
    static let ink = Color(red: 0.055, green: 0.085, blue: 0.13)
    static let panel = Color(red: 0.10, green: 0.15, blue: 0.20)
    static let lime = Color(red: 0.72, green: 0.98, blue: 0.37)
    static let muted = Color(red: 0.65, green: 0.73, blue: 0.75)
}

struct ContentView: View {
    @StateObject private var store = RoundStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var names = ["Player 1", "Player 2"]
    @State private var holes = 9
    @State private var showReset = false
    @State private var showReview = false
    @State private var showStandings = false
    @State private var editingFinished = false
    @State private var scoreEdit: ScoreEdit?
    @State private var flexStyle: FlexStyle = .champion
    @State private var share: SharePayload?
    @AppStorage("puttpodium.haptics") private var haptics = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let game = store.round {
                        if game.finished && !editingFinished { results(game) }
                        else { scoring(game) }
                    } else { setup }
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .id(store.round.map { $0.finished && !editingFinished ? "results" : "hole-\($0.currentHole)" } ?? "setup")
            .background(PodiumTheme.ink)
            .navigationTitle("Putt Podium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        if store.round != nil {
                            Button { showReset = true } label: {
                                Image(systemName: "arrow.counterclockwise").frame(minWidth: 44, minHeight: 44)
                            }.accessibilityLabel("New round").accessibilityIdentifier("newRound")
                        }
                        Menu {
                            Toggle("Haptic feedback", isOn: $haptics)
                            if store.round != nil {
                                Button("Review scorecard", systemImage: "tablecells") { showReview = true }
                                    .accessibilityIdentifier("reviewScores")
                                if store.round?.finished == true && !editingFinished {
                                    Button("Edit scores", systemImage: "pencil") { beginCorrection() }
                                        .accessibilityIdentifier("editScores")
                                }
                            }
                        } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel("Round options").accessibilityIdentifier("roundOptions")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let game = store.round {
                    if game.finished && !editingFinished { resultActions(game) }
                    else { holeNavigation(game) }
                } else {
                    actionButton("Let's putt", symbol: "arrow.right", id: "startRound") {
                        if store.start(names: names, holes: holes) { editingFinished = false }
                    }.padding(.horizontal, 20).padding(.vertical, 10).background(PodiumTheme.ink)
                }
            }
        }
        .tint(PodiumTheme.lime)
        .preferredColorScheme(.dark)
        .sheet(item: $scoreEdit) { edit in
            ScoreEntrySheet(edit: edit) { value in
                _ = store.setScore(playerID: edit.playerID, hole: edit.hole, value: value)
            }
        }
        .sheet(isPresented: $showReview) { reviewSheet }
        .sheet(isPresented: $showStandings) {
            NavigationStack {
                ScrollView { if let game = store.round { standings(game).padding(20) } }
                    .navigationTitle("Standings").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showStandings = false } } }
                    .background(PodiumTheme.ink)
            }.preferredColorScheme(.dark)
        }
        .sheet(item: $share) { payload in ActivitySheet(items: [payload.image, payload.caption]) }
        .alert("Start a new round?", isPresented: $showReset) {
            Button("Cancel", role: .cancel) {}
            Button("Replace round", role: .destructive) {
                if store.reset() { editingFinished = false }
            }
        } message: { Text("This replaces the current saved scorecard. Share it first if you want to keep a copy.") }
        .alert("Scorecard update", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
            Button("OK") { store.notice = nil }
        } message: { Text(store.notice ?? "") }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 24) {
            OpeningCourseArtwork()
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("The crew", detail: "2–8 players")
                ForEach(names.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        Text(String(index + 1)).font(.caption.monospacedDigit().bold()).foregroundStyle(PodiumTheme.muted)
                        TextField("Player \(index + 1)", text: $names[index])
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Player \(index + 1) name")
                            .accessibilityIdentifier("playerName-\(index)")
                            .onChange(of: names[index]) { _, value in
                                if value.count > 40 { names[index] = String(value.prefix(40)) }
                            }
                        if names.count > 2 {
                            Button { names.remove(at: index) } label: {
                                Image(systemName: "minus.circle").frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Remove \(names[index])")
                        }
                    }
                    .padding(.horizontal, 16).frame(minHeight: 56)
                    .background(PodiumTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                }
                if names.count < 8 {
                    Button { names.append("Player \(names.count + 1)") } label: {
                        Label("Add player", systemImage: "plus.circle").frame(minHeight: 44)
                    }.accessibilityIdentifier("addPlayer")
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("The round", detail: "Low score wins")
                Picker("Number of holes", selection: $holes) {
                    Text("9 holes").tag(9).accessibilityIdentifier("holeChoice-9")
                    Text("18 holes").tag(18).accessibilityIdentifier("holeChoice-18")
                }.pickerStyle(.segmented)
            }
        }
    }

    private func scoring(_ game: RoundData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hole \(game.currentHole + 1)").font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
                Menu {
                    ForEach(0..<game.holes, id: \.self) { hole in
                        Button("Hole \(hole + 1)") { _ = store.move(to: hole) }
                    }
                } label: {
                    Label("of \(game.holes)", systemImage: "chevron.down").frame(minHeight: 44)
                }.accessibilityLabel("Choose hole, current hole \(game.currentHole + 1) of \(game.holes)")
                .accessibilityIdentifier("chooseHole")
            }
            VStack(spacing: 0) {
                ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                    scoreRow(player, index: index, hole: game.currentHole)
                    if index != game.players.count - 1 { Divider() }
                }
            }.padding(.horizontal, 12).background(PodiumTheme.panel, in: RoundedRectangle(cornerRadius: 18))
            if game.players.contains(where: { $0.scores[game.currentHole] == nil }) {
                Text("— means not recorded. Tap a score to enter it directly.")
                    .font(.footnote).foregroundStyle(PodiumTheme.muted)
            }
        }
    }

    private func scoreRow(_ player: Golfer, index: Int, hole: Int) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(player.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                    scoreControls(player, index: index, hole: hole)
                }
            } else {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.name).font(.headline).lineLimit(2)
                        Text("Total \(player.total)").font(.caption).foregroundStyle(PodiumTheme.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    scoreControls(player, index: index, hole: hole)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }.padding(.vertical, 10)
    }

    private func scoreControls(_ player: Golfer, index: Int, hole: Int) -> some View {
        HStack(spacing: 4) {
            Button { update(player, hole: hole, delta: -1) } label: {
                Image(systemName: "minus").frame(minWidth: 48, minHeight: 48).contentShape(Rectangle())
            }
            .disabled(player.scores[hole] == nil)
            .accessibilityLabel(player.scores[hole] == 1 ? "Clear \(player.name)'s score on hole \(hole + 1)" : "Decrease \(player.name)'s score on hole \(hole + 1)")
            .accessibilityIdentifier("decrease-\(index)")
            Button {
                scoreEdit = ScoreEdit(playerID: player.id, name: player.name, hole: hole, value: player.scores[hole])
            } label: {
                Text(player.scores[hole].map(String.init) ?? "—")
                    .font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
                    .frame(minWidth: 48, minHeight: 48).contentShape(Rectangle())
                    .foregroundStyle(player.scores[hole] == nil ? PodiumTheme.muted : .white)
            }
            .accessibilityLabel("\(player.name), hole \(hole + 1), \(player.scores[hole].map { "\($0) strokes" } ?? "not recorded"). Edit score")
            .accessibilityIdentifier("score-\(index)")
            Button { update(player, hole: hole, delta: 1) } label: {
                Image(systemName: "plus").frame(minWidth: 48, minHeight: 48).contentShape(Rectangle())
                    .foregroundStyle(PodiumTheme.ink).background(PodiumTheme.lime, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Increase \(player.name)'s score on hole \(hole + 1)")
            .accessibilityIdentifier("increase-\(index)")
        }.buttonStyle(.plain)
    }

    private func holeNavigation(_ game: RoundData) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 6) { navigationButtons(game); standingsButton }
            } else {
                HStack(spacing: 8) { standingsButton; navigationButtons(game) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .background(PodiumTheme.ink)
    }

    private func navigationButtons(_ game: RoundData) -> some View {
        HStack(spacing: 8) {
            Button { _ = store.move(to: max(0, game.currentHole - 1)) } label: {
                Image(systemName: "chevron.left").frame(minWidth: 48, minHeight: 48).contentShape(Rectangle())
            }.disabled(game.currentHole == 0).accessibilityLabel("Previous hole").accessibilityIdentifier("previousHole")
            if game.currentHole < game.holes - 1 && !editingFinished {
                actionButton("Next", symbol: "chevron.right", id: "nextHole") { _ = store.move(to: game.currentHole + 1) }
            } else {
                actionButton(editingFinished ? "Done" : "Finish", symbol: "checkmark", id: "finishRound") {
                    if game.isComplete { if store.finish() { editingFinished = false } }
                    else { showReview = true }
                }
            }
        }
    }

    private var standingsButton: some View {
        Button { showStandings = true } label: {
            Label("Standings", systemImage: "list.number").font(.subheadline).frame(minHeight: 48)
        }.accessibilityIdentifier("showStandings")
    }

    private func beginCorrection() {
        editingFinished = true
        _ = store.move(to: 0)
    }

    private func resultActions(_ game: RoundData) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 6) { shareButton(game); standingsButton }
            } else {
                HStack(spacing: 14) { standingsButton; shareButton(game) }
            }
        }.padding(.horizontal, 16).padding(.vertical, 8).background(PodiumTheme.ink)
    }

    private func shareButton(_ game: RoundData) -> some View {
        actionButton("Share", symbol: "square.and.arrow.up", id: "shareCard") { renderShare(game) }
    }

    private func standings(_ game: RoundData) -> some View {
        let outcome = GameOutcome(game: game)
        let live = LiveStandings(game: game)
        return VStack(alignment: .leading, spacing: 14) {
            sectionHeading(game.isComplete ? "The standings" : "Live standings", detail: game.isComplete ? "Low score wins" : (live.completedHoleCount == 0 ? "Record a full hole to compare" : "Through \(live.completedHoleCount) shared holes · provisional"))
            ForEach(game.isComplete ? outcome.standings : live.standings) { standing in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(standing.label).font(.headline.monospacedDigit()).foregroundStyle(PodiumTheme.lime).frame(minWidth: 36, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(standing.player.name).font(.body.weight(.semibold))
                        if !game.isComplete { Text("\(live.completedHoleCount) shared holes").font(.caption).foregroundStyle(PodiumTheme.muted) }
                    }
                    Spacer(minLength: 8)
                    Text("\(standing.player.total)").font(.title3.bold()).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                Divider()
            }
        }
    }

    private var reviewSheet: some View {
        NavigationStack {
            Group {
                if let game = store.round {
                    List {
                        Section {
                            Label(game.isComplete ? "Every score is in." : "\(game.missingCount) scores still to record", systemImage: game.isComplete ? "checkmark.circle.fill" : "pencil.circle")
                            Text(game.isComplete ? "Check the holes below, then open the podium. You can still correct scores afterward." : "Blank scores never count as zero. Tap a hole to record or correct scores.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Section(game.isComplete ? "Hole-by-hole review" : "Holes needing scores") {
                            ForEach((0..<game.holes).filter { hole in game.isComplete || game.players.contains { $0.scores[hole] == nil } }, id: \.self) { hole in
                                Button {
                                    _ = store.move(to: hole)
                                    editingFinished = game.finished
                                    showReview = false
                                } label: {
                                    HStack {
                                        Text("Hole \(hole + 1)")
                                        Spacer()
                                        let count = game.players.filter { $0.scores[hole] != nil }.count
                                        Text("\(count)/\(game.players.count)").foregroundStyle(count == game.players.count ? .secondary : PodiumTheme.lime)
                                        Image(systemName: "chevron.right").font(.caption)
                                    }.frame(minHeight: 36)
                                }.accessibilityIdentifier("reviewHole-\(hole)")
                            }
                        }
                        Section {
                            Button("Open the podium") {
                                if store.finish() { editingFinished = false; showReview = false }
                            }
                            .fontWeight(.bold).disabled(!game.isComplete)
                            .accessibilityIdentifier("confirmFinish")
                        }
                    }
                }
            }
            .navigationTitle("Check the scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showReview = false } } }
        }.preferredColorScheme(.dark)
    }

    private func results(_ game: RoundData) -> some View {
        let outcome = GameOutcome(game: game)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label(outcome.isTie ? "A shared crown." : "\(outcome.winnerNames) wins!", systemImage: "crown.fill")
                    .font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(PodiumTheme.lime)
                    .fixedSize(horizontal: false, vertical: true)
                Text(outcome.isTie ? "\(outcome.ranked.first?.total ?? 0) strokes · \(game.holes) holes" : "\(outcome.ranked.first?.total ?? 0) strokes. A \(outcome.margin)-stroke victory.")
                    .font(.subheadline).foregroundStyle(PodiumTheme.muted)
            }
            if typeSize.isAccessibilitySize {
                Menu {
                    ForEach(FlexStyle.allCases) { style in
                        Button { flexStyle = style } label: {
                            Label(style.title, systemImage: flexStyle == style ? "checkmark" : style.symbol)
                        }.accessibilityIdentifier("flexStyle-\(style.rawValue)")
                    }
                } label: { Label(flexStyle.title, systemImage: "chevron.down").frame(minHeight: 48) }
                .accessibilityLabel("Card style, \(flexStyle.title)")
            } else {
                HStack(spacing: 6) {
                    ForEach(FlexStyle.allCases) { style in
                        Button { flexStyle = style } label: {
                            Text(style == .champion ? "Champion" : style == .roast ? "Trash talk" : "Receipts")
                                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(flexStyle == style ? PodiumTheme.ink : .white)
                                .background(flexStyle == style ? PodiumTheme.lime : PodiumTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                        }.accessibilityLabel(style.title)
                        .accessibilityAddTraits(flexStyle == style ? .isSelected : [])
                        .accessibilityIdentifier("flexStyle-\(style.rawValue)")
                    }
                }
            }
            FlexCard(game: game, style: flexStyle)
                .aspectRatio(0.8, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
            DisclosureGroup("Caption") {
                Text(outcome.caption(for: flexStyle)).font(.body).textSelection(.enabled)
            }
            Button { beginCorrection() } label: { Label("Edit scores", systemImage: "pencil").frame(minHeight: 44) }
                .accessibilityIdentifier("editScores")
        }
    }

    private func update(_ player: Golfer, hole: Int, delta: Int) {
        let current = player.scores[hole] ?? 0
        let next = current + delta
        let accepted = withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
            store.setScore(playerID: player.id, hole: hole, value: next > 0 ? next : nil)
        }
        if haptics && accepted { UISelectionFeedbackGenerator().selectionChanged() }
    }

    @MainActor private func renderShare(_ game: RoundData) {
        guard game.isComplete && game.finished else { store.notice = "Record every score and review the round before sharing."; return }
        let renderer = ImageRenderer(content: FlexCard(game: game, style: flexStyle)
            .frame(width: 900, height: 1125).environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, .large))
        renderer.scale = 2
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { store.notice = "The card couldn't be created. Please try sharing again."; return }
        share = SharePayload(image: image, caption: GameOutcome(game: game).caption(for: flexStyle))
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(detail).font(.caption).foregroundStyle(PodiumTheme.muted)
        }
    }

    private func actionButton(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline)
                .frame(maxWidth: .infinity, minHeight: 28).padding(14)
                .foregroundStyle(PodiumTheme.ink).background(PodiumTheme.lime, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

/// Compact adaptation of Version A's original SwiftUI hero, not a new asset.
private struct OpeningCourseArtwork: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalSize
    private var compact: Bool { typeSize.isAccessibilitySize || verticalSize == .compact }
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20).fill(PodiumTheme.lime)
            GeometryReader { geometry in
                Circle().stroke(PodiumTheme.ink.opacity(0.12), lineWidth: 24)
                    .frame(width: 160, height: 160)
                    .position(x: geometry.size.width - 10, y: 10)
            }
            HStack(spacing: 16) {
                Image(systemName: "figure.golf")
                    .font(.system(size: compact ? 32 : 40))
                    .frame(width: 42)
                Text("THE COURSE\nIS CALLING")
                    .font(.system(size: compact ? 17 : 21, weight: .black, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(PodiumTheme.ink)
            .padding(.horizontal, 20)
        }
        // Decorative artwork scales independently from accessible form text.
        .frame(height: compact ? 64 : 84)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct ScoreEdit: Identifiable {
    let id = UUID()
    let playerID: UUID
    let name: String
    let hole: Int
    let value: Int?
}

private struct ScoreEntrySheet: View {
    let edit: ScoreEdit
    let save: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    init(edit: ScoreEdit, save: @escaping (Int?) -> Void) {
        self.edit = edit; self.save = save; _text = State(initialValue: edit.value.map(String.init) ?? "")
    }
    private var valid: Bool { text.isEmpty || Int(text).map { (1...999).contains($0) } == true }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(edit.name).font(.headline)
                    TextField("Strokes", text: $text).keyboardType(.numberPad)
                        .accessibilityIdentifier("scoreInput")
                    Text("Leave blank for not recorded. Enter 1–999 strokes; this is an entry limit, not a course rule.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !valid { Text("Enter a whole number from 1 to 999, or clear the score.").foregroundStyle(.red) }
                }
                Section("Quick entry") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(1...6, id: \.self) { number in
                            Button("\(number)") { save(number); dismiss() }.frame(minHeight: 48)
                                .accessibilityLabel("\(number) strokes")
                        }
                    }
                    Text("For 7 or more, type the score above.").font(.footnote).foregroundStyle(.secondary)
                }
                Section { Button("Clear score", role: .destructive) { save(nil); dismiss() }.accessibilityIdentifier("clearScore") }
            }
            .navigationTitle("Hole \(edit.hole + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(text.isEmpty ? nil : Int(text)); dismiss() }.disabled(!valid).accessibilityIdentifier("saveScore")
                }
            }
        }.preferredColorScheme(.dark).tint(PodiumTheme.lime)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let caption: String
}

#Preview("Scoring app") { ContentView() }
#Preview("Accessibility text") { ContentView().environment(\.dynamicTypeSize, .accessibility3) }
