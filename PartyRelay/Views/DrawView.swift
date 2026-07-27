import SwiftUI
import Combine

// MARK: - 笔画模型

struct Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

/// 你画我猜（按键流程）：看词界面 ⇄「开始作画/收起画布」⇄ 画布界面
/// 计分按钮（答对/换一个/被抢答）只在看词界面；画布界面只有作画工具。
/// 防偷窥模式开启时，看词界面叠加姿态隐词（放平自动隐藏）。
struct DrawView: View {
    @EnvironmentObject var store: GameStore
    @ObservedObject private var motion = MotionManager.shared

    @State private var word = ""
    @State private var ownPoints = 0
    @State private var stolenPoints = 0
    @State private var skipsLeft = 0
    @State private var remaining = 60
    @State private var showCanvas = false     // 按键切换：词语界面 / 画布界面
    @State private var forceShow = false      // 连点三次强制显词（防偷窥模式下）
    @State private var forceTaps: [Date] = []

    @State var strokes: [Stroke] = []
    @State private var currentStroke: Stroke?
    @State private var selectedColor: Color = .black
    @State private var selectedWidth: CGFloat = 6

    static let palette: [Color] = [.black, .red, .blue, .green, .orange, .purple]
    static let widths: [CGFloat] = [3, 6, 12]

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var game: GameKind { .drawGuess }

    /// 防偷窥模式下，看词界面放平自动隐词
    private var wordHiddenByGuard: Bool {
        store.settings.privacyGuardOn && !forceShow && motion.posture == .flat
    }

    var body: some View {
        ZStack {
            PartyBackground()
            if showCanvas {
                canvasBody
            } else {
                wordBody
            }
        }
        .onAppear {
            remaining = store.roundDuration
            skipsLeft = store.skipAllowance
            if word.isEmpty { word = store.nextWord() }
            if store.settings.privacyGuardOn { motion.start() }
            if let m = ScreenshotMode.mode, m == "draw" || m == "drawcanvas" {
                word = LanguageManager.shared.language == .en ? "snowman" : "雪人"
                ownPoints = 2
                if m == "drawcanvas" {
                    strokes = ScreenshotMode.demoStrokes()
                    showCanvas = true
                }
            }
        }
        .onDisappear { motion.stop() }
        .onReceive(timer) { _ in
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

    // MARK: 看词界面（计分按钮都在这里）

    private var wordBody: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HomeExitButton()
                TimerRing(remaining: remaining, total: store.roundDuration, size: 50)
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
            .padding(.top, 10)

            if store.catchUp.isActive {
                CatchUpBanner(catchUp: store.catchUp, teamName: store.playingTeam.name)
            }

            Spacer()

            if wordHiddenByGuard {
                PrivacyCard(game: game)
            } else {
                VStack(spacing: 12) {
                    Text(L("draw.artist_only"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Text(word)
                        .font(.system(size: word.count > 6 ? 40 : 54, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 38)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(game.gradient)
                        .shadow(color: game.colors[0].opacity(0.45), radius: 14, y: 6)
                )
                .padding(.horizontal, 24)
            }

            Spacer()

            // 开始作画 + 计分按钮（只在看词界面）
            VStack(spacing: 10) {
                Button {
                    FeedbackManager.shared.tap()
                    showCanvas = true
                } label: {
                    Label(L("draw.start_drawing"), systemImage: "paintbrush.pointed.fill")
                }
                .buttonStyle(BigButtonStyle(colors: game.colors))

                if store.openBuzz {
                    HStack(spacing: 10) {
                        correctButton(compactLabel: true)
                        Button {
                            FeedbackManager.shared.buzz()
                            stolenPoints += 1
                            nextDrawing(guessed: true)
                        } label: {
                            Label(L("draw.sniped"), systemImage: "bolt.fill")
                        }
                        .buttonStyle(BigButtonStyle(colors: [.red, .orange], font: .headline, tall: true))
                    }
                } else {
                    correctButton(compactLabel: false)
                }

                Button {
                    FeedbackManager.shared.skip()
                    skipsLeft -= 1
                    nextDrawing(guessed: false)
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
            .padding(.bottom, 18)
        }
    }

    private func correctButton(compactLabel: Bool) -> some View {
        Button {
            FeedbackManager.shared.correct()
            ownPoints += 1
            nextDrawing(guessed: true)
        } label: {
            Label(compactLabel ? L("play.correct_us") : L("draw.correct_plain"),
                  systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(BigButtonStyle(colors: [.green, .mint], font: .headline, tall: true))
    }

    // MARK: 画布界面（只有作画工具 + 收起画布）

    private var canvasBody: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
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

            // 画布
            drawingCanvas
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 12)

            // 工具栏：6色 + 3档粗细 + 撤销/清空
            HStack(spacing: 6) {
                ForEach(Array(Self.palette.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 27, height: 27)
                        .overlay(Circle().stroke(.blue, lineWidth: selectedColor == color ? 3 : 0).padding(-3))
                        .onTapGesture {
                            FeedbackManager.shared.tap()
                            selectedColor = color
                        }
                }
                Divider().frame(height: 26)
                ForEach(Self.widths, id: \.self) { w in
                    Circle()
                        .fill(Color.primary.opacity(selectedWidth == w ? 1 : 0.35))
                        .frame(width: 8 + w, height: 8 + w)
                        .frame(width: 22, height: 22)
                        .onTapGesture {
                            FeedbackManager.shared.tap()
                            selectedWidth = w
                        }
                }
                Divider().frame(height: 26)
                Button {
                    FeedbackManager.shared.tap()
                    _ = strokes.popLast()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title2)
                }
                Button {
                    FeedbackManager.shared.skip()
                    strokes.removeAll()
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 10)

            // 收起画布 → 回到看词界面
            Button {
                FeedbackManager.shared.tap()
                showCanvas = false
            } label: {
                Label(L("draw.close_canvas"), systemImage: "chevron.down.circle.fill")
            }
            .buttonStyle(BigButtonStyle(colors: [.indigo, .purple], font: .headline))
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
        }
    }

    private var drawingCanvas: some View {
        Canvas { context, _ in
            for stroke in strokes {
                context.stroke(Self.path(for: stroke.points),
                               with: .color(stroke.color),
                               style: StrokeStyle(lineWidth: stroke.lineWidth,
                                                  lineCap: .round, lineJoin: .round))
            }
            if let s = currentStroke {
                context.stroke(Self.path(for: s.points),
                               with: .color(s.color),
                               style: StrokeStyle(lineWidth: s.lineWidth,
                                                  lineCap: .round, lineJoin: .round))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if currentStroke == nil {
                        currentStroke = Stroke(points: [value.location],
                                               color: selectedColor,
                                               lineWidth: selectedWidth)
                    } else {
                        currentStroke?.points.append(value.location)
                    }
                }
                .onEnded { _ in
                    if let s = currentStroke { strokes.append(s) }
                    currentStroke = nil
                }
        )
    }

    static func path(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 1 {
            path.addLine(to: CGPoint(x: first.x + 0.1, y: first.y + 0.1))
        } else {
            for p in points.dropFirst() { path.addLine(to: p) }
        }
        return path
    }

    /// 换词：结算当前词、清画布、回到看词界面
    private func nextDrawing(guessed: Bool) {
        store.markCurrentWord(guessed: guessed)
        word = store.nextWord()
        strokes.removeAll()
        currentStroke = nil
        showCanvas = false
        forceShow = false
    }
}
