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

    /// 普通大按钮的实际高度约 58~64pt，加高档给两倍
    private var minHeight: CGFloat? { tall ? 120 : nil }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(textColor)
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

struct HomeExitButton: View {
    @EnvironmentObject var store: GameStore
    /// 深色/彩色背景上用浅色描边样式
    var light: Bool = false
    @State private var showConfirm = false

    var body: some View {
        Button {
            FeedbackManager.shared.tap()
            showConfirm = true
        } label: {
            Label(L("common.back_home"), systemImage: "house.fill")
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
        }
        .accessibilityIdentifier("backHome")
        // 用 alert 而不是 confirmationDialog：alert 一定会同时显示「取消」按钮
        .alert(L("exit.confirm_title"), isPresented: $showConfirm) {
            Button(L("exit.confirm_action"), role: .destructive) {
                FeedbackManager.shared.tap()
                store.resetToHome()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("exit.confirm_body"))
        }
        .onAppear {
            guard ScreenshotMode.autoPresents("exitconfirm") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showConfirm = true }
        }
    }
}

/// 顶部只放一个返回主页按钮的行（用于原本没有顶栏的页面）
struct HomeExitBar: View {
    var light: Bool = false

    var body: some View {
        HStack {
            HomeExitButton(light: light)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}
