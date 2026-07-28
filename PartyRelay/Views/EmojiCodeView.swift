import SwiftUI
import Combine

/// 表情管理：出题人看词 → 用系统 emoji 键盘拼出来 → 把词藏起来，整屏只剩表情给队友猜
///
/// 和你画我猜正好相反：那边是当众一笔一笔画，这边是先私下拼好、展示时画面完全冻结——
/// 展示屏上除了表情什么都没有，要改表情就得把手机拿回来（按「收起」回到看词界面）。
/// 计分按钮全部留在看词界面，跟你画我猜一致。
///
/// 计时和别的玩法一样：整遍就一块表，走 store.roundDuration（每队单局时长），
/// 从上场那一刻起一直走到 0——拼表情花掉的时间同样算在里面，翻键盘翻久了就是没时间猜。
struct EmojiCodeView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject private var motion = MotionManager.shared

    @State private var word = ""
    @State private var code = ""               // 拼好的表情串
    @State private var ownPoints = 0
    @State private var stolenPoints = 0
    @State private var skipsLeft = 0
    @State private var remaining = GameSettings().roundSeconds  // 本遍还剩几秒（拼表情和猜词共用这一块表）
    @State private var showDisplay = false     // 按键切换：看词界面 / 展示界面
    @State private var keyboardUp = false      // 输入框是否持有第一响应者
    @State private var forceShow = false       // 连点三次强制显词（防偷窥模式下）
    @State private var forceTaps: [Date] = []

    /// 一条密码最多几个表情：再多队友一眼读不完，展示屏也放不下
    static let maxEmojis = 12

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var game: GameKind { .emojiCode }

    private var emojis: [String] { code.map(String.init) }
    /// 展示用：表情之间留空，读起来不糊成一片，也方便换行
    private var spacedCode: String { emojis.joined(separator: " ") }

    /// 防偷窥模式下，看词界面放平自动隐词
    private var wordHiddenByGuard: Bool {
        store.settings.privacyGuardOn && !forceShow && motion.posture == .flat
    }

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
            remaining = store.roundDuration
            skipsLeft = store.skipAllowance
            if word.isEmpty { word = store.nextWord() }
            if store.settings.privacyGuardOn { motion.start() }
            if let m = ScreenshotMode.mode, m == "emoji" || m == "emojiguess" {
                word = LanguageManager.shared.language == .en ? "The Lion King" : "狮子王"
                code = "🦁👑🌍"
                ownPoints = 2
                showDisplay = m == "emojiguess"
                remaining = max(1, store.roundDuration * 3 / 4)   // 截图里让表正在走
            }
            keyboardUp = !showDisplay
        }
        .onDisappear { motion.stop() }
        .onReceive(timer) { _ in
            // 拼表情和猜词都在同一块表上，中间不停
            guard remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 {
                FeedbackManager.shared.timeUp()
                store.finishPlay(own: ownPoints, stolen: stolenPoints)
            } else if remaining <= 5 {
                FeedbackManager.shared.countdownTick()
            }
        }
    }

    // MARK: 看词界面（拼表情 + 计分按钮都在这里）

    private var composeBody: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HomeExitButton()
                TimerRing(remaining: remaining, total: store.roundDuration, size: 46)
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
                TimerRing(remaining: remaining, total: store.roundDuration, size: 48)
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
                Text(L("emoji.guess_title"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.85))
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
        showDisplay = false
        keyboardUp = true
        forceShow = false
    }
}
