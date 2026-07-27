import SwiftUI
import Combine

/// 普通玩法（你说我猜 / 唇语 / 动作）：执机人立起手机看词，放平自动防窥
struct PlayView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject private var motion = MotionManager.shared

    @State private var word = ""
    @State private var ownPoints = 0        // 己方猜对
    @State private var stolenPoints = 0     // 开放抢答被对方偷走的分
    @State private var skipsLeft = 0
    @State private var remaining = 60
    @State private var countdown = 3
    @State private var started = false
    @State private var wordBounce = false
    @State private var forceShow = false    // 连点三次强制显词
    @State private var forceTaps: [Date] = []

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var game: GameKind { store.currentGame }

    /// 防偷窥模式关闭（默认）时始终显示词；开启时立起/强制才显示
    private var wordVisible: Bool {
        guard store.settings.privacyGuardOn else { return true }
        return forceShow || motion.posture == .upright || motion.posture == .unknown
    }

    var body: some View {
        ZStack {
            PartyBackground()
            if started {
                playBody
            } else {
                readyBody
            }
        }
        .onAppear {
            remaining = store.roundDuration
            skipsLeft = store.skipAllowance
            word = store.nextWord()
            if store.settings.privacyGuardOn { motion.start() }
        }
        .onDisappear { motion.stop() }
        .onReceive(timer) { _ in
            guard started, remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 {
                FeedbackManager.shared.timeUp()
                store.finishPlay(own: ownPoints, stolen: stolenPoints)
            } else if remaining <= 5 {
                FeedbackManager.shared.countdownTick()
            }
        }
    }

    // MARK: 3-2-1 预备

    private var readyBody: some View {
        VStack(spacing: 24) {
            HomeExitBar()
            Spacer()
            Text("\(game.emoji) \(game.title)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(game.gradient)
            if store.openBuzz {
                OpenBuzzBadge()
            }
            Text("\(countdown)")
                .font(.system(size: 110, weight: .black, design: .rounded))
                .foregroundStyle(game.gradient)
                .contentTransition(.numericText(countsDown: true))
            Spacer()
        }
        .onReceive(timer) { _ in
            guard !started else { return }
            if countdown > 1 {
                FeedbackManager.shared.countdownTick()
                withAnimation { countdown -= 1 }
            } else {
                FeedbackManager.shared.wheelStop()
                withAnimation { started = true }
            }
        }
    }

    // MARK: 游戏中

    private var playBody: some View {
        VStack(spacing: 14) {
            // 顶部状态栏
            HStack(spacing: 10) {
                HomeExitButton()
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.playingTeam.emoji) \(store.playingTeam.name)")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(L("play.this_turn", ownPoints)
                         + (stolenPoints > 0 ? " · " + L("play.stolen", stolenPoints) : ""))
                        .font(.subheadline.bold())
                        .foregroundStyle(game.colors[0])
                        .contentTransition(.numericText())
                }
                Spacer()
                if store.openBuzz { OpenBuzzBadge(compact: true) }
                if store.settings.privacyGuardOn {
                    ForceRevealButton(forceShow: $forceShow, taps: $forceTaps)
                }
                TimerRing(remaining: remaining, total: store.roundDuration, size: 50)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if store.catchUp.isActive {
                CatchUpBanner(catchUp: store.catchUp, teamName: store.playingTeam.name)
            }

            Spacer()

            // 词卡 / 防窥屏（姿态驱动）
            if wordVisible {
                wordCard
            } else {
                PrivacyCard(game: game)
            }

            Spacer()

            // 操作按钮
            VStack(spacing: 10) {
                if store.openBuzz {
                    HStack(spacing: 10) {
                        Button {
                            FeedbackManager.shared.correct()
                            ownPoints += 1
                            advanceWord(guessed: true)
                        } label: {
                            Label(L("play.correct_us"), systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(BigButtonStyle(colors: [.green, .mint], font: .headline, tall: true))

                        Button {
                            FeedbackManager.shared.buzz()
                            stolenPoints += 1
                            advanceWord(guessed: true)
                        } label: {
                            Label(L("play.sniped_them"), systemImage: "bolt.fill")
                        }
                        .buttonStyle(BigButtonStyle(colors: [.red, .orange], font: .headline, tall: true))
                    }
                } else {
                    Button {
                        FeedbackManager.shared.correct()
                        ownPoints += 1
                        advanceWord(guessed: true)
                    } label: {
                        Label(L("play.correct"), systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(BigButtonStyle(colors: [.green, .mint], tall: true))
                }

                Button {
                    FeedbackManager.shared.skip()
                    skipsLeft -= 1
                    advanceWord(guessed: false)
                } label: {
                    Label(L("play.skip_n", skipsLeft), systemImage: "arrow.uturn.right.circle.fill")
                }
                .buttonStyle(BigButtonStyle(colors: skipsLeft > 0
                                            ? [.orange, .yellow]
                                            : [Color(.systemGray3), Color(.systemGray4)],
                                            font: .headline))
                .disabled(skipsLeft <= 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private var wordCard: some View {
        VStack(spacing: 12) {
            Text(hintLabel)
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.85))
            Text(word)
                .font(.system(size: word.count > 4 ? 44 : 58, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .scaleEffect(wordBounce ? 1.08 : 1)
            if store.settings.privacyGuardOn {
                Text(L("play.word_footer"))
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(game.gradient)
                .shadow(color: game.colors[0].opacity(0.45), radius: 14, y: 6)
        )
        .padding(.horizontal, 24)
    }

    private var hintLabel: String {
        switch game {
        case .describeGuess: return L("play.hint.describeGuess")
        case .lipRead:       return L("play.hint.lipRead")
        case .act:           return L("play.hint.act")
        default:             return ""
        }
    }

    private func advanceWord(guessed: Bool) {
        store.markCurrentWord(guessed: guessed)
        word = store.nextWord()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { wordBounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { wordBounce = false }
        }
    }
}

// MARK: - 共享小组件

/// 开放抢答徽章
struct OpenBuzzBadge: View {
    var compact = false

    var body: some View {
        Text(compact ? L("play.openbuzz_badge") : L("play.openbuzz_full"))
            .font(.caption.bold())
            .foregroundStyle(.black)
            .lineLimit(compact ? 1 : nil)
            .fixedSize(horizontal: compact, vertical: false)
            .padding(.horizontal, compact ? 8 : 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.yellow))
    }
}

/// 防窥屏（放平时词自动隐藏）
struct PrivacyCard: View {
    var game: GameKind

    var body: some View {
        VStack(spacing: 14) {
            Text("🙈")
                .font(.system(size: 60))
            Text(L("play.privacy_title"))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(L("play.privacy_body"))
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.2, blue: 0.3),
                                              Color(red: 0.1, green: 0.1, blue: 0.18)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
        )
        .padding(.horizontal, 24)
    }
}

/// 连点三次强制显词按钮
struct ForceRevealButton: View {
    @Binding var forceShow: Bool
    @Binding var taps: [Date]

    var body: some View {
        Button {
            let now = Date()
            taps = taps.filter { now.timeIntervalSince($0) < 1.2 } + [now]
            if taps.count >= 3 {
                taps = []
                forceShow.toggle()
                FeedbackManager.shared.buzz()
            } else {
                FeedbackManager.shared.tap()
            }
        } label: {
            VStack(spacing: 1) {
                Image(systemName: forceShow ? "eye.fill" : "eye.slash")
                    .font(.subheadline)
                Text(forceShow ? L("play.force_on") : L("play.force_tap3"))
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(forceShow ? .white : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(forceShow
                               ? AnyShapeStyle(LinearGradient(colors: [.orange, .pink],
                                                              startPoint: .top, endPoint: .bottom))
                               : AnyShapeStyle(.white.opacity(0.8)))
            )
        }
    }
}
