import SwiftUI
import UIKit

struct FlexCard: View {
    let game: RoundData
    let style: FlexStyle
    private var outcome: GameOutcome { GameOutcome(game: game) }
    private let ink = Color(red: 0.055, green: 0.085, blue: 0.13)
    private let lime = Color(red: 0.72, green: 0.98, blue: 0.37)
    private let gold = Color(red: 1, green: 0.78, blue: 0.33)
    private let coral = Color(red: 1, green: 0.43, blue: 0.43)

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / 900
            ZStack {
                ink
                Circle()
                    .stroke(accent.opacity(0.14), lineWidth: 90 * unit)
                    .frame(width: 670 * unit, height: 670 * unit)
                    .offset(x: 330 * unit, y: -330 * unit)
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 550 * unit, height: 550 * unit)
                    .blur(radius: 100 * unit)
                    .offset(x: -300 * unit, y: 360 * unit)

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("PUTT PODIUM", systemImage: "flag.fill")
                            .font(.system(size: 31 * unit, weight: .black, design: .rounded))
                            .tracking(3 * unit)
                        Spacer()
                        Text("\(game.holes) HOLES")
                            .font(.system(size: 24 * unit, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 24 * unit)
                            .padding(.vertical, 13 * unit)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    .foregroundStyle(accent)

                    Spacer(minLength: 16 * unit)
                    Image(systemName: style.symbol)
                        .font(.system(size: 100 * unit, weight: .black))
                        .foregroundStyle(accent)
                        .shadow(color: accent.opacity(0.4), radius: 30 * unit)
                        .padding(.bottom, 25 * unit)

                    Text(kicker)
                        .font(.system(size: 28 * unit, weight: .black, design: .rounded))
                        .tracking(6 * unit)
                        .foregroundStyle(accent)
                        .padding(.bottom, 18 * unit)

                    Text(title)
                        .font(.system(size: 78 * unit, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.58)
                        .lineLimit(3)
                        .tracking(-3 * unit)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 28 * unit, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, 20 * unit)

                    Spacer(minLength: 20 * unit)

                    VStack(spacing: 0) {
                        ForEach(Array(outcome.standings.prefix(style == .receipts ? 8 : 4).enumerated()), id: \.element.id) { index, standing in
                            let player = standing.player
                            HStack(spacing: 14 * unit) {
                                Text(standing.rank == 1 && !outcome.isTie ? "👑" : standing.label)
                                    .frame(width: 70 * unit, alignment: .leading)
                                Text(player.name)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(player.total)")
                                    .monospacedDigit()
                                    .foregroundStyle(standing.rank == 1 ? accent : .white)
                            }
                            .font(.system(size: 30 * unit, weight: .bold, design: .rounded))
                            .padding(.vertical, (style == .receipts ? 13 : 17) * unit)
                            if index < min(outcome.ranked.count, style == .receipts ? 8 : 4) - 1 {
                                Rectangle().fill(.white.opacity(0.13)).frame(height: unit)
                            }
                        }
                    }
                    .padding(.horizontal, 28 * unit)
                    .padding(.vertical, 12 * unit)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 28 * unit))

                    HStack {
                        Text("LOW SCORE. LOUD BRAG.")
                        Spacer()
                        Text("REMATCH?")
                    }
                    .font(.system(size: 19 * unit, weight: .black, design: .rounded))
                    .tracking(2 * unit)
                    .foregroundStyle(accent)
                    .padding(.top, 40 * unit)
                }
                .padding(64 * unit)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityElement(children: .combine)
    }

    private var accent: Color {
        switch style {
        case .champion: gold
        case .roast: coral
        case .receipts: lime
        }
    }
    private var kicker: String {
        switch style {
        case .champion: "THE CHAMPION"
        case .roast: "THE VERDICT"
        case .receipts: "OFFICIAL RESULTS"
        }
    }
    private var title: String {
        switch style {
        case .champion: outcome.isTie ? "CROWN\nSHARED." : "BOW TO\n\(outcome.winnerNames.uppercased())."
        case .roast: outcome.headline
        case .receipts: "THE\nRECEIPTS."
        }
    }
    private var subtitle: String {
        switch style {
        case .champion: outcome.isTie ? "A tie means unfinished business." : "Winner by \(outcome.margin) stroke\(outcome.margin == 1 ? "" : "s")."
        case .roast: outcome.isTie ? "Nobody escapes the rematch." : "\(outcome.winnerNames) has entered the group chat."
        case .receipts: "The scoreboard doesn't lie."
        }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
