import SwiftUI

// MARK: - 派对渐变背景

struct PartyBackground: View {
    var colors: [Color] = [Color(red: 0.98, green: 0.94, blue: 1.0),
                           Color(red: 0.90, green: 0.95, blue: 1.0)]
    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - 大圆角按钮

struct BigButtonStyle: ButtonStyle {
    var colors: [Color]
    var textColor: Color = .white
    var font: Font = .title2.bold()
    /// 加高按钮（得分 / 被抢答用）：高度约为普通大按钮的两倍
    var tall: Bool = false
    /// 白字压在饱和底色上时给一层暗投影，把对比度补回来（队色按钮用）
    var shadowedText: Bool = false

    /// 普通大按钮的实际高度约 58~64pt，加高档给两倍
    private var minHeight: CGFloat? { tall ? 120 : nil }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(textColor)
            .shadow(color: .black.opacity(shadowedText ? 0.4 : 0), radius: 3, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: colors[0].opacity(0.45), radius: 10, y: 5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 倒计时圆环

struct TimerRing: View {
    var remaining: Int
    var total: Int
    var size: CGFloat = 56

    private var fraction: CGFloat {
        total > 0 ? CGFloat(remaining) / CGFloat(total) : 0
    }

    private var ringColor: Color {
        if remaining <= 5 { return .red }
        if remaining <= 15 { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
            Text("\(remaining)")
                .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                .foregroundStyle(ringColor)
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 追分卡横幅（透明展示加成）

struct CatchUpBanner: View {
    var catchUp: CatchUp
    var teamName: String

    var body: some View {
        if catchUp.isActive {
            let perks = catchUp.perks
            VStack(spacing: 4) {
                Text(L("catchup.active", teamName))
                    .font(.subheadline.bold())
                if !perks.isEmpty {
                    Text(perks.joined(separator: " · "))
                        .font(.caption.bold())
                        .opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: .orange.opacity(0.4), radius: 6, y: 3)
            )
        }
    }
}

// MARK: - 出现过的词标签（猜对=正常色，跳过=灰底）

struct PlayedWordChip: View {
    var word: PlayedWord
    /// 猜对时的底色（跳过一律灰底，与猜对的一眼区分）
    var tint: AnyShapeStyle
    var textColor: Color = .white
    var font: Font = .caption2.bold()

    var body: some View {
        Text(word.text)
            .font(font)
            .lineLimit(1)
            .foregroundStyle(word.guessed ? textColor : Color.black.opacity(0.45))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(word.guessed ? tint : AnyShapeStyle(Color(.systemGray3))))
    }
}

/// 简单的自适应换行流式布局（用于词语标签墙）
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 200
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                       anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - 得分弹跳徽章

struct ScoreBadge: View {
    var team: Team
    /// 展示的比分（大分制传大分，小分制传累计小分）
    var score: Int
    var highlight: Bool = false
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 6) {
            Text("\(team.emoji) \(team.name)")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(score)")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .scaleEffect(bounce ? 1.25 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(team.gradient)
                .shadow(color: team.colors[0].opacity(0.4), radius: 8, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white, lineWidth: highlight ? 4 : 0)
                )
        )
        .onChange(of: score) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bounce = false }
            }
        }
    }
}

// MARK: - 返回主页按钮（所有游戏中页面顶部，二次确认后才真的退出）

// MARK: - 侧边栏里的暂停键（iPhone Duo）

/// 屏幕一侧有没有整条留给系统状态栏的竖条，有的话多宽。
/// iPhone Duo 的两块屏都把时间、Wi-Fi 竖着放在右边一条里，下面整段是空的；
/// 暂停键挪进这条里，不再浮在居中内容列的左上角。普通手机为 0，暂停键照旧在左上角
private struct PauseSidebarWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var pauseSidebarWidth: CGFloat {
        get { self[PauseSidebarWidthKey.self] }
        set { self[PauseSidebarWidthKey.self] = newValue }
    }
}

struct HomeExitButton: View {
    enum Placement { case inline, sidebar }

