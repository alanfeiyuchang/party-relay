import SwiftUI

/// 主界面：红蓝两队（队名可编辑）+ 开始游戏 / 设置 + 右上角语言切换
struct HomeView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject var langManager = LanguageManager.shared
    @Binding var showSettings: Bool
    @State private var infoGame: GameKind?

    var body: some View {
        ZStack {
            PartyBackground()
            VStack(spacing: 18) {
                // 顶栏：语言切换按钮（右上角）
                HStack {
                    Spacer()
                    Button {
                        FeedbackManager.shared.tap()
                        langManager.toggle()
                        store.syncTeamNamesToLanguage()
                    } label: {
                        Label(langManager.language.toggleLabel, systemImage: "globe")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(LinearGradient(colors: [.indigo, .purple],
                                                              startPoint: .leading, endPoint: .trailing))
                                    .shadow(color: .purple.opacity(0.35), radius: 5, y: 2)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                Text("🎉")
                    .font(.system(size: 50))
                Text(L("app.title"))
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .orange, .purple],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                Text(L(store.settings.smallScoreWin ? "home.subtitle_small" : "home.subtitle"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // 两支队伍（可编辑队名）
                VStack(spacing: 14) {
                    ForEach($store.teams) { $team in
                        TeamCard(team: $team)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                HStack(spacing: 18) {
                    Label(L("home.rounds", store.settings.totalRounds),
                          systemImage: "arrow.triangle.2.circlepath")
                    Label(L("home.seconds_per_turn", store.settings.roundSeconds),
                          systemImage: "timer")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

                // 玩法一览（点标签看规则并加入/移出转盘；已排除的置灰）
                VStack(spacing: 6) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                        ForEach(GameKind.allCases) { kind in
                            GameTagChip(kind: kind,
                                        included: store.settings.enabled.contains(kind)) {
                                FeedbackManager.shared.tap()
                                infoGame = kind
                            }
                        }
                    }
                    Text(L("home.tag_hint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        FeedbackManager.shared.tap()
                        store.startMatch()
                    } label: {
                        Label(L("home.start"), systemImage: "play.fill")
                    }
                    .buttonStyle(BigButtonStyle(colors: [.pink, .orange]))

                    Button {
                        FeedbackManager.shared.tap()
                        showSettings = true
                    } label: {
                        Label(L("home.settings"), systemImage: "gearshape.fill")
                    }
                    .buttonStyle(BigButtonStyle(colors: [Color(.systemGray2), Color(.systemGray)],
                                                font: .headline))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
            }

            // 玩法说明 + 加入/移出转盘（与设置页共用同一份开关状态）
            if let kind = infoGame {
                GameInfoOverlay(kind: kind) {
                    withAnimation(.easeOut(duration: 0.2)) { infoGame = nil }
                }
            }
        }
        .onAppear {
            if ScreenshotMode.autoPresents("gametag") { infoGame = .lipRead }
            if ScreenshotMode.autoPresents("hoftag") { infoGame = .hallOfFame }
        }
    }
}

/// 主界面玩法标签：未加入转盘的置灰
private struct GameTagChip: View {
    var kind: GameKind
    var included: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text("\(kind.emoji) \(kind.title)")
                if !included {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(kind.gradient))
            .grayscale(included ? 0 : 1)
            .opacity(included ? 1 : 0.45)
        }
        .buttonStyle(.plain)
    }
}

/// 玩法说明弹窗：规则 + 加入/移出转盘开关
private struct GameInfoOverlay: View {
    @EnvironmentObject var store: GameStore
    var kind: GameKind
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 14) {
                Text(kind.emoji).font(.system(size: 56))
                Text(kind.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(kind.rule)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)

                if let note = kind == .quiz ? "gametag.quiz_note"
                            : kind.isSimultaneous ? "gametag.hof_note" : nil {
                    Text(L(note))
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.yellow))
                }

                Toggle(isOn: store.gameEnabledBinding(for: kind)) {
                    Text(L("gametag.include"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                .tint(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.18)))

                Text(L("gametag.footer"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Button {
                    FeedbackManager.shared.tap()
                    onClose()
                } label: {
                    Text(L("gametag.close"))
                }
                .buttonStyle(BigButtonStyle(colors: [.white.opacity(0.95), .white],
                                            textColor: kind.colors[0], font: .headline))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(kind.gradient)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            )
            .padding(.horizontal, 28)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}

struct TeamCard: View {
    @Binding var team: Team
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(team.emoji)
                .font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("home.team_n", team.id + 1))
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
                TextField(L("home.team_placeholder"), text: $team.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .focused($focused)
                    .submitLabel(.done)
            }
            Spacer()
            Image(systemName: "pencil.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
                .onTapGesture { focused = true }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(team.gradient)
                .shadow(color: team.colors[0].opacity(0.4), radius: 8, y: 4)
        )
    }
}
