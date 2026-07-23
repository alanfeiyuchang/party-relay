import SwiftUI

struct WheelView: View {
    @EnvironmentObject var store: GameStore

    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var landedGame: GameKind?     // 停下的扇区
    @State private var isRespin = false          // 正在进行抢答后的二次转盘
    @State private var finalOpenBuzz = false     // 定盘时是否带开放抢答
    @State private var tickTimers: [DispatchWorkItem] = []

    /// 第一次转：全部启用扇区；二次转：只在普通玩法里转
    private var games: [GameKind] {
        isRespin ? store.settings.playableList : store.settings.wheelList
    }

    /// 落后队可跳过转盘、直接指定玩法（抢答二次转盘期间不适用）
    private var pickMode: Int? {
        isRespin ? nil : store.pickEligibleTeam
    }

    private var titleText: String {
        if let picker = pickMode {
            return L("wheel.pick_title", "\(store.teams[picker].emoji) \(store.teams[picker].name)")
        }
        return isRespin ? L("wheel.respin_title") : L("wheel.both_play")
    }

    private var titleColor: AnyShapeStyle {
        if pickMode != nil { return AnyShapeStyle(Color.orange) }
        return isRespin ? AnyShapeStyle(GameKind.quiz.gradient) : AnyShapeStyle(Color.primary)
    }

    var body: some View {
        ZStack {
            PartyBackground()
            VStack(spacing: 12) {
                // 顶部：轮次信息
                VStack(spacing: 6) {
                    Text(store.isOvertime ? L("wheel.overtime") : L("wheel.round", store.roundNumber, store.totalRounds))
                        .font(.subheadline.bold())
                        .foregroundStyle(store.isOvertime ? .orange : .secondary)
                    Text(titleText)
                        .font(.system(size: pickMode != nil ? 20 : 26, weight: .black, design: .rounded))
                        .foregroundStyle(titleColor)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 16)

                Spacer(minLength: 4)

                if let picker = pickMode {
                    // 追分特权：隐藏转盘，直接选玩法
                    PickGamePanel(teamIndex: picker)
                } else {
                    // 转盘
                    ZStack {
                        WheelCanvas(games: games)
                            .rotationEffect(.degrees(rotation))
                            .frame(width: 310, height: 310)

                        Triangle()
                            .fill(Color(red: 0.95, green: 0.26, blue: 0.37))
                            .frame(width: 34, height: 40)
                            .shadow(radius: 3, y: 2)
                            .offset(y: -167)

                        Button {
                            spin()
                        } label: {
                            Text(spinning ? "🎲" : L("wheel.spin"))
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(LinearGradient(colors: isRespin ? GameKind.quiz.colors : [.pink, .purple],
                                                             startPoint: .top, endPoint: .bottom))
                                        .shadow(color: .purple.opacity(0.5), radius: 8, y: 4)
                                )
                                .overlay(Circle().stroke(.white, lineWidth: 4))
                        }
                        .disabled(spinning)
                    }
                }

                Spacer(minLength: 4)

                // 大分横条
                HStack(spacing: 10) {
                    ForEach(store.teams) { team in
                        Text(L("wheel.score_chip", "\(team.emoji) \(team.name)", team.score))
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(team.gradient))
                    }
                }
                .padding(.bottom, 20)
            }

            // 停盘弹卡
            if let game = landedGame {
                if game == .quiz {
                    // 抢答扇区：宣告加成，再转一次
                    QuizModifierOverlay {
                        withAnimation { landedGame = nil }
                        isRespin = true
                        finalOpenBuzz = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { spin() }
                    }
                } else {
                    GameCardOverlay(game: game, openBuzz: finalOpenBuzz) {
                        landedGame = nil
                        store.gameDecided(game, openBuzz: finalOpenBuzz)
                        store.proceedToHandoff()
                    }
                }
            }
        }
        .onDisappear { tickTimers.forEach { $0.cancel() } }
    }

    private func spin() {
        guard !spinning, !games.isEmpty else { return }
        spinning = true
        FeedbackManager.shared.wheelStart()

        let target = games.randomElement()!
        let index = games.firstIndex(of: target)!
        let sector = 360.0 / Double(games.count)
        // WheelCanvas centers sector i at angle (-90° + sector·i), so the rotation
        // that brings it under the fixed top pointer is a multiple of `sector`,
        // not `sector·(i + 0.5)` — no extra half-sector offset.
        let sectorCenter = sector * Double(index)
        let currentMod = rotation.truncatingRemainder(dividingBy: 360)
        var delta = -sectorCenter - currentMod
        while delta < 0 { delta += 360 }
        let jitter = Double.random(in: -sector * 0.35...sector * 0.35)
        let turns = Double(Int.random(in: 3...5))
        let total = turns * 360 + delta + jitter
        let duration = 3.0

        withAnimation(.easeOut(duration: duration)) {
            rotation += total
        }

        // 减速"哒哒"触感
        tickTimers.forEach { $0.cancel() }
        tickTimers = []
        var t = 0.06
        while t < duration - 0.25 {
            let progress = t / duration
            let item = DispatchWorkItem {
                FeedbackManager.shared.wheelTick(intensity: 1 - progress * 0.7)
            }
            tickTimers.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: item)
            t += 0.06 + progress * progress * 0.5
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            spinning = false
            FeedbackManager.shared.wheelStop()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                landedGame = target
            }
        }
    }
}

