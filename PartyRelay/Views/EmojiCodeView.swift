import SwiftUI
import Combine

/// 表情密码：出题人看词 → 用系统 emoji 键盘拼出来 → 把词藏起来，整屏只剩表情给队友猜
///
/// 和你画我猜正好相反：那边是当众一笔一笔画，这边是先私下拼好、展示时画面完全冻结——
/// 展示屏上除了表情什么都没有，要改表情就得把手机拿回来（按「收起」回到看词界面）。
/// 计分按钮全部留在看词界面，跟你画我猜一致。
///
/// 计时是两套各走各的，任一时刻只有一套在动：
/// - 看词界面（拼表情）：每个词单独一份，长度是设置里的「拼表情时长」（emojiWordSeconds，
///   默认 30，可调 10~90）。出题人只有这么久拼 emoji，走完这个词就作废换下一个（不扣跳过次数）。
///   这份不计入单局时长。
/// - 展示界面（队友猜）：走 store.roundDuration，也就是主设置里的每队单局时长，和别的玩法一样，
///   跨词累计，走完这一遍就结束。
/// 换句话说：拼的时候单局时钟停着，展示的时候拼表情时钟停着。
struct EmojiCodeView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject private var motion = MotionManager.shared

    @State private var word = ""
    @State private var code = ""               // 拼好的表情串
    @State private var ownPoints = 0
    @State private var stolenPoints = 0
    @State private var skipsLeft = 0
    @State private var composeLeft = GameSettings().emojiWordSeconds  // 本词拼表情还剩几秒（只在看词界面走表）
    @State private var turnLeft = GameSettings().roundSeconds         // 本遍单局时长还剩几秒（只在展示界面走表）
    @State private var showDisplay = false     // 按键切换：看词界面 / 展示界面
    @State private var keyboardUp = false      // 输入框是否持有第一响应者
    @State private var forceShow = false       // 连点三次强制显词（防偷窥模式下）
    @State private var forceTaps: [Date] = []

    /// 一条密码最多几个表情：再多队友一眼读不完，展示屏也放不下
    static let maxEmojis = 12

    /// 拼表情：每个词单独一份（设置里可调 10~90 秒），不计入单局时长
    private var composeSeconds: Int { store.settings.emojiWordSeconds }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var game: GameKind { .emojiCode }

    private var emojis: [String] { code.map(String.init) }
    /// 展示用：表情之间留空，读起来不糊成一片，也方便换行
    private var spacedCode: String { emojis.joined(separator: " ") }

    /// 防偷窥模式下，看词界面放平自动隐词
    private var wordHiddenByGuard: Bool {
        store.settings.privacyGuardOn && !forceShow && motion.posture == .flat
    }

    /// 已经猜过一阵、这会儿回到看词界面：单局时钟停在原地，下次展示接着走
    private var turnClockStarted: Bool { turnLeft < store.roundDuration }

    var body: some View {
        ZStack {
            PartyBackground()
            if showDisplay {
                displayBody
            } else {
                composeBody
            }
        }
        .onAppear {
            composeLeft = composeSeconds
            turnLeft = store.roundDuration
            skipsLeft = store.skipAllowance
            if word.isEmpty { word = store.nextWord() }
            if store.settings.privacyGuardOn { motion.start() }
            if let m = ScreenshotMode.mode, m == "emoji" || m == "emojiguess" {
                word = LanguageManager.shared.language == .en ? "The Lion King" : "狮子王"
                code = "🦁👑🌍"
                ownPoints = 2
                showDisplay = m == "emojiguess"
                // 截图里两块表都摆成「正在走」的样子
                composeLeft = max(1, composeSeconds * 4 / 5)
                turnLeft = max(1, store.roundDuration * 3 / 4)
            }
            keyboardUp = !showDisplay
        }
        .onDisappear { motion.stop() }
        .onReceive(timer) { _ in
            if showDisplay {
                // 队友在猜：走单局时长，跨词累计，和别的玩法一样
                guard turnLeft > 0 else { return }
                turnLeft -= 1
                if turnLeft == 0 {
                    FeedbackManager.shared.timeUp()
                    store.finishPlay(own: ownPoints, stolen: stolenPoints)
                } else if turnLeft <= 5 {
                    FeedbackManager.shared.countdownTick()
                }
            } else {
                // 出题人在拼表情：走本词自己那份，走完这个词就作废换下一个（不扣跳过次数）
                guard composeLeft > 0 else { return }
                composeLeft -= 1
                if composeLeft == 0 {
                    FeedbackManager.shared.timeUp()
                    nextRiddle(guessed: false)
                } else if composeLeft <= 5 {
                    FeedbackManager.shared.countdownTick()
                }
            }
        }
    }

    // MARK: 看词界面（拼表情 + 计分按钮都在这里）

    private var composeBody: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HomeExitButton()
                TimerRing(remaining: composeLeft, total: composeSeconds, size: 46)
                Text("+\(ownPoints)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(game.colors[0])
                    .contentTransition(.numericText())
                if stolenPoints > 0 {
                    Text(L("play.stolen", stolenPoints))
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                Spacer()
                pausedTurnChip
                if store.openBuzz { OpenBuzzBadge(compact: true) }
                if store.settings.privacyGuardOn {
                    ForceRevealButton(forceShow: $forceShow, taps: $forceTaps)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if store.catchUp.isActive {
                CatchUpBanner(catchUp: store.catchUp, teamName: store.playingTeam.name)
            }

            // 键盘弹起后上半部分空间有限，放进滚动区，小屏也不会挤掉按钮
            ScrollView {
                VStack(spacing: 8) {
                    wordStrip
                    codeField
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            // 放在滚动区外面：键盘弹起后上半部分被压缩，这行提示也要一直看得见
            Text(L("emoji.only_emoji_hint"))
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            actionButtons
        }
    }

    /// 看词界面上那圈是「拼表情」的表；单局那块表这会儿停着，用小胶囊报一下还剩多少
    private var pausedTurnChip: some View {
        Text(L(turnClockStarted ? "emoji.turn_paused" : "emoji.turn_pending", turnLeft))
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(0.85)))
    }

    /// 词条：防偷窥放平时整条换成遮挡样式，页面高度不跳
    private var wordStrip: some View {
        VStack(spacing: 4) {
            Text(wordHiddenByGuard ? L("play.privacy_title") : L("emoji.encoder_only"))
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
            Text(wordHiddenByGuard ? "🙈" : word)
                .font(.system(size: word.count > 6 ? 28 : 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(wordHiddenByGuard
                      ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.2, green: 0.2, blue: 0.3),
                                                              Color(red: 0.1, green: 0.1, blue: 0.18)],
                                                     startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(game.gradient))
                .shadow(color: game.colors[0].opacity(0.35), radius: 10, y: 5)
        )
        .padding(.horizontal, 20)
    }

    /// 表情输入框（系统 emoji 键盘）+ 计数 / 清空
    private var codeField: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                EmojiField(text: $code,
                           focused: $keyboardUp,
                           maxCount: Self.maxEmojis,
                           placeholder: L("emoji.placeholder"))
                    .frame(height: 42)

                Text("\(emojis.count)/\(Self.maxEmojis)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                Button {
                    guard !code.isEmpty else { return }
                    FeedbackManager.shared.skip()
                    code = ""
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundStyle(code.isEmpty ? Color(.systemGray3) : .red)
                }
                .disabled(code.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            )
        }
        .padding(.horizontal, 20)
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                FeedbackManager.shared.tap()
                keyboardUp = false
                showDisplay = true
            } label: {
                Label(L("emoji.start_guess"), systemImage: "eye.fill")
            }
            .buttonStyle(BigButtonStyle(colors: code.isEmpty
                                        ? [Color(.systemGray3), Color(.systemGray4)]
                                        : game.colors,
                                        font: .title3.bold()))
            .disabled(code.isEmpty)

            if store.openBuzz {
                HStack(spacing: 10) {
                    correctButton(compactLabel: true)
                    Button {
                        FeedbackManager.shared.buzz()
                        stolenPoints += 1
                        nextRiddle(guessed: true)
                    } label: {
                        Label(L("draw.sniped"), systemImage: "bolt.fill")
                    }
                    .buttonStyle(BigButtonStyle(colors: [.red, .orange], font: .headline))
                }
            } else {
                correctButton(compactLabel: false)
            }

            Button {
                FeedbackManager.shared.skip()
                skipsLeft -= 1
                nextRiddle(guessed: false)
            } label: {
                Label(L("play.skip_n", skipsLeft), systemImage: "arrow.uturn.right.circle.fill")
            }
            .buttonStyle(BigButtonStyle(colors: skipsLeft > 0
                                        ? [.orange, .yellow]
                                        : [Color(.systemGray3), Color(.systemGray4)],
                                        font: .subheadline.bold()))
            .disabled(skipsLeft <= 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private func correctButton(compactLabel: Bool) -> some View {
        Button {
            FeedbackManager.shared.correct()
            ownPoints += 1
            nextRiddle(guessed: true)
        } label: {
            Label(compactLabel ? L("play.correct_us") : L("draw.correct_plain"),
                  systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(BigButtonStyle(colors: [.green, .mint], font: .headline))
    }

    // MARK: 展示界面（只剩表情，改不了也点不了）

    private var displayBody: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HomeExitButton()
                TimerRing(remaining: turnLeft, total: store.roundDuration, size: 48)
                Text("+\(ownPoints)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(game.colors[0])
                    .contentTransition(.numericText())
                Spacer()
                if store.openBuzz { OpenBuzzBadge(compact: true) }
                Text(L("draw.word_hidden"))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.8)))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(L("emoji.guess_title"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Text(L("emoji.guess_timer"))
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(spacedCode)
                    .font(.system(size: emojis.count <= 4 ? 64 : (emojis.count <= 8 ? 50 : 40)))
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(game.gradient)
                    .shadow(color: game.colors[0].opacity(0.45), radius: 14, y: 6)
            )
            .padding(.horizontal, 24)

            Spacer()

            // 展示屏上唯一的操作：收起，回到看词界面去改表情 / 计分
            Button {
                FeedbackManager.shared.tap()
                showDisplay = false
                keyboardUp = true
            } label: {
                Label(L("emoji.back_to_word"), systemImage: "chevron.down.circle.fill")
            }
            .buttonStyle(BigButtonStyle(colors: [.indigo, .purple], font: .headline))
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    /// 换词：结算当前词、清空表情、回到看词界面。下一个词重新拿到完整的 30 秒
    private func nextRiddle(guessed: Bool) {
        store.markCurrentWord(guessed: guessed)
        word = store.nextWord()
        code = ""
        composeLeft = composeSeconds   // 下一个词重新拿满拼表情时间；单局时钟不动
        showDisplay = false
        keyboardUp = true
        forceShow = false
    }
}
