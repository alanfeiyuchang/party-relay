import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // 玩法开关
                Section {
                    ForEach(GameKind.allCases) { kind in
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
                    Text(L("settings.games_footer"))
                }

                // 赛制
                Section(L("settings.match_header")) {
                    Stepper(value: $store.settings.totalRounds, in: 3...10) {
                        HStack {
                            Text(L("settings.total_rounds"))
                            Spacer()
                            Text(L("settings.rounds_value", store.settings.totalRounds))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $store.settings.roundSeconds,
                            in: GameSettings.roundSecondsRange,
                            step: GameSettings.roundSecondsStep) {
                        HStack {
                            Text(L("settings.turn_length"))
                            Spacer()
                            Text(L("settings.seconds_value", store.settings.roundSeconds))
                                .foregroundStyle(.secondary)
                        }
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
                        Text(L(store.settings.smallScoreWin ? "settings.rules_body_small" : "settings.rules_body"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 计分制：小分制（无大分，累计小分定胜负）
                Section {
                    Toggle(isOn: $store.settings.smallScoreWin) {
                        Label(L("settings.small_score_win"), systemImage: "sum")
                    }
                    .tint(.teal)
                } footer: {
                    Text(L("settings.small_score_footer"))
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
