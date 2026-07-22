import SwiftUI

/// 主界面：红蓝两队（队名可编辑）+ 开始游戏 / 设置 + 右上角语言切换
struct HomeView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject var langManager = LanguageManager.shared
    @Binding var showSettings: Bool

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
                Text(L("home.subtitle"))
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

                // 已启用玩法一览（自适应换行）
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                    ForEach(store.settings.enabledList) { kind in
                        Text("\(kind.emoji) \(kind.title)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(kind.gradient))
                    }
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
