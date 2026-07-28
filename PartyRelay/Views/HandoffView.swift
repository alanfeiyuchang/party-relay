import SwiftUI
import Combine

/// 交接遮挡屏：防止对方偷看词；后手上场时显示先手的小分
/// 换手（上一队打完交给下一队）时，「开始」按钮要等 5 秒倒计时结束才可按
struct HandoffView: View {
    @EnvironmentObject var store: GameStore

    @State private var waitLeft = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// 只在「换到下一队」这一刻加倒计时（本轮第二遍上场）
    private var needsWait: Bool { store.playIndex == 1 }
    private var locked: Bool { waitLeft > 0 }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(store.playingTeam.gradient)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HomeExitBar(light: true)

                Spacer()

                Text(store.currentGame.emoji)
                    .font(.system(size: 64))
                Text("\(store.currentGame.title)\(store.openBuzz ? " ⚡️" : "")")
                    .font(.title2.bold())
                    .foregroundStyle(.white.opacity(0.9))

                Text(L("handoff.pass_to"))
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(store.playingTeam.emoji) \(store.playingTeam.name)")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 20)

                if store.playIndex == 1 {
                    Text(L(store.smallScoreWin ? "handoff.beat_them_small" : "handoff.beat_them",
                           store.roundSmall[1 - store.playingTeamIndex]))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.black.opacity(0.2)))
                } else {
                    Text(L("handoff.you_first"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // 上一队刚打完的词回顾（灰底=跳过），居中放在开始按钮上方
                if !store.previousTurnWords.isEmpty {
                    TurnWordsRecap(words: store.previousTurnWords,
                                   teamName: store.teams[1 - store.playingTeamIndex].name)
                }

                if store.openBuzz {
                    Text(L("handoff.openbuzz"))
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.yellow))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                if store.currentGame == .drawGuess || store.currentGame == .emojiCode {
                    Text(store.currentGame == .drawGuess
                         ? L("handoff.draw_flow")
                         : L("handoff.emoji_flow", store.settings.emojiWordSeconds))
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else if store.settings.privacyGuardOn {
                    Text(L("handoff.posture"))
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                CatchUpBanner(catchUp: store.catchUp, teamName: store.playingTeam.name)

                Spacer()

                Button {
                    FeedbackManager.shared.tap()
                    store.startPlaying()
                } label: {
                    Text(locked ? L("handoff.start_in", waitLeft) : L("handoff.start"))
                        .contentTransition(.numericText(countsDown: true))
                }
                .buttonStyle(BigButtonStyle(colors: locked
                                            ? [Color(.systemGray3), Color(.systemGray4)]
                                            : [.white, .white.opacity(0.92)],
                                            textColor: locked ? .white : store.currentGame.colors[0]))
                .disabled(locked)
                .padding(.horizontal, 32)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            waitLeft = needsWait ? GameSettings.handoffCountdown : 0
        }
        .onReceive(timer) { _ in
            guard waitLeft > 0 else { return }
            FeedbackManager.shared.countdownTick()
            withAnimation { waitLeft -= 1 }
        }
    }
}

// MARK: - 上一队刚打完那一遍出现过的词

/// 交接页中央的词语回顾：猜对的正常显示，跳过的灰底
private struct TurnWordsRecap: View {
    var words: [PlayedWord]
    var teamName: String

    var body: some View {
        VStack(spacing: 8) {
            Text(L("handoff.recap_title", teamName))
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // 词不多时按内容高度展开，词多了才滚动，免得中间留一大块空白
            if words.count > 9 {
                ScrollView { chipWall }.frame(maxHeight: 150)
            } else {
                chipWall
            }

            Text(L("handoff.recap_legend"))
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.black.opacity(0.18)))
        .padding(.horizontal, 22)
    }

    private var chipWall: some View {
        FlowLayout(spacing: 6) {
            ForEach(words) { w in
                PlayedWordChip(word: w,
                               tint: AnyShapeStyle(Color.white),
                               textColor: .black.opacity(0.8),
                               font: .footnote.bold())
            }
        }
    }
}
