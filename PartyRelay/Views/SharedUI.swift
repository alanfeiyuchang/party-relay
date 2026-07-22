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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
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
    var highlight: Bool = false
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 6) {
            Text("\(team.emoji) \(team.name)")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(team.score)")
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
        .onChange(of: team.score) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bounce = false }
            }
        }
    }
}
