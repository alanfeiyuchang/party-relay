import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // 快速模式：不分队、只打一局。放在最上面，它决定下面显示哪些玩法
                Section {
                    Toggle(isOn: Binding(get: { store.settings.soloMode },
                                         set: { store.setSoloMode($0) })) {
                        Label(L("settings.solo_mode"), systemImage: "bolt.fill")
                    }
                    .tint(.teal)
                } footer: {
                    Text(L("settings.solo_footer"))
                }

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
                    Text(L(store.settings.soloMode ? "settings.games_footer_solo" : "settings.games_footer"))
                }

                // 赛制
                Section(L("settings.match_header")) {
                    // 快速模式只打一局，总轮数用不上
                    if !store.settings.soloMode {
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
                            Text(L(store.settings.soloMode ? "settings.turn_length_solo" : "settings.turn_length"))
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
                        Text(L(store.settings.soloMode ? "settings.rules_body_solo"
                               : store.settings.smallScoreWin ? "settings.rules_body_small" : "settings.rules_body"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 计分制：小分制（无大分，累计小分定胜负）。快速模式不记分，藏起来
                if !store.settings.soloMode {
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
}