    @EnvironmentObject var store: GameStore
    @Environment(\.pauseSidebarWidth) private var sidebarWidth
    /// 深色/彩色背景上用浅色描边样式
    var light: Bool = false
    var placement: Placement = .inline
    @State private var showConfirm = false

    /// 只有正在猜词的那一遍能重开；转盘、交接、结算页上没有「小局」可重开
    private var canRestartTurn: Bool { store.phase == .playing }

    var body: some View {
        // 有侧边栏时，页面里的那颗不画，由 RootView 在侧边栏里画一颗（同一个弹窗逻辑）
        if placement == .inline && sidebarWidth > 0 {
            EmptyView()
        } else {
            button
        }
    }

    private var button: some View {
        Button {
            FeedbackManager.shared.tap()
            showConfirm = true
        } label: {
            switch placement {
            case .inline:
                Label(L("common.pause"), systemImage: "pause.fill")
                    .font(.caption.bold())
                    .foregroundStyle(light ? .white : Color.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(light ? AnyShapeStyle(.white.opacity(0.22))
                                        : AnyShapeStyle(.white.opacity(0.85)))
                            .overlay(Capsule().stroke(light ? .white.opacity(0.5) : .clear, lineWidth: 1))
                    )
            case .sidebar:
                // 竖条只有四五十点宽：图标在上、字在下
                VStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2))
                    Text(L("common.pause"))
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(Color(white: 0.3))
                .frame(width: max(sidebarWidth - 4, 40))
            }
        }
        .accessibilityIdentifier("backHome")
        // 用 alert 而不是 confirmationDialog：alert 一定会同时显示「取消」按钮。
        // 一遍正在进行时（计时已经开始）多给一个「重开小局」
        .alert(L("exit.paused_title"), isPresented: $showConfirm) {
            if canRestartTurn {
                Button(L("exit.restart_turn")) {
                    FeedbackManager.shared.tap()
                    store.restartTurn()
                }
            }
            Button(L("exit.confirm_action"), role: .destructive) {
                FeedbackManager.shared.tap()
                store.resetToHome()
            }
            Button(L("exit.resume"), role: .cancel) {}
        } message: {
            Text(L(canRestartTurn ? "exit.paused_body" : "exit.confirm_body"))
        }
        // 弹窗开着就停表，点「取消」回来接着计时
        .onChange(of: showConfirm) {
            store.turnPaused = showConfirm && canRestartTurn
        }
        .onAppear {
            guard ScreenshotMode.autoPresents("exitconfirm") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showConfirm = true }
        }
    }
}

/// 顶部只放一个暂停键的行（用于原本没有顶栏的页面）；暂停键在侧边栏时整行不占地方
struct HomeExitBar: View {
    @Environment(\.pauseSidebarWidth) private var sidebarWidth
    var light: Bool = false

    var body: some View {
        if sidebarWidth > 0 {
            Color.clear.frame(height: 10)
        } else {
            HStack {
                HomeExitButton(light: light)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }
}

// MARK: - 垂直空间不够时可滚动

/// 高度够时和普通 VStack 一样（Spacer 照常把内容撑开），高度不够时整页可以滚。
/// iPhone Duo 内屏是横着的，只有 669pt 高，按手机竖屏排的页面会溢出，顶部或底部的控件会被推出屏幕。
struct FittingScroll<Content: View>: View {
    /// 可用尺寸交给内容自己判断排版（宽扁排两栏、其余排单栏）
    @ViewBuilder var content: (CGSize) -> Content

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content(geo.size).frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// MARK: - 内容限宽

/// 页面内容的尺寸上限：屏幕比这更大时，多出来的空间变成四周留白，而不是把内容拉散。
/// 没有上限的话，Duo 内屏横放会把卡片拉成横贯整屏的长条，内屏竖放 / iPad 又会在
/// 中间豁开一大条空白（弹簧把按钮全推到屏底）。
extension View {
    func pageFrame(maxWidth: CGFloat = 560, maxHeight: CGFloat = 760) -> some View {
        frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
