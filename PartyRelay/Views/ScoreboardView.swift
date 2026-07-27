import SwiftUI

/// 记分板：大分（赛点）为主，附上轮小分
struct ScoreboardView: View {
    @EnvironmentObject var store: GameStore
    @State private var showResetConfirm = false

    private var matchOver: Bool {
        store.roundNumber >= store.totalRounds
    }

    private var isTied: Bool {
        store.winnerIndex == nil
    }

    var body: some View {
        ZStack {
            PartyBackground()
            VStack(spacing: 18) {
                HomeExitBar()

                Text(L("board.title"))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                Text(store.isOvertime
                     ? L("board.overtime")
                     : L(store.smallScoreWin ? "board.progress_small" : "board.progress",
                         store.roundNumber, store.totalRounds))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // 总分：大分制显示大分，小分制显示累计小分（含主持人手动 +/−）
                HStack(spacing: 16) {
                    ForEach(store.teams) { team in
                        VStack(spacing: 6) {
                            ScoreBadge(team: team, score: store.matchScore(team.id))
                            HStack(spacing: 10) {
                                AdjustButton(icon: "minus.circle.fill", tint: team.colors[0]) {
                                    store.adjustTotal(team: team.id, delta: -1)
                                }
                                Text(L(store.smallScoreWin ? "board.small_total_label" : "board.big_label"))
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                AdjustButton(icon: "plus.circle.fill", tint: team.colors[0]) {
                                    store.adjustTotal(team: team.id, delta: +1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // 上轮小分（含主持人手动 +/−，改动自动重算该轮大分）
                if let o = store.lastOutcome {
                    HStack(spacing: 8) {
                        Text("\(o.game.emoji) \(L("board.last_round_label"))")
                            .font(.caption.bold())
                            .layoutPriority(1)
                        SmallScoreStepper(teamIndex: 0, value: o.small[0])
                        Text(":")
                            .font(.headline.bold())
                        SmallScoreStepper(teamIndex: 1, value: o.small[1])
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.8)))

                    Text(L(store.smallScoreWin ? "board.adjust_hint_small" : "board.adjust_hint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    if !o.words[0].isEmpty || !o.words[1].isEmpty {
                        RoundWordsRecap(outcome: o)
                    }
                }

                // 追分提示（两条都没有时不留空盒子）
                if let trailing = store.trailingIndex, !matchOver,
                   store.catchUpDiff >= 2 || store.pickEligibleTeam != nil {
                    VStack(spacing: 4) {
                        if store.catchUpDiff >= 2 {
                            Text(L(store.smallScoreWin ? "board.trailing_small" : "board.trailing",
                                   store.teams[trailing].name, store.scoreDiff))
                        }
                        if store.pickEligibleTeam != nil {
                            Text(L("board.pick_hint"))
                        }
                    }
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.orange.opacity(0.15)))
                } else if isTied {
                    Text(L("board.tied"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    FeedbackManager.shared.tap()
                    store.nextTurn()
                } label: {
                    if matchOver {
                        Label(isTied
                              ? L(store.smallScoreWin ? "board.overtime_btn_small" : "board.overtime_btn")
                              : L("board.reveal"),
                              systemImage: "flag.checkered.2.crossed")
                    } else {
                        Label(L(store.settings.soleGame == nil ? "board.next_round" : "board.next_round_direct",
                                store.roundNumber + 1),
                              systemImage: "arrow.right.circle.fill")
                    }
                }
                .buttonStyle(BigButtonStyle(colors: [.pink, .orange]))
                .padding(.horizontal, 28)

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label(L("board.reset"), systemImage: "arrow.counterclockwise")
                        .font(.subheadline.bold())
                }
                .padding(.bottom, 24)
            }
        }
        .confirmationDialog(L("board.reset_confirm_title"), isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button(L("board.reset_confirm_action"), role: .destructive) {
                FeedbackManager.shared.tap()
                store.resetToHome()
            }
            Button(L("common.cancel"), role: .cancel) {}
        }
    }
}

/// 主持人调分 +/− 小圆钮
private struct AdjustButton: View {
    var icon: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .background(Circle().fill(.white).padding(2))
        }
        .buttonStyle(.plain)
    }
}

/// 上轮小分步进器：− 数字 +（修改会触发该轮大分重算）
private struct SmallScoreStepper: View {
    @EnvironmentObject var store: GameStore
    var teamIndex: Int
    var value: Int

    var body: some View {
        let team = store.teams[teamIndex]
        HStack(spacing: 5) {
            AdjustButton(icon: "minus.circle.fill", tint: team.colors[0]) {
                store.adjustLastSmall(team: teamIndex, delta: -1)
            }
            Text("\(team.emoji)\(value)")
                .font(.headline.bold())
                .contentTransition(.numericText())
                .frame(minWidth: 40)
            AdjustButton(icon: "plus.circle.fill", tint: team.colors[0]) {
                store.adjustLastSmall(team: teamIndex, delta: +1)
            }
        }
    }
}

/// 上轮两队各自出现过的词
private struct RoundWordsRecap: View {
    @EnvironmentObject var store: GameStore
    var outcome: RoundOutcome

    var body: some View {
        VStack(spacing: 8) {
            Text(L(outcome.game.isSimultaneous ? "board.hof_names_label" : "board.words_label"))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                ForEach(0..<2, id: \.self) { i in
                    WordChipColumn(words: outcome.words[i], team: store.teams[i])
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.white.opacity(0.7)))
        .padding(.horizontal, 20)
    }
}

private struct WordChipColumn: View {
    var words: [PlayedWord]
    var team: Team

    var body: some View {
        VStack(spacing: 6) {
            Text("\(team.emoji) \(team.name)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if words.isEmpty {
                Text(L("board.no_words"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView {
                    FlowLayout(spacing: 5) {
                        ForEach(words) { w in
                            PlayedWordChip(word: w, tint: AnyShapeStyle(team.gradient))
                        }
                    }
                }
                .frame(maxHeight: 110)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
