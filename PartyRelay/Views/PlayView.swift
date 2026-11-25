import SwiftUI
import Combine

/// 普通玩法（你说我猜 / 唇语 / 动作）：执机人立起手机看词，放平自动防窥
struct PlayView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject private var motion = MotionManager.shared
    @ObservedObject private var hinge = HingeMonitor.shared

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
            // 外屏只在猜词这一页点亮；相机会话也只在这段时间里跑
            CoverScreenModel.shared.mode = .question
            CoverScreenModel.shared.sync(remaining: remaining, total: store.roundDuration)
            CoverScreenModel.shared.enabled = true
            CoverScreenCamera.shared.start()
        }
        .onDisappear {
            motion.stop()
            CoverScreenModel.shared.enabled = false
            CoverScreenCamera.shared.stop()
        }
        .onReceive(timer) { _ in
            guard started, remaining > 0, !store.turnPaused else { return }
            remaining -= 1
            CoverScreenModel.shared.sync(remaining: remaining, total: store.roundDuration)
            if remaining == 0 {
                FeedbackManager.shared.timeUp()
                store.finishPlay(own: ownPoints, stolen: stolenPoints)
            } else if remaining <= 5 {
                FeedbackManager.shared.countdownTick()
            }
        }
    }

    // MARK: 3-2-1 预备

    @ViewBuilder private var readyBody: some View {
        if hinge.isLaptopPosture {
            // 预备页也要让开折痕：那个大数字原本正好压在中线上。整页收进上半屏——
            // 立着的那半朝着执机人，下半屏这几秒本来就没东西
            CreaseSplit {
                VStack(spacing: 24) {
                    HomeExitBar()
                    countdownStack
                }
            } bottom: {
                Color.clear
            }
            .onReceive(timer) { _ in tickCountdown() }
        } else {
            VStack(spacing: 24) {
                HomeExitBar()
                countdownStack
            }
            .onReceive(timer) { _ in tickCountdown() }
        }
    }

    private var countdownStack: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("\(game.emoji) \(game.title)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(game.gradient)
            if store.openBuzz {
                OpenBuzzBadge()
            }
            Text("\(countdown)")
                .font(.system(size: hinge.isLaptopPosture ? 76 : 110,
                              weight: .black, design: .rounded))
                .foregroundStyle(game.gradient)
                .contentTransition(.numericText(countsDown: true))
            Spacer()
        }
        .pageFrame()
    }

    private func tickCountdown() {
        guard !started, !store.turnPaused else { return }
        if countdown > 1 {
            FeedbackManager.shared.countdownTick()
            withAnimation { countdown -= 1 }
        } else {
            FeedbackManager.shared.wheelStop()
            withAnimation { started = true }
        }
    }

    // MARK: 游戏中

    /// 摊成 90° 时，按屏幕中线劈成两半：上半屏朝人（词 + 计时），下半屏朝天（操作按钮）。
    ///
    /// 折痕在屏幕上的真实位置系统**不提供任何 API**（`UIHinge` 只给 status 和 angle），
    /// 所以这里只能按中线分——物理折痕就在屏幕正中，这个假设对 Duo 成立。
    @ViewBuilder private var playBody: some View {
        if hinge.isLaptopPosture {
            // 摊开时要跟物理折痕对齐，不能再被 pageFrame 的 560×760 上限居中留边
            CreaseSplit {
                wordHalf
            } bottom: {
                // 平躺那半屏靠近自己的那一头才是拇指够得到的地方，按钮压到底边去，
                // 顺带把折痕那一侧让得更空
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    actionButtons
                }
            }
        } else {
            VStack(spacing: 14) {
                wordHalf
                actionButtons
            }
            .pageFrame()
        }
    }

    /// 词那一半：摊开时它就是立起来朝人的上半屏
    private var wordHalf: some View {
        VStack(spacing: 14) {
            topStatusBar
            if !hinge.isLaptopPosture { FoldHintPill() }
            if store.catchUp.isActive {
                CatchUpBanner(catchUp: store.catchUp, teamName: store.playingTeam.name)
            }
            wordArea
        }
    }

    private var topStatusBar: some View {
        Group {
            // 顶部状态栏
            HStack(spacing: 10) {
                HomeExitButton()
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.soloMode
                         ? "\(game.emoji) \(game.title)"
                         : store.isRotation
                         ? "\(store.performer.emoji) \(store.performer.name)"
                         : "\(store.playingTeam.emoji) \(store.playingTeam.name)")
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
                CoverScreenPill()
                if store.openBuzz { OpenBuzzBadge(compact: true) }
                if store.settings.privacyGuardOn {
                    ForceRevealButton(forceShow: $forceShow, taps: $forceTaps)
                }
                TimerRing(remaining: remaining, total: store.roundDuration, size: 50)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    @ViewBuilder private var wordArea: some View {
        if store.isRotation && !hinge.isLaptopPosture {
            // 摊平：其他人的名字围着词，谁猜对点谁，没有单独的猜对按钮
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                GuesserRing(onGuess: creditGuess) { wordOrPrivacy }
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 0) {
                Spacer()
                wordOrPrivacy
                Spacer()
            }
        }
    }

    private var actionButtons: some View {
            // 操作按钮
            VStack(spacing: 10) {
                if store.isRotation {
                    // 折起来时名字按钮在**这一半**：立起来那半只放词和计时，
                    // 一个需要点的东西都不留（摊平时名字还是围着词排，见 wordArea）
                    if hinge.isLaptopPosture {
                        GuesserPad(onGuess: creditGuess)
                    }
                } else if store.openBuzz {
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

    /// 词卡 / 防窥屏（姿态驱动）
    @ViewBuilder private var wordOrPrivacy: some View {
        if wordVisible {
            wordCard
        } else {
            PrivacyCard(game: game)
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
        // 摊平的轮流模式上下还要排两圈名字，词卡压矮一点；
        // 折起来之后名字挪到了下半屏，这半屏只剩词，不用再让位
        .padding(.vertical, store.isRotation && !hinge.isLaptopPosture ? 28 : 42)
        .padding(.horizontal, 20)
        // 摊开时撑满立起来那半屏：那半屏除了这个词没别的事要干，
        // 卡越大隔着一张桌子越好认。maxHeight 要加在 background 之前，底色才跟着长
        .frame(maxHeight: hinge.isLaptopPosture ? .infinity : nil)
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

    /// 轮流模式：表演者点了某个人的名字
    private func creditGuess(_ guesser: UUID) {
        FeedbackManager.shared.correct()
        ownPoints += 1
        store.creditGuess(by: guesser)   // 两人各 +1，并把这个词记成「某某猜对」
        CoverScreenModel.shared.flashCorrect(store.coverScorers(guesser: guesser))
        showNextWord()
    }

    private func advanceWord(guessed: Bool) {
        store.markCurrentWord(guessed: guessed)
        // 换词也要让外屏闪一下：对面看不到这块屏，不说的话他们还在猜上一个词
        if guessed { CoverScreenModel.shared.flashCorrect(store.coverScorers()) }
        else { CoverScreenModel.shared.flashSkip() }
        showNextWord()
    }

    private func showNextWord() {
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
