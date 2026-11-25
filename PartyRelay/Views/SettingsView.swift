import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var coverCamera = CoverScreenCamera.shared
    /// 点过「再讲一遍」之后给个确认态，否则按下去毫无反馈。
    /// 初值从真实状态读：只存在 @State 里的话，关掉再进设置就退回「没点过」的样子，
    /// 而 UserDefaults 里其实已经武装好了——那是在骗人
    @State private var foldIntroRearmed = !FoldTutorial.hasSeenIntro

    /// 相机权限被拒：外屏从此不会亮，而玩的时候没有任何地方说得清为什么
    private var cameraDenied: Bool { coverCamera.denied }

    var body: some View {
        NavigationStack {
            List {
                // 玩法开关
                Section {
                    ForEach(store.settings.relevantGames) { kind in
                        Toggle(isOn: store.gameEnabledBinding(for: kind)) {
                            HStack(spacing: 12) {
                                Text(kind.emoji)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(kind.gradient)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title).font(.headline)
                                    Text(kind.rule)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .tint(kind.colors[0])
                    }
                } header: {
                    Text(L("settings.games_header"))
                } footer: {
                    Text(L(store.playMode.hasTeams ? "settings.games_footer"
                           : store.isRotation ? "settings.games_footer_rotation" : "settings.games_footer_solo"))
                }

                // 赛制
                Section(L("settings.match_header")) {
                    // 只有对战模式打多轮；快速一局、轮流每人一次，总轮数用不上
                    if store.playMode.hasTeams {
                        Stepper(value: $store.settings.totalRounds, in: 3...10) {
                            HStack {
                                Text(L("settings.total_rounds"))
                                Spacer()
                                Text(L("settings.rounds_value", store.settings.totalRounds))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Stepper(value: $store.settings.roundSeconds,
                            in: GameSettings.roundSecondsRange,
                            step: GameSettings.roundSecondsStep) {
                        HStack {
                            Text(L(store.playMode.hasTeams ? "settings.turn_length"
                                   : store.isRotation ? "settings.turn_length_rotation" : "settings.turn_length_solo"))
                            Spacer()
                            Text(L("settings.seconds_value", store.settings.roundSeconds))
                                .foregroundStyle(.secondary)
                        }
                    }
                    // 表情管理的加时：只作用于这一个玩法，加在上面的单局时长上。
                    // 玩法下架时这一项也跟着藏起来
                    if !GameKind.emojiCode.isHidden {
                        Stepper(value: $store.settings.emojiBonusSeconds,
                                in: GameSettings.emojiBonusRange,
                                step: GameSettings.emojiBonusStep) {
                            HStack {
                                Text(L("settings.emoji_bonus"))
                                Spacer()
                                Text(L("settings.bonus_seconds_value", store.settings.emojiBonusSeconds))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(L("settings.emoji_bonus_footer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Stepper(value: $store.settings.maxSkips, in: GameSettings.skipsRange) {
                        HStack {
                            Text(L("settings.max_skips"))
                            Spacer()
                            Text(L("settings.skips_value", store.settings.maxSkips))
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("settings.rules_title")).font(.subheadline.bold())
                        Text(L(rulesKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 计分制：小分制（无大分，累计小分定胜负）。只有对战模式有队伍比分
                if store.playMode.hasTeams {
                    Section {
                        Toggle(isOn: $store.settings.smallScoreWin) {
                            Label(L("settings.small_score_win"), systemImage: "sum")
                        }
                        .tint(.teal)
                    } footer: {
                        Text(L("settings.small_score_footer"))
                    }
                }

                // 防偷窥模式（默认关闭）
                Section {
                    Toggle(isOn: $store.settings.privacyGuardOn) {
                        Label(L("settings.privacy"), systemImage: "eye.slash.fill")
                    }
                    .tint(.indigo)
                } footer: {
                    Text(L("settings.privacy_footer"))
                }

                // 折叠玩法：只有真有铰链的机器才显示，普通 iPhone 上一个字都不提
                if FoldTutorial.deviceCanFold {
                    Section {
                        Button {
                            FeedbackManager.shared.tap()
                            // 重新武装：下次折到 90° 再讲一遍。派对游戏每局换人拿手机，
                            // 「只弹一次、之后永远找不回」对第二个人起就等于没有说明
                            FoldTutorial.rearmIntro()
                            foldIntroRearmed = true
                        } label: {
                            Label(L(foldIntroRearmed ? "settings.fold_intro_done"
                                                     : "settings.fold_intro"),
                                  systemImage: foldIntroRearmed ? "checkmark.circle.fill"
                                                                : "laptopcomputer")
                        }
                        .disabled(foldIntroRearmed)
                    } header: {
                        Text(L("settings.fold_header"))
                    } footer: {
                        // 权限被拒之后外屏就是永远不亮，而 App 在玩的时候一个字都不会提。
                        // 这里是唯一能说清「为什么对面那块屏没反应」的地方
                        Text(L(cameraDenied ? "settings.fold_camera_denied"
                                            : "settings.fold_footer"))
                    }
                }

                // 反馈
                Section {
                    Toggle(isOn: $store.settings.feedbackOn) {
                        Label(L("settings.feedback"), systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(.pink)
                } footer: {
                    Text(L("settings.feedback_footer"))
                }
            }
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("settings.done")) { dismiss() }
                        .bold()
                }
            }
        }
        .onChange(of: store.settings.feedbackOn) {
            FeedbackManager.shared.isEnabled = store.settings.feedbackOn
        }
    }

    private var rulesKey: String {
        switch store.playMode {
        case .match:    return store.settings.smallScoreWin ? "settings.rules_body_small" : "settings.rules_body"
        case .quick:    return "settings.rules_body_solo"
        case .rotation: return "settings.rules_body_rotation"
        }
    }
}