// MARK: - 落后队指定玩法面板（替代转盘，直接选玩法）

private struct PickGamePanel: View {
    @EnvironmentObject var store: GameStore
    var teamIndex: Int

    var body: some View {
        VStack(spacing: 10) {
            Text(L("wheel.pick_subtitle"))
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(store.settings.playableList) { kind in
                    Button {
                        FeedbackManager.shared.tap()
                        store.pickGame(kind)
                    } label: {
                        HStack(spacing: 14) {
                            Text(kind.emoji).font(.system(size: 30))
                            Text(kind.title)
                                .font(.title3.bold())
                            Spacer()
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title3)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(kind.gradient)
                                .shadow(color: kind.colors[0].opacity(0.35), radius: 8, y: 4)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 26)
    }
}

// MARK: - Canvas 自绘转盘

struct WheelCanvas: View {
    var games: [GameKind]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 6
            let count = max(games.count, 1)
            let sector = 2 * .pi / Double(count)
            let startBase = -Double.pi / 2 - sector / 2

            for (i, game) in games.enumerated() {
                let start = startBase + sector * Double(i)
                let end = start + sector
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                            startAngle: .radians(start), endAngle: .radians(end),
                            clockwise: false)
                path.closeSubpath()

                let g = Gradient(colors: game.colors)
                context.fill(path, with: .linearGradient(
                    g,
                    startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
                    endPoint: CGPoint(x: center.x + radius, y: center.y + radius)))
                context.stroke(path, with: .color(.white), lineWidth: 3)

                let mid = start + sector / 2
                let labelR = radius * 0.62
                let pos = CGPoint(x: center.x + cos(mid) * labelR,
                                  y: center.y + sin(mid) * labelR)
                var text = context
                text.translateBy(x: pos.x, y: pos.y)
                text.rotate(by: .radians(mid + .pi / 2))
                text.draw(Text("\(game.emoji)\n\(game.title)")
                    .font(.system(size: count > 4 ? 13 : 15, weight: .heavy))
                    .foregroundStyle(.white),
                    at: .zero, anchor: .center)
            }

            let rim = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                             width: radius * 2, height: radius * 2))
            context.stroke(rim, with: .color(.white), lineWidth: 6)
        }
        .background(
            Circle().fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        )
        .clipShape(Circle())
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 抢答扇区弹卡（宣告开放抢答，再转一次）

private struct QuizModifierOverlay: View {
    var onRespin: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("⚡️").font(.system(size: 70))
                Text(L("quizcard.title"))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(L("quizcard.body"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)

                Button {
                    FeedbackManager.shared.tap()
                    onRespin()
                } label: {
                    Text(L("quizcard.respin"))
                }
                .buttonStyle(BigButtonStyle(colors: [.white.opacity(0.95), .white],
                                            textColor: GameKind.quiz.colors[1],
                                            font: .title3.bold()))
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(GameKind.quiz.gradient)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            )
            .padding(.horizontal, 30)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }
}

// MARK: - 定盘玩法卡

private struct GameCardOverlay: View {
    @EnvironmentObject var store: GameStore
    var game: GameKind
    var openBuzz: Bool
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(game.emoji)
                    .font(.system(size: 66))
                Text(game.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(game.rule)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                if openBuzz {
                    Text(L("gamecard.openbuzz"))
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.yellow))
                        .multilineTextAlignment(.center)
                }

                Text(L("gamecard.info_plain"))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.25)))

                Button {
                    FeedbackManager.shared.tap()
                    onContinue()
                } label: {
                    Text(L("gamecard.first_go", store.teams[store.firstTeamIndex].name))
                }
                .buttonStyle(BigButtonStyle(colors: [.white.opacity(0.95), .white],
                                            textColor: game.colors[0], font: .title3.bold()))
            }
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(game.gradient)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            )
            .padding(.horizontal, 30)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }
}
