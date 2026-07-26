import SwiftUI

/// 本轮结算：比小分 → 定大分
struct RoundResultView: View {
    @EnvironmentObject var store: GameStore
    @State private var pop = false

    var body: some View {
        ZStack {
            PartyBackground()
            if let o = store.lastOutcome {
                VStack(spacing: 20) {
                    HomeExitBar()
                    Spacer()
                    Text(o.game.emoji)
                        .font(.system(size: 60))
                    Text("\(o.isOvertime ? L("result.overtime") : L("result.round_n", o.roundNumber)) · \(o.game.title)\(o.openBuzz ? " ⚡️" : "")")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)

                    // 小分对比
                    HStack(spacing: 14) {
                        ForEach(store.teams) { team in
                            VStack(spacing: 6) {
                                Text("\(team.emoji) \(team.name)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(o.small[team.id])")
                                    .font(.system(size: 54, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .scaleEffect(pop ? 1 : 0.2)
                                Text(L("result.small_label"))
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(team.gradient)
                                    .opacity(o.awards[team.id] > 0 ? 1 : 0.55)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(.white, lineWidth: o.awards[team.id] > 0 ? 4 : 0)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 26)

                    // 大分归属（小分制下没有大分，只宣布本轮领先方）
                    Group {
                        if o.awards[0] == 1 && o.awards[1] == 1 {
                            Text(L(store.smallScoreWin ? "result.tie_small" : "result.tie"))
                        } else {
                            let w = o.awards[0] == 1 ? 0 : 1
                            Text(L(store.smallScoreWin ? "result.winner_small" : "result.winner",
                                   "\(store.teams[w].emoji) \(store.teams[w].name)"))
                        }
                    }
                    .multilineTextAlignment(.center)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)))
                    .scaleEffect(pop ? 1 : 0.5)

                    Spacer()

                    Button {
                        FeedbackManager.shared.tap()
                        store.proceedToScoreboard()
                    } label: {
                        Label(L("result.to_scoreboard"), systemImage: "chart.bar.fill")
                    }
                    .buttonStyle(BigButtonStyle(colors: [.indigo, .blue]))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            FeedbackManager.shared.roundSettle()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.15)) {
                pop = true
            }
        }
    }
}
