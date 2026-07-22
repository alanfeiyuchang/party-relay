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
                        Toggle(isOn: binding(for: kind)) {
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
                    Stepper(value: $store.settings.roundSeconds, in: 30...180, step: 15) {
                        HStack {
                            Text(L("settings.turn_length"))
                            Spacer()
                            Text(L("settings.seconds_value", store.settings.roundSeconds))
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("settings.rules_title")).font(.subheadline.bold())
                        Text(L("settings.rules_body"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

    /// 玩法开关绑定：普通玩法至少保留 1 个（抢答是加成扇区，不算数）
    private func binding(for kind: GameKind) -> Binding<Bool> {
        Binding {
            store.settings.enabled.contains(kind)
        } set: { on in
            if on {
                store.settings.enabled.insert(kind)
            } else if kind == .quiz || store.settings.playableList.count > 1 {
                store.settings.enabled.remove(kind)
            } else {
                FeedbackManager.shared.locked()   // 拒绝关掉最后一个普通玩法
            }
        }
    }
}
