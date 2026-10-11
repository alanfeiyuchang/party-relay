import SwiftUI

/// 准备页（启动页选完模式后进来）：
/// - 对战：红蓝两队（队名可编辑）
/// - 快速：不分队，只看玩法
/// - 轮流：先定人数，再给每个人起名
/// 下面都是玩法标签 + 开始游戏 / 设置；左上角回模式选择，右上角语言切换
///
/// 布局按可用空间挑，不按设备型号挑：
/// - 宽而扁（iPhone Duo 内屏横放 951×669pt）：两栏，左「谁在玩」右「玩什么」，
///   两栏等宽、各自垂直居中，富余的高度均分成上下留白
/// - 其余形态（手机竖屏、Duo 外屏、内屏竖放、分屏窄条）：单栏限宽居中
struct HomeView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject var langManager = LanguageManager.shared
    @Binding var showSettings: Bool
    @State private var infoGame: GameKind?
    /// 轮流模式：正在编辑的玩家（卡片从他的胶囊里展开）
    @State private var editingPlayer: UUID?
    @Namespace private var playerCards

    private enum Metrics {
        /// 低于这个宽度排两栏会把按钮和标签挤扁
        static let twoColumnMinWidth: CGFloat = 700
        static let columnMaxWidth: CGFloat = 400
        static let singleMaxWidth: CGFloat = 520
        /// 语言按钮距屏幕上沿的距离
        static let langTopPadding: CGFloat = 18
        /// 给浮在右上角的语言按钮让出的高度
        static let topInset: CGFloat = 68
        /// 开始/设置按钮距屏幕下沿的距离：贴着底边最好按，但要留出手势条的位置
        static let actionsBottomPadding: CGFloat = 12
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PartyBackground()

            FittingScroll { size in
                layout(for: size)
            }

            // 顶栏两个按钮浮在上面，不参与排版。它们要是排进内容流里，
            // 矮屏上就会连着整列内容一起被挤出屏幕（Duo 内屏上出过这个问题）。
            HStack {
                modeBackButton
                Spacer()
                LanguageToggleButton()
            }
            .padding(.horizontal, 20)
            .padding(.top, Metrics.langTopPadding)

            if let id = editingPlayer {
                PlayerEditCard(playerID: id, namespace: playerCards) { editingPlayer = nil }
                    .zIndex(1)
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

    @ViewBuilder private func layout(for size: CGSize) -> some View {
        if size.width >= Metrics.twoColumnMinWidth, size.width > size.height {
            wideLayout
        } else {
            narrowLayout
        }
    }

    /// 宽扁屏：两栏对着排，共用一条底线。
    /// 底部对齐既让两栏看着是一组，又把「开始游戏」放在低处，握着手机时拇指够得到。
    private var wideLayout: some View {
        HStack(alignment: .bottom, spacing: 32) {
            VStack(spacing: 16) {
                titleBlock
                teamCards
                playerSetup
                infoRow
            }
            .frame(maxWidth: Metrics.columnMaxWidth)

            VStack(spacing: 20) {
                gameTags
                actions
            }
            .frame(maxWidth: Metrics.columnMaxWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, Metrics.topInset)
        .padding(.bottom, Metrics.actionsBottomPadding)
    }

    /// 单栏：手机竖屏、Duo 外屏、内屏竖放、分屏窄条都走这条。
    /// 上半部分（标题～玩法标签）在剩余空间里居中，开始/设置固定贴在底部——
    /// 主操作放在拇指最容易够到的地方，屏幕越高越明显。
    private var narrowLayout: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                titleBlock
                teamCards
                playerSetup
                infoRow
                // 固定间隔，不用弹簧——弹簧会把这块内容按屏幕高度拉散
                Spacer().frame(height: 22)
                gameTags
            }
            .frame(maxWidth: Metrics.singleMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            actions
                .frame(maxWidth: Metrics.singleMaxWidth)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, Metrics.topInset)
        .padding(.bottom, Metrics.actionsBottomPadding)
    }

    /// 回到模式三选一
    private var modeBackButton: some View {
        Button {
            FeedbackManager.shared.tap()
            store.backToMenu()
        } label: {
            Label(L("home.change_mode"), systemImage: "chevron.left")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.85)))
        }
        .accessibilityIdentifier("changeMode")
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text("🎉")
                .font(.system(size: 38))
            Text(L("app.title"))
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.pink, .orange, .purple],
                                   startPoint: .leading, endPoint: .trailing)
                )
            Text(subtitle)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var subtitle: String {
        switch store.playMode {
        case .match:    return L(store.settings.smallScoreWin ? "home.subtitle_small" : "home.subtitle")
        case .quick:    return L("home.subtitle_solo")
        case .rotation: return L("home.subtitle_rotation")
        }
    }

    /// 两支队伍（可编辑队名）。只有对战模式分队
    @ViewBuilder private var teamCards: some View {
        if store.playMode == .match {
            VStack(spacing: 14) {
                ForEach($store.teams) { $team in
                    TeamCard(team: $team)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// 轮流模式：人数 + 每个人的名字
    @ViewBuilder private var playerSetup: some View {
        if store.isRotation {
            // 与下面玩法标签、开始按钮同宽
            PlayerSetupPanel(editing: $editingPlayer, namespace: playerCards)
                .padding(.horizontal, 28)
        }
    }

    private var infoRow: some View {
        HStack(spacing: 18) {
            switch store.playMode {
            case .match:
                Label(L("home.rounds", store.settings.totalRounds),
                      systemImage: "arrow.triangle.2.circlepath")
            case .quick:
                Label(L("home.solo_badge"), systemImage: "bolt.fill")
                    .foregroundStyle(PlayMode.quick.colors[0])
            case .rotation:
                Label(L("home.rotation_badge"), systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(PlayMode.rotation.colors[0])
            }
            Label(L(store.playMode == .match ? "home.seconds_per_turn"
                    : store.isRotation ? "home.seconds_rotation" : "home.seconds_solo",
                    store.settings.roundSeconds),
                  systemImage: "timer")
        }
        .font(.subheadline.bold())
        .foregroundStyle(.secondary)
    }

    /// 玩法一览（点标签看规则并加入/移出转盘；已排除的置灰）
    private var gameTags: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                      spacing: 8) {
                ForEach(store.settings.relevantGames) { kind in
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
        // 与下面「开始游戏」按钮同宽，两块左右对齐
        .padding(.horizontal, 28)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                FeedbackManager.shared.tap()
                store.startGame()
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
        // 底部留白统一由 Metrics.actionsBottomPadding 控制，这里不再另加
        .padding(.horizontal, 28)
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
